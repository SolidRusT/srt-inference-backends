# Create the Docker login script
echo "===== Creating utility scripts ====="
cat > /usr/local/bin/docker-login-ecr.sh << 'EOF'
#!/bin/bash

# Get the ECR login token and use it to authenticate Docker
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query 'Account' --output text).dkr.ecr.${aws_region}.amazonaws.com
EOF
chmod +x /usr/local/bin/docker-login-ecr.sh

# Create script to get HF token from SSM Parameter Store
cat > /usr/local/bin/get-hf-token.sh << 'EOF'
#!/bin/bash

# Get the HuggingFace token from SSM Parameter Store
echo "Retrieving HuggingFace token from SSM parameter: ${hf_token_parameter_name}"
MAX_ATTEMPTS=3
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT+1))
  echo "Attempt $ATTEMPT of $MAX_ATTEMPTS..."
  
  HF_TOKEN=$(aws ssm get-parameter --name ${hf_token_parameter_name} --with-decryption --region ${aws_region} --query "Parameter.Value" --output text 2>/dev/null)
  
  if [ -z "$HF_TOKEN" ]; then
    echo "WARNING: Empty HuggingFace token retrieved. Retrying in 5 seconds..."
    sleep 5
  else
    echo "Successfully retrieved HuggingFace token (first 3 chars): $${HF_TOKEN:0:3}..."
    echo "$HF_TOKEN"
    exit 0
  fi
done

echo "WARNING: Failed to retrieve token after $MAX_ATTEMPTS attempts. Using fallback value."
echo "hf_fallback_token_for_testing"
EOF
chmod +x /usr/local/bin/get-hf-token.sh

# Test the token retrieval script
echo "Testing HuggingFace token retrieval..."
/usr/local/bin/get-hf-token.sh || echo "WARNING: Error retrieving HuggingFace token, but continuing anyway"

# Create script to test vLLM (with GPU check)
cat > /usr/local/bin/test-vllm.sh << 'EOL'
#!/bin/bash

# Check if we're running in non-GPU mode
if [ -f /opt/inference/config.env ]; then
  source /opt/inference/config.env
  if [ "$USE_GPU" != "true" ]; then
    echo "==== vLLM Test Script ===="
    echo "GPU support is disabled in configuration."
    echo "vLLM service is not available in non-GPU mode."
    echo "==== End of vLLM Test ===="
    exit 0
  fi
fi

echo "==== vLLM Test Script ===="
echo "Checking for HuggingFace token..."
HF_TOKEN=$(/usr/local/bin/get-hf-token.sh)
if [ -z "$HF_TOKEN" ]; then
  echo "ERROR: No HuggingFace token available!"
else
  echo "HuggingFace token found. First few characters: $${HF_TOKEN:0:4}..."
fi

echo "Checking NVIDIA drivers..."
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi
else
  echo "NVIDIA tools not installed or not in PATH!"
fi

echo "Checking vLLM service status..."
systemctl status vllm

echo "Checking container status..."
docker ps | grep vllm-service || echo "vLLM container not found in docker ps"

echo "Testing vLLM API..."
curl -s http://localhost:${vllm_port}/health || echo "vLLM API not responding"

echo "Docker logs for vLLM (last 50 lines):"
docker logs vllm-service --tail 50 2>&1 || echo "No vLLM container logs available"

echo "==== End of vLLM Test ===="
EOL
chmod +x /usr/local/bin/test-vllm.sh

# Create an enhanced health check script
cat > /usr/local/bin/health-check.sh << 'EOL'
#!/bin/bash

# Check if we're running in non-GPU mode
if [ -f /opt/inference/config.env ]; then
  source /opt/inference/config.env
  if [ "$USE_GPU" != "true" ]; then
    # In non-GPU mode, just check if the API is running
    api_status=$(systemctl is-active inference-app)
    
    if [ "$api_status" = "active" ]; then
      # API is running
      cat << EOF
{
  "status": "ok",
  "message": "API is healthy (vLLM disabled in non-GPU mode)",
  "vllm_status": "disabled",
  "api_status": "healthy",
  "gpu_enabled": false
}
EOF
      exit 0
    else
      # API is not running
      cat << EOF
{
  "status": "error",
  "message": "API service is not running",
  "vllm_status": "disabled",
  "api_status": "unavailable",
  "gpu_enabled": false
}
EOF
      exit 1
    fi
  fi
fi

# For GPU mode - regular checks
# Check if both services are running
vllm_status=$(systemctl is-active vllm)
api_status=$(systemctl is-active inference-app)

