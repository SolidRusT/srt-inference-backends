#!/bin/bash
# This script aggressively forces services to start using multiple methods
# It's designed as a last resort when services are not starting properly

echo -e "\n\n========================================================"
echo "SUPER FORCE START: Attempting to aggressively start services"
echo "========================================================"

# Source config if available
USE_GPU=false
if [ -f /opt/inference/config.env ]; then
  source /opt/inference/config.env
  if [ "$USE_GPU" = "true" ]; then
    USE_GPU=true
    echo "GPU mode is enabled"
  else
    echo "GPU mode is disabled"
  fi
else 
  echo "Config file not found, checking manually for GPU..."
  if command -v nvidia-smi &> /dev/null; then
    USE_GPU=true
    echo "GPU detected via nvidia-smi"
  fi
fi

# Force stop all services and containers
echo "Stopping all services and containers..."
systemctl stop inference-app.service || true
if [ "$USE_GPU" = "true" ]; then
  systemctl stop vllm.service || true
fi

# Kill any remaining Docker processes
echo "Killing any remaining Docker processes..."
docker ps -q | xargs -r docker kill
docker ps -a -q | xargs -r docker rm

# Restart Docker service
echo "Restarting Docker service..."
systemctl restart docker
sleep 5

# Verify Docker is running
if ! systemctl is-active docker &> /dev/null; then
  echo "ERROR: Docker service not running. Trying more aggressive restart..."
  systemctl stop docker
  sleep 2
  killall -9 dockerd || true
  killall -9 containerd || true
  sleep 2
  systemctl daemon-reload
  systemctl start docker
  sleep 5
  
  if ! systemctl is-active docker &> /dev/null; then
    echo "CRITICAL ERROR: Docker service failed to start after aggressive restart!"
    echo "Trying one last restart with system process cleanup..."
    
    ps aux | grep -E 'docker|containerd' | grep -v grep | awk '{print $2}' | xargs -r kill -9
    sleep 2
    systemctl start docker
    sleep 5
    
    if ! systemctl is-active docker &> /dev/null; then
      echo "FATAL ERROR: Docker service still not starting. Manual intervention required."
      exit 1
    fi
  fi
fi

echo "Docker service is now running."

# Force reload all systemd services
echo "Reloading systemd services..."
systemctl daemon-reload

# Make sure services are properly enabled
echo "Ensuring services are enabled..."
systemctl enable inference-app.service
if [ "$USE_GPU" = "true" ]; then
  systemctl enable vllm.service
fi

# Start services in correct order
if [ "$USE_GPU" = "true" ]; then
  echo "Starting vLLM service (GPU mode)..."
  
  # Attempt multiple start methods
  systemctl start vllm.service || echo "First attempt failed"
  sleep 5
  
  if ! systemctl is-active vllm.service &> /dev/null; then
    echo "vLLM service failed to start. Trying manual container start..."
    
    # Try direct Docker container creation
    HF_TOKEN=$(cat /opt/inference/hf_token.txt 2>/dev/null || aws ssm get-parameter --name /inference/hf_token --with-decryption --region us-west-2 --query "Parameter.Value" --output text 2>/dev/null || echo "no_token_available")
    
    docker run -d --name vllm-service \
      --runtime nvidia --gpus all \
      -v ~/.cache/huggingface:/root/.cache/huggingface \
      --env "VLLM_LOGGING_LEVEL=DEBUG" \
      --env "HUGGING_FACE_HUB_TOKEN=$HF_TOKEN" \
      -p 8000:8000 \
      --ipc=host \
      --network=host \
      vllm/vllm-openai:latest \
      --model Qwen/QwQ-7B || echo "Manual container creation failed"
    
    sleep 5
    
    # Check if manual container start worked
    if docker ps | grep -q vllm-service; then
      echo "Manual vLLM container start succeeded!"
    else
      echo "Manual vLLM container start failed. Last attempt: restart service..."
      systemctl restart vllm.service
      sleep 10
    fi
  fi
  
  echo "vLLM service status: $(systemctl is-active vllm.service)"
  docker ps | grep vllm-service || echo "No vLLM container found"
fi

echo "Starting inference-app service..."
systemctl start inference-app.service || echo "First attempt failed"
sleep 5

if ! systemctl is-active inference-app.service &> /dev/null; then
  echo "inference-app service failed to start. Trying manual container start..."
  
  # Try direct Docker container creation
  docker login -u AWS -p $(aws ecr get-login-password) "$(aws sts get-caller-identity --query 'Account' --output text).dkr.ecr.us-west-2.amazonaws.com" || echo "ECR login failed"
  
  docker run -d --name inference-app \
    -p 8080:8080 \
    -e PORT=8080 \
    -e VLLM_PORT=8000 \
    -e VLLM_HOST=localhost \
    -e AWS_REGION=us-west-2 \
    --network=host \
    "$(aws sts get-caller-identity --query 'Account' --output text).dkr.ecr.us-west-2.amazonaws.com/inference-app-production:latest" || echo "Manual container creation failed"
  
  sleep 5
  
  # Check if manual container start worked
  if docker ps | grep -q inference-app; then
    echo "Manual inference-app container start succeeded!"
  else
    echo "Manual inference-app container start failed. Last attempt: restart service..."
    systemctl restart inference-app.service
    sleep 10
  fi
fi

echo "Inference-app service status: $(systemctl is-active inference-app.service)"
docker ps | grep inference-app || echo "No inference-app container found"

# Set service to not restart on failure
echo "Setting service restart policy..."
mkdir -p /etc/systemd/system/inference-app.service.d
cat > /etc/systemd/system/inference-app.service.d/override.conf << EOC
[Service]
Restart=always
RestartSec=5
EOC

if [ "$USE_GPU" = "true" ]; then
  mkdir -p /etc/systemd/system/vllm.service.d
  cat > /etc/systemd/system/vllm.service.d/override.conf << EOC
[Service]
Restart=always
RestartSec=5
EOC
fi

systemctl daemon-reload

echo "Final status check:"
echo "-----------------"
systemctl status docker
echo "-----------------"
systemctl status inference-app.service
if [ "$USE_GPU" = "true" ]; then
  echo "-----------------"
  systemctl status vllm.service
fi
echo "-----------------"
docker ps
echo "-----------------"
echo "Network ports:"
netstat -tulpn | grep -E '(8080|8000)'
echo "-----------------"

echo "Super force start completed at $(date)"
