#!/bin/bash

# Minimal bootstrap script to download and run the main setup
# Instance version: ${instance_version}
# Generated at: $(date)

# Log everything to a file for debugging
set -e
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting bootstrap script at $(date)"

# Install minimal dependencies
apt-get update
apt-get install -y awscli curl jq

# Set up AWS region
export AWS_DEFAULT_REGION="${aws_region}"

# Create directories
mkdir -p /opt/inference
mkdir -p /var/lib/cloud/scripts/per-boot

# Create service check script to run at every boot with enhanced retry logic
cat > /var/lib/cloud/scripts/per-boot/ensure-services.sh << 'EOSVC'
#!/bin/bash
# This script runs at every boot to ensure services are running

LOG_FILE="/var/log/ensure-services.log"
CHECK_TIMESTAMP="/tmp/last-service-check"
exec > >(tee -a $LOG_FILE) 2>&1

echo -e "\n\n================================================="
echo "Running service check at $(date)"
echo -e "=================================================\n"

# Create a timestamp for this run
date > $CHECK_TIMESTAMP

# Source config if available to check if GPU is enabled
USE_GPU=false
if [ -f /opt/inference/config.env ]; then
  source /opt/inference/config.env
  if [ "$USE_GPU" = "true" ]; then
    USE_GPU=true
    echo "GPU mode is enabled in configuration"
  else
    echo "GPU mode is disabled in configuration"
  fi
else
  echo "Configuration file not found, assuming non-GPU mode"
fi

# Clean up any potential lingering containers to avoid conflicts
echo "Cleaning up any existing containers..."
docker rm -f inference-app 2>/dev/null || echo "No inference-app container to remove"
if [ "$USE_GPU" = "true" ]; then
  docker rm -f vllm-service 2>/dev/null || echo "No vllm-service container to remove"
fi

# Check if docker is running
if ! systemctl is-active docker >/dev/null 2>&1; then
  echo "Docker service not running, starting..."
  systemctl start docker
  sleep 5
  
  if ! systemctl is-active docker >/dev/null 2>&1; then
    echo "ERROR: Failed to start Docker service! All other services will fail."
    # Try more aggressive Docker restart
    systemctl stop docker
    sleep 2
    systemctl daemon-reload
    systemctl start docker
    sleep 5
    
    if ! systemctl is-active docker >/dev/null 2>&1; then
      echo "CRITICAL ERROR: Docker service still not starting. System may need manual intervention."
      exit 1
    fi
  fi
fi

# Check if services are enabled
if [ "$USE_GPU" = "true" ] && ! systemctl is-enabled vllm >/dev/null 2>&1; then
  echo "vLLM service not enabled, enabling..."
  systemctl enable vllm
fi

if ! systemctl is-enabled inference-app >/dev/null 2>&1; then
  echo "Inference app service not enabled, enabling..."
  systemctl enable inference-app
fi

# Start services in the right order with retries
MAX_RETRIES=5

echo -e "\n===== Starting services... ====="