# Get vLLM API health
vllm_api_healthy=false
if curl -s http://localhost:${vllm_port}/health > /dev/null 2>&1; then
  vllm_api_healthy=true
fi

# Format the response based on service statuses
if [ "$api_status" = "active" ]; then
  # API is running
  if [ "$vllm_api_healthy" = "true" ]; then
    # Everything is good
    cat << EOF
{
  "status": "ok",
  "message": "API and vLLM service are healthy",
  "vllm_status": "healthy",
  "api_status": "healthy",
  "gpu_enabled": true
}
EOF
    exit 0
  else
    # API is up but vLLM is not responding
    # Get more information about vLLM
    vllm_info=$(/usr/local/bin/monitor-vllm.sh)
    
    cat << EOF
{
  "status": "warning",
  "message": "API is healthy but vLLM service is not responding",
  "vllm_status": "unavailable",
  "api_status": "healthy",
  "vllm_info": $vllm_info,
  "gpu_enabled": true
}
EOF
    # Return status 200 since API is up
    exit 0
  fi
else
  # API is not running
  cat << EOF
{
  "status": "error",
  "message": "API service is not running",
  "vllm_status": "$$([ "$vllm_api_healthy" = "true" ] && echo "healthy" || echo "unavailable")",
  "api_status": "unavailable",
  "gpu_enabled": true
}
EOF
  # Return error status
  exit 1
fi
EOL
chmod +x /usr/local/bin/health-check.sh

# Create update script
cat > /usr/local/bin/update-inference-app.sh << 'EOL'
#!/bin/bash

# Login to ECR
/usr/local/bin/docker-login-ecr.sh

# Pull the latest image
docker pull ${ecr_repository_url}:latest

# Restart the service to use the new image
systemctl restart inference-app
EOL
chmod +x /usr/local/bin/update-inference-app.sh

# Create a script to wait for vLLM to be ready
cat > /usr/local/bin/wait-for-vllm.sh << 'EOL'
#!/bin/bash

MAX_ATTEMPTS=30
ATTEMPT=0
WAIT_SECONDS=10

echo "Waiting for vLLM service to be available..." 

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT+1))
  echo "Attempt $ATTEMPT of $MAX_ATTEMPTS..."
  
  # Check if the vLLM service is active
  if ! systemctl is-active vllm >/dev/null 2>&1; then
    echo "vLLM service is not active"
    sleep $WAIT_SECONDS
    continue
  fi
  
  # Check if the vLLM container is running
  if ! docker ps | grep -q vllm-service; then
    echo "vLLM container is not running yet"
    sleep $WAIT_SECONDS
    continue
  fi
  
  # Try to connect to the health endpoint
  if curl -s http://localhost:${vllm_port}/health > /dev/null; then
    echo "vLLM service is available!"
    exit 0
  else
    echo "vLLM service not responding yet"
    sleep $WAIT_SECONDS
  fi
done

echo "Failed to connect to vLLM service after $MAX_ATTEMPTS attempts"
exit 1
EOL
chmod +x /usr/local/bin/wait-for-vllm.sh

# Create a script to monitor vLLM status
cat > /usr/local/bin/monitor-vllm.sh << 'EOL'
#!/bin/bash

# This script checks the status of vLLM and returns useful information

# Check if we're running in non-GPU mode
if [ -f /opt/inference/config.env ]; then
  source /opt/inference/config.env
  if [ "$USE_GPU" != "true" ]; then
    # Return non-GPU status
    cat << EOF
{
  "service_status": "disabled",
  "container_status": "not_running",
  "api_status": "disabled",
  "started_at": "N/A",
  "last_logs": "vLLM is disabled in non-GPU mode",
  "gpu_enabled": false
}
EOF
    exit 0
  fi
fi

# Check if vLLM service is active
VLLM_SERVICE_STATUS=$(systemctl is-active vllm)

# Check if vLLM container is running
if docker ps | grep -q vllm-service; then
  VLLM_CONTAINER_STATUS="running"
  # Get vLLM container start time
  CONTAINER_STARTED=$(docker inspect --format='{{.State.StartedAt}}' vllm-service 2>/dev/null | xargs -I{} date -d {} +"%Y-%m-%d %H:%M:%S")
  # Get last log lines
  LAST_LOGS=$(docker logs vllm-service --tail 5 2>&1 | sed 's/\"//g' | tr '\n' ' ' | cut -c 1-500)
else
  VLLM_CONTAINER_STATUS="not_running"
  CONTAINER_STARTED="N/A"
  LAST_LOGS="No container running"
fi

# Try to get vLLM health status
if curl -s http://localhost:${vllm_port}/health > /dev/null 2>&1; then
  VLLM_API_STATUS="healthy"
