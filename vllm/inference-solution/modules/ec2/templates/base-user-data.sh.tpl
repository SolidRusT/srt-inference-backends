#!/bin/bash

# Basic bootstrap script
# Instance version: ${instance_version}

# Log everything to a file for debugging
set -ex
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting bootstrap script at $(date)"

# Create directories
mkdir -p /usr/local/bin
mkdir -p /etc/ssl/private
mkdir -p /etc/ssl/certs
mkdir -p /opt/inference/scripts

# Update and install required packages
echo "===== Installing base packages ====="
apt-get update
apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common awscli jq unzip nginx

# Install Docker
echo "===== Installing Docker ====="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Run the utility scripts setup
${utility_scripts}

# Setup GPU if needed
if [ "${use_gpu}" = "true" ]; then
  ${gpu_setup}
fi

# Setup services
${services_setup}

# Setup HTTPS if needed
if [ "${enable_https}" = "true" ]; then
  ${nginx_setup}
fi

# Run the Docker login script
/usr/local/bin/docker-login-ecr.sh || true

# Create a cron job to check for updates every hour
echo "0 * * * * /usr/local/bin/update-inference-app.sh" | crontab -

# Enable and start the services
echo "===== Starting services ====="
systemctl daemon-reload
systemctl enable vllm
systemctl start vllm || echo "Failed to start vLLM service, check logs"
systemctl enable inference-app
systemctl start inference-app || echo "Failed to start inference-app service, check logs"

# Run vLLM test script to check status
echo "===== Running vLLM test script ====="
/usr/local/bin/test-vllm.sh

# Install CloudWatch agent for monitoring
echo "===== Installing monitoring agents ====="
curl -O https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Install SSM agent for management
mkdir -p /tmp/ssm
cd /tmp/ssm
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Reboot after NVIDIA driver installation if GPU is enabled
if [ "${use_gpu}" = "true" ]; then
  echo "===== Scheduling reboot to complete GPU setup ====="
  # Create a startup script to handle post-reboot tasks
  mkdir -p /var/lib/cloud/scripts/per-boot
  cat > /var/lib/cloud/scripts/per-boot/post-reboot-setup.sh << 'EOB'
#!/bin/bash
# Check if NVIDIA drivers are loaded
if ! nvidia-smi > /dev/null 2>&1; then
  echo "NVIDIA drivers not loaded after reboot, trying to reload"
fi

# Make sure services are running
systemctl restart vllm
systemctl restart inference-app

# Run the test script to verify everything
echo "Running post-reboot vLLM test..."
/usr/local/bin/test-vllm.sh > /var/log/post-reboot-vllm-test.log 2>&1
EOB
  chmod +x /var/lib/cloud/scripts/per-boot/post-reboot-setup.sh

  # Schedule a reboot in 1 minute to give cloud-init time to finish
  echo "Scheduling reboot in 1 minute..."
  shutdown -r +1 "Rebooting to complete NVIDIA driver installation"
fi

echo "===== User-data script completed at $(date) ====="
