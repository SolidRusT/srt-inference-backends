#!/bin/bash
# This script creates systemd override configurations for our services
# to ensure they are more resilient and attempt to handle failures better

echo "=== Creating systemd override configurations ==="

# Create override directory for inference-app service
mkdir -p /etc/systemd/system/inference-app.service.d/

# Create the override file with improved restart behavior
cat > /etc/systemd/system/inference-app.service.d/override.conf << EOT
[Service]
# Override the Restart behavior to be more aggressive
Restart=always
RestartSec=10s

# Increase the timeout for slow container starts
TimeoutStartSec=300

# Don't give up after a certain number of restarts
StartLimitIntervalSec=0

# Add additional environment variables if needed
Environment=FORCE_START=true
EOT

echo "Created inference-app service override"

# If GPU is enabled, do the same for vLLM service
if [ -f /opt/inference/config.env ]; then
  source /opt/inference/config.env
  if [ "$USE_GPU" = "true" ]; then
    mkdir -p /etc/systemd/system/vllm.service.d/
    
    cat > /etc/systemd/system/vllm.service.d/override.conf << EOT
[Service]
# Override the Restart behavior to be more aggressive
Restart=always
RestartSec=15s

# Increase the timeout for slow container starts (GPU initialization can be slow)
TimeoutStartSec=600

# Don't give up after a certain number of restarts
StartLimitIntervalSec=0

# Add additional environment variables if needed
Environment=FORCE_START=true
EOT
    echo "Created vLLM service override"
  else
    echo "GPU not enabled, skipping vLLM service override"
  fi
else
  echo "Config file not found, skipping GPU-specific overrides"
fi

# Reload systemd to recognize the changes
systemctl daemon-reload

echo "Systemd overrides created and daemon reloaded"