else
  VLLM_API_STATUS="unavailable"
fi

# Output information in JSON format
cat << EOF
{
  "service_status": "$VLLM_SERVICE_STATUS",
  "container_status": "$VLLM_CONTAINER_STATUS",
  "api_status": "$VLLM_API_STATUS",
  "started_at": "$CONTAINER_STARTED",
  "last_logs": "$LAST_LOGS",
  "gpu_enabled": true
}
EOF
EOL
chmod +x /usr/local/bin/monitor-vllm.sh

# Create a script that can restart vLLM if needed
cat > /usr/local/bin/restart-vllm.sh << 'EOL'
#!/bin/bash

# Log to a file
exec > >(tee -a /var/log/vllm-restarts.log) 2>&1
echo "[$(date)] Attempting to restart vLLM service"

# Check current status
VLLM_STATUS=$(systemctl is-active vllm)
echo "[$(date)] Current vLLM service status: $VLLM_STATUS"

# Stop any running containers
docker stop vllm-service 2>/dev/null || echo "No container to stop"
docker rm vllm-service 2>/dev/null || echo "No container to remove"

# Restart the service
echo "[$(date)] Restarting vLLM service"
systemctl restart vllm

# Wait a bit and check status
sleep 5
NEW_STATUS=$(systemctl is-active vllm)
echo "[$(date)] New vLLM service status: $NEW_STATUS"

# Try to wait for it to be fully available
echo "[$(date)] Waiting for vLLM API to respond"
/usr/local/bin/wait-for-vllm.sh
RESULT=$?

if [ $RESULT -eq 0 ]; then
  echo "[$(date)] vLLM successfully restarted and API is responding"
  exit 0
else
  echo "[$(date)] vLLM restarted but API is not responding yet"
  exit 1
fi
EOL
chmod +x /usr/local/bin/restart-vllm.sh

# Download and set up the watchdog script and service
echo "Setting up inference watchdog service..."

# Download the watchdog script from S3 and make it executable
aws s3 cp s3://${scripts_bucket}/scripts/inference-watchdog.sh /usr/local/bin/inference-watchdog.sh
chmod +x /usr/local/bin/inference-watchdog.sh

# Download the service file
aws s3 cp s3://${scripts_bucket}/scripts/inference-watchdog.service /etc/systemd/system/inference-watchdog.service

# Enable and start the watchdog service
systemctl daemon-reload
systemctl enable inference-watchdog.service
systemctl start inference-watchdog.service || echo "Warning: Failed to start watchdog service immediately, it will be started on next boot"

# Create a simple script to force start all services
cat > /usr/local/bin/force-start-services.sh << 'EOF'
#!/bin/bash

echo "===== Force starting all inference services ====="
echo "Starting at $(date)"

# Get GPU mode from config
USE_GPU=false
if [ -f /opt/inference/config.env ]; then
  source /opt/inference/config.env
  if [ "$USE_GPU" = "true" ]; then
    USE_GPU=true
    echo "GPU mode is enabled"
  else
    echo "GPU mode is disabled"
  fi
fi

# Force stop all services first
echo "Stopping any existing services..."
systemctl stop inference-app.service || true
if [ "$USE_GPU" = "true" ]; then
  systemctl stop vllm.service || true
fi

# Stop and remove any running containers
echo "Cleaning up any existing containers..."
docker stop inference-app 2>/dev/null || true
docker rm inference-app 2>/dev/null || true
if [ "$USE_GPU" = "true" ]; then
  docker stop vllm-service 2>/dev/null || true
  docker rm vllm-service 2>/dev/null || true
fi

# Wait for cleanup
sleep 2

# Start services in correct order
if [ "$USE_GPU" = "true" ]; then
  echo "Starting vLLM service..."
  systemctl start vllm.service
  sleep 5
  systemctl status vllm.service
  
  # Wait for vLLM to initialize
  if [ -f /usr/local/bin/wait-for-vllm.sh ]; then
    echo "Waiting for vLLM to be ready..."
    /usr/local/bin/wait-for-vllm.sh || echo "vLLM service not responding yet"
  else
    echo "wait-for-vllm.sh not found, waiting 30 seconds instead..."
    sleep 30
  fi
fi

echo "Starting inference-app service..."
systemctl start inference-app.service
sleep 5
systemctl status inference-app.service

echo "Checking for running containers..."
docker ps

echo "===== Service force start completed at $(date) ====="
EOF
chmod +x /usr/local/bin/force-start-services.sh

echo "Watchdog service and scripts installed"