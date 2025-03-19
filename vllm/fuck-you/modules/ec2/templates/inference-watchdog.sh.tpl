#!/bin/bash

# Inference Services Watchdog Script
# This script continuously monitors and restarts inference services if they're not running

LOG_FILE="/var/log/inference-watchdog.log"
SLEEP_INTERVAL=30  # Check every 30 seconds
MAX_RETRIES=5      # Maximum number of retries before giving up on a service

# Make sure log file exists and is writable
touch $LOG_FILE
chmod 644 $LOG_FILE

# Log function
log() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" >> $LOG_FILE
  echo "$1"
}

log "========== Starting Inference Services Watchdog =========="
log "This watchdog will check services every $SLEEP_INTERVAL seconds"

# Source config if available
USE_GPU=false
if [ -f /opt/inference/config.env ]; then
  source /opt/inference/config.env
  if [ "$USE_GPU" = "true" ]; then
    log "GPU mode is enabled, will monitor both vLLM and inference-app"
    USE_GPU=true
  else
    log "GPU mode is disabled, will monitor only inference-app"
  fi
else
  log "No config found at /opt/inference/config.env, assuming non-GPU mode"
fi

# Function to check and restart a service if needed
check_and_restart_service() {
  local service_name=$1
  local container_name=$2
  local retry_count=0
  
  log "Checking service: $service_name (container: $container_name)"
  
  if ! systemctl is-active $service_name > /dev/null; then
    log "WARNING: $service_name service is not running!"
    
    # Try to restart the service several times
    while [ $retry_count -lt $MAX_RETRIES ]; do
      retry_count=$((retry_count+1))
      
      # First, check if Docker container is stuck
      if docker ps | grep -q $container_name; then
        log "Stopping stuck $container_name container..."
        docker stop $container_name || log "Failed to stop container"
        docker rm $container_name || log "Failed to remove container"
        sleep 2
      fi
      
      # Try to start the service
      log "Attempting to start $service_name service (attempt $retry_count/$MAX_RETRIES)..."
      systemctl start $service_name
      sleep 5  # Give it time to start
      
      # Check if successful
      if systemctl is-active $service_name > /dev/null; then
        log "Successfully started $service_name service"
        return 0
      else
        log "Failed to start $service_name service on attempt $retry_count"
        
        # Report useful diagnostics
        log "--- Service Status ---"
        systemctl status $service_name || true
        log "--- Last log entries ---"
        journalctl -u $service_name --no-pager -n 20 || true
      fi
      
      # Wait before next retry
      log "Waiting before retry..."
      sleep 10
    done
    
    log "ERROR: Failed to start $service_name service after $MAX_RETRIES attempts!"
    return 1
  else
    # Service is running, check container
    if ! docker ps | grep -q $container_name; then
      log "WARNING: Service $service_name is active but container $container_name is not running!"
      log "This suggests the service is in a failed state but systemd hasn't detected it."
      
      # Force restart
      log "Force restarting $service_name..."
      systemctl restart $service_name
      sleep 5
      
      # Check if successful
      if docker ps | grep -q $container_name; then
        log "Successfully restarted $service_name service"
        return 0
      else
        log "Failed to restart $service_name service to get container running"
        return 1
      fi
    fi
  fi
  
  return 0  # Service and container are running
}

# Function to verify API health
check_api_health() {
  local api_name=$1
  local port=$2
  local service_name=$3
  
  log "Checking $api_name health on port $port..."
  
  if curl -s http://localhost:$port/health > /dev/null; then
    log "$api_name API is healthy"
    return 0
  else
    log "WARNING: $api_name API is not responding!"
    log "Service is running but API is not healthy, restarting service..."
    systemctl restart $service_name
    sleep 10
    
    # Check again after restart
    if curl -s http://localhost:$port/health > /dev/null; then
      log "$api_name API is now healthy after restart"
      return 0
    else
      log "ERROR: $api_name API still not healthy after restart"
      return 1
    fi
  fi
}

# Watchdog main loop
while true; do
  log "--- Starting service check cycle ---"
  
  # Always check inference-app
  check_and_restart_service "inference-app" "inference-app"
  
  # Check API health after ensuring service is running
  if docker ps | grep -q "inference-app"; then
    check_api_health "Inference" "8080" "inference-app"
  fi
  
  # Check vLLM if in GPU mode
  if [ "$USE_GPU" = "true" ]; then
    check_and_restart_service "vllm" "vllm-service"
    
    # Check vLLM API health if service is running
    if docker ps | grep -q "vllm-service"; then
      check_api_health "vLLM" "8000" "vllm"
    fi
  fi
  
  log "--- Service check cycle completed ---"
  
  # Wait for next check
  sleep $SLEEP_INTERVAL
done
