#!/bin/bash

# Create service files
set -e
echo "===== Creating systemd services ====="

# Ensure we display all commands and errors
set -x
exec > >(tee /var/log/services-setup.log) 2>&1

# Create vLLM service
cat > /etc/systemd/system/vllm.service << EOT
[Unit]
Description=vLLM Inference Service
After=docker.service network.target
Requires=docker.service
# No direct relationship with inference-app to avoid startup issues

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop vllm-service
ExecStartPre=-/usr/bin/docker rm vllm-service
ExecStartPre=/usr/bin/docker pull vllm/vllm-openai:${vllm_image_tag}
ExecStart=/bin/bash -c 'HF_TOKEN=\$(/usr/local/bin/get-hf-token.sh) && \\
    /usr/bin/docker run --rm --name vllm-service \\
EOT

# Add GPU flag if needed
if [ "${use_gpu}" = "true" ]; then
  echo "    --runtime nvidia --gpus all \\" >> /etc/systemd/system/vllm.service
fi

# Continue the service file
cat >> /etc/systemd/system/vllm.service << EOT
    -v ~/.cache/huggingface:/root/.cache/huggingface \\
    --env "VLLM_LOGGING_LEVEL=DEBUG" \\
    --env "HUGGING_FACE_HUB_TOKEN=$${HF_TOKEN}" \\
    -p ${vllm_port}:8000 \\
    --ipc=host \\
    --network=host \\
    vllm/vllm-openai:${vllm_image_tag} \\
    --model ${model_id} \\
    --tokenizer ${model_id} \\
    --trust-remote-code \\
    --dtype auto \\
    --device auto \\
    --max-model-len ${max_model_len} \\
    --gpu-memory-utilization ${gpu_memory_utilization} \\
    --tensor-parallel-size ${tensor_parallel_size} \\
    --pipeline-parallel-size ${pipeline_parallel_size} \\
    --tool-call-parser ${tool_call_parser}'

[Install]
WantedBy=multi-user.target
EOT

# Create the API service
cat > /etc/systemd/system/inference-app.service << EOT
[Unit]
Description=Inference API Proxy
After=docker.service network.target
Requires=docker.service
# No dependency on vLLM to allow operation even when vLLM is down

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop inference-app
ExecStartPre=-/usr/bin/docker rm inference-app
ExecStartPre=/usr/local/bin/docker-login-ecr.sh
ExecStartPre=/usr/bin/docker pull ${ecr_repository_url}:latest
# No wait for vLLM to allow independent start
ExecStart=/usr/bin/docker run --rm --name inference-app \\
    -p ${app_port}:${app_port} \\
EOT

# Add HTTPS port if enabled
if [ "${enable_https}" = "true" ]; then
  echo "    -p 443:443 \\" >> /etc/systemd/system/inference-app.service
fi

# Continue the service file
cat >> /etc/systemd/system/inference-app.service << EOT
    -e PORT=${app_port} \\
    -e VLLM_PORT=${vllm_port} \\
    -e VLLM_HOST=localhost \\
    -e MODEL_ID="${model_id}" \\
    -e DEFAULT_TIMEOUT_MS="60000" \\
    -e MAX_TIMEOUT_MS="300000" \\
    -e USE_HTTPS="${enable_https}" \\
EOT

# Add volume mount if HTTPS is enabled
if [ "${enable_https}" = "true" ]; then
  echo "    -v /etc/ssl:/etc/ssl \\" >> /etc/systemd/system/inference-app.service
fi

# Finish the service file
cat >> /etc/systemd/system/inference-app.service << EOT
    -e AWS_REGION=${aws_region} \\
    --network=host \\
    ${ecr_repository_url}:latest

[Install]
WantedBy=multi-user.target
EOT

# Create "ensure services" service that will run on every boot
cat > /etc/systemd/system/ensure-inference-services.service << EOT
[Unit]
Description=Ensure Inference Services are Running
After=docker.service network.target
Wants=docker.service multi-user.target

[Service]
Type=oneshot
ExecStart=/var/lib/cloud/scripts/per-boot/ensure-services.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOT

# Now initialize all the services
echo "===== Initializing services ====="

# Reload systemd to recognize our new service files
systemctl daemon-reload

# Enable all services to start on boot
echo "Enabling services to start on boot"
systemctl enable inference-app.service ensure-inference-services.service
if [ "${use_gpu}" = "true" ]; then
  systemctl enable vllm.service
fi

# Force start our services immediately
echo "Force starting services now..."

if [ "${use_gpu}" = "true" ]; then
  echo "Starting vLLM service (GPU mode)..."
  systemctl start vllm.service || echo "Warning: vLLM failed to start, but this may be expected in GPU mode before reboot"
  sleep 3
  systemctl status vllm.service || true
fi

echo "Starting inference app service..."
systemctl start inference-app.service || echo "Warning: inference-app failed to start on first attempt"
sleep 3
systemctl status inference-app.service || true

# Start the ensure-services service
echo "Starting ensure-inference-services service..."
systemctl start ensure-inference-services.service || echo "Warning: ensure-inference-services failed to start"
sleep 1 
systemctl status ensure-inference-services.service || true

# Create a cron job to check services every minute during the first hour after boot
echo "Setting up frequent service check cron job for first hour..."
cat > /etc/cron.d/initial-service-check << EOC
# Check services every minute for the first hour after boot
* * * * * root /var/lib/cloud/scripts/per-boot/ensure-services.sh > /dev/null 2>&1
EOC
chmod 0644 /etc/cron.d/initial-service-check

# Log our final status
echo "===== Service setup completed at $(date) ====="
echo "Service statuses:"
systemctl status inference-app.service --no-pager || true
if [ "${use_gpu}" = "true" ]; then
  systemctl status vllm.service --no-pager || true
fi
systemctl status ensure-inference-services.service --no-pager || true
echo "Running containers:"
docker ps || true
