echo "===== Setting up GPU environment ====="
  
# Install NVIDIA drivers (newer version)
apt-get install -y linux-headers-$(uname -r)
apt-get install -y software-properties-common
add-apt-repository -y ppa:graphics-drivers/ppa
apt-get update
apt-get install -y nvidia-driver-525 # Using a specific version for stability
  
# Add NVIDIA repository for Docker runtime
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
apt-get update
  
# Install NVIDIA Docker runtime
apt-get install -y nvidia-docker2
  
# Configure Docker to use NVIDIA runtime
cat > /etc/docker/daemon.json << 'EOJ'
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
EOJ
  
# Restart Docker to apply changes
systemctl restart docker
  
# Verify NVIDIA setup
nvidia-smi || echo "NVIDIA drivers not loaded correctly. Check installation."