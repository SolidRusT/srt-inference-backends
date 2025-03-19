#!/bin/bash
# This is a manual script that can be run to force-start the services
# You can SSH to the instance and run this script if services aren't starting

set -e
echo "Starting manual service initialization script..."

# Find and source configuration
if [ -f /opt/inference/config.env ]; then
  source /opt/inference/config.env
  echo "Configuration loaded from /opt/inference/config.env"
  echo "USE_GPU = $USE_GPU"
else 
  echo "No config.env found in /opt/inference"
  
  # Try to determine if we're in GPU mode
  if command -v nvidia-smi &> /dev/null; then
    USE_GPU=true
    echo "GPU detected, setting USE_GPU=true"
  else
    USE_GPU=false
    echo "No GPU detected, setting USE_GPU=false"
  fi
fi

# Make sure Docker is running
echo "Ensuring Docker is running..."
if ! systemctl is-active docker &> /dev/null; then
  systemctl restart docker
  sleep 5
  
  if ! systemctl is-active docker &> /dev/null; then
    echo "ERROR: Could not start Docker service!"
    exit 1
  fi
fi

# Stop any existing services and containers
echo "Stopping any existing services and containers..."
systemctl stop inference-app.service || true
if [ "$USE_GPU" = "true" ]; then
  systemctl stop vllm.service || true
fi

docker ps -q | xargs -r docker kill
docker ps -a -q | xargs -r docker rm

# Check and enable services
echo "Enabling services..."
systemctl enable inference-app.service
if [ "$USE_GPU" = "true" ]; then
  systemctl enable vllm.service
fi

# Reload daemon
systemctl daemon-reload

# Start services in order
if [ "$USE_GPU" = "true" ]; then
  echo "Starting vLLM service (GPU mode)..."
  systemctl start vllm.service
  sleep 10
  
  echo "vLLM service status:"
  systemctl status vllm.service || true
  
  echo "vLLM container:"
  docker ps | grep vllm || echo "No vLLM container found"
fi

echo "Starting inference-app service..."
systemctl start inference-app.service 
sleep 10

echo "inference-app service status:"
systemctl status inference-app.service || true

echo "inference-app container:"
docker ps | grep inference-app || echo "No inference-app container found"

echo "Listening ports:"
netstat -tulpn | grep -E "(8080|8000)" || echo "No services listening on API ports"

echo "Manual service start completed at $(date)"