if [ "$USE_GPU" = "true" ]; then
  echo "Starting vLLM service first in GPU mode..."
  
  # Check for NVIDIA readiness
  if command -v nvidia-smi >/dev/null 2>&1; then
    echo "NVIDIA drivers status:"
    if ! nvidia-smi; then
      echo "NVIDIA drivers not ready yet, waiting..."
      sleep 10
      nvidia-smi || echo "NVIDIA drivers still not ready, but continuing"
    fi
  else
    echo "NVIDIA tools not found, this may cause issues in GPU mode"
  fi
  
  # Start vLLM with retries
  RETRY=0
  while [ $RETRY -lt $MAX_RETRIES ]; do
    # First verify no containers are running
    if docker ps | grep -q vllm-service; then
      echo "vLLM container already running, stopping it first..."
      docker stop vllm-service
      docker rm vllm-service
      sleep 2
    fi
    
    if systemctl start vllm; then
      echo "vLLM service started successfully"
      
      # Verify container is actually running
      sleep 5
      if docker ps | grep -q vllm-service; then
        echo "vLLM container confirmed running"
        break
      else
        echo "vLLM service started but container is not running"
        RETRY=$((RETRY+1))
        echo "Restarting vllm service (attempt $RETRY/$MAX_RETRIES)"
        systemctl restart vllm
        sleep 5
      fi
    else
      RETRY=$((RETRY+1))
      echo "Failed to start vLLM service (attempt $RETRY/$MAX_RETRIES)"
      if [ $RETRY -lt $MAX_RETRIES ]; then
        echo "Waiting before retry..."
        sleep 10
      else
        echo "Maximum retries reached for vLLM service"
      fi
    fi
  done
  
  # Wait for vLLM API to be responsive
  echo "Waiting for vLLM API to be responsive..."
  if command -v /usr/local/bin/wait-for-vllm.sh >/dev/null 2>&1; then
    /usr/local/bin/wait-for-vllm.sh || echo "vLLM API not responding yet, but continuing"
  else
    # Fallback if wait script is not available
    MAX_API_CHECKS=15
    API_CHECK=0
    while [ $API_CHECK -lt $MAX_API_CHECKS ]; do
      API_CHECK=$((API_CHECK+1))
      echo "Checking vLLM API (attempt $API_CHECK/$MAX_API_CHECKS)..."
      if curl -s http://localhost:8000/health > /dev/null; then
        echo "vLLM API is responding!"
        break
      else
        echo "vLLM API not responding yet"
        sleep 10
      fi
      
      if [ $API_CHECK -eq $MAX_API_CHECKS ]; then
        echo "WARNING: vLLM API not responding after maximum checks"
      fi
    done
  fi
fi

# Now start the inference app
echo -e "\n===== Starting inference-app service ====="
RETRY=0
while [ $RETRY -lt $MAX_RETRIES ]; do
  # Check and clean up any existing containers
  if docker ps | grep -q inference-app; then
    echo "Inference app container already running, stopping it first..."
    docker stop inference-app
    docker rm inference-app
    sleep 2
  fi
  
  if systemctl start inference-app; then
    echo "Inference app service started successfully"
    
    # Verify container is actually running
    sleep 5
    if docker ps | grep -q inference-app; then
      echo "Inference app container confirmed running"
      break
    else
      echo "Inference app service started but container is not running"
      RETRY=$((RETRY+1))
      echo "Restarting inference-app service (attempt $RETRY/$MAX_RETRIES)"
      systemctl restart inference-app
      sleep 5
    fi
  else
    RETRY=$((RETRY+1))
    echo "Failed to start inference-app service (attempt $RETRY/$MAX_RETRIES)"
    if [ $RETRY -lt $MAX_RETRIES ]; then
      echo "Waiting before retry..."
      sleep 10
    else
      echo "Maximum retries reached for inference-app service"
    fi
  fi
done

# Check the API health
echo "Checking inference API health..."
MAX_API_CHECKS=10
API_CHECK=0
while [ $API_CHECK -lt $MAX_API_CHECKS ]; do
  API_CHECK=$((API_CHECK+1))
  echo "Checking inference API (attempt $API_CHECK/$MAX_API_CHECKS)..."
  if curl -s http://localhost:8080/health > /dev/null; then
    echo "Inference API is responding! Service is healthy."
    break
  else
    echo "Inference API not responding yet"
    sleep 5
  fi
  
  if [ $API_CHECK -eq $MAX_API_CHECKS ]; then
    echo "WARNING: Inference API not responding after maximum checks"
  fi
done

# Wait a moment to ensure services have had time to start
sleep 5

# Final service status check
echo "=== Final Service Status ==="
systemctl status docker --no-pager || echo "Docker service status check failed"
systemctl status inference-app --no-pager || echo "Inference app service status check failed"
if [ "$USE_GPU" = "true" ]; then
  systemctl status vllm --no-pager || echo "vLLM service status check failed"
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi || echo "NVIDIA status check failed"
  fi
fi

# List running containers
echo "=== Running Containers ==="
docker ps

# Check for any containers or services that might need manual restart
if [ "$USE_GPU" = "true" ] && systemctl is-active vllm >/dev/null && ! docker ps | grep -q vllm-service; then
  echo "vLLM service is active but container is not running. Restarting service..."
  systemctl restart vllm
fi

if systemctl is-active inference-app >/dev/null && ! docker ps | grep -q inference-app; then
  echo "Inference app service is active but container is not running. Restarting service..."
  systemctl restart inference-app
fi

# Verify docker container API health
if docker ps | grep -q inference-app; then
  echo "Checking inference API health..."
  if ! curl -s http://localhost:8080/health > /dev/null; then
    echo "Inference API is not responding, restarting service..."
    systemctl restart inference-app
  else
    echo "Inference API is healthy"
  fi
fi

if [ "$USE_GPU" = "true" ] && docker ps | grep -q vllm-service; then
  echo "Checking vLLM API health..."
  if ! curl -s http://localhost:8000/health > /dev/null; then
    echo "vLLM API is not responding, restarting service..."
    systemctl restart vllm
  else
    echo "vLLM API is healthy"
  fi
fi

echo "Service check completed at $(date)"
EOSVC
chmod +x /var/lib/cloud/scripts/per-boot/ensure-services.sh

# Execute the script immediately to start services after initial setup
echo "Running service enablement script for first time..."
/var/lib/cloud/scripts/per-boot/ensure-services.sh

# Download the main setup script from S3
echo "Downloading main setup script from S3..."
aws s3 cp s3://${scripts_bucket}/${main_setup_key} /opt/inference/main-setup.sh

# Make script executable
chmod +x /opt/inference/main-setup.sh

# Execute the main setup script
echo "Executing main setup script..."
/opt/inference/main-setup.sh

# Run the service check immediately after setup
echo "Running service check and ensuring services are started..."
/var/lib/cloud/scripts/per-boot/ensure-services.sh

# Verify services are running (critical for first boot)
if systemctl is-active inference-app.service >/dev/null; then
  echo "Inference app service is running"
else
  echo "Inference app service is not running, attempting to start..."
  systemctl start inference-app.service
fi

if [ "${use_gpu}" = "true" ]; then
  if systemctl is-active vllm.service >/dev/null; then
    echo "vLLM service is running"
  else
    echo "vLLM service is not running, attempting to start..."
    systemctl start vllm.service
  fi
fi

# Check cloud-init status
echo "Checking cloud-init status..."
cloud-init status --long || echo "Cloud-init status command failed"

# Try to force start the services one last time
echo "Force starting services with diagnostics..."
if [ -f /usr/local/bin/force-start-services.sh ]; then
  /usr/local/bin/force-start-services.sh
  
  # Check if services are now running
  SERVICE_SUCCESS=true
  if ! systemctl is-active inference-app.service >/dev/null; then
    echo "Regular force start didn't work for inference-app, trying super force start..."
    SERVICE_SUCCESS=false
  fi
  
  if [ "${use_gpu}" = "true" ] && ! systemctl is-active vllm.service >/dev/null; then
    echo "Regular force start didn't work for vLLM, trying super force start..."
    SERVICE_SUCCESS=false
  fi
  
  # If regular force start failed, try super force start
  if [ "$SERVICE_SUCCESS" = "false" ] && [ -f /usr/local/bin/super-force-start.sh ]; then
    echo -e "\n\n===== ATTEMPTING SUPER FORCE START =====\n\n"
    /usr/local/bin/super-force-start.sh
  fi
else
  echo "Force start script not found, attempting direct service starts..."
  systemctl daemon-reload
  systemctl start inference-app.service || echo "Failed to start inference-app service"
  if [ "${use_gpu}" = "true" ]; then
    systemctl start vllm.service || echo "Failed to start vLLM service"
  fi
  
  # Try super force start if direct starts failed
  if ! systemctl is-active inference-app.service >/dev/null || ([ "${use_gpu}" = "true" ] && ! systemctl is-active vllm.service >/dev/null); then
    if [ -f /usr/local/bin/super-force-start.sh ]; then
      echo -e "\n\n===== ATTEMPTING SUPER FORCE START =====\n\n"
      /usr/local/bin/super-force-start.sh
    fi
  fi
fi

# Extended diagnostics
echo -e "\n===== EXTENDED DIAGNOSTICS ====="
echo "Running processes:" 
ps aux | grep -E 'docker|vllm|inference' || true
echo -e "\nNetwork status:"
netstat -tulpn | grep -E "(8080|8000|443)" || echo "No services listening on API ports"
echo -e "\nDocker service status:"
systemctl status docker --no-pager || true
echo -e "\nFile permissions check:"
ls -la /etc/systemd/system/inference-app.service /etc/systemd/system/vllm.service || true
echo -e "\nSwap info:"
free -m
echo -e "\nDisk space:"
df -h

echo "Bootstrap completed at $(date)"