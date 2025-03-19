# Deployment Guide

This guide provides step-by-step instructions for deploying the Container Registry with vLLM integration.

## Prerequisites

### System Requirements

- **Registry Servers**:
  - Debian 11+ (Bullseye or newer)
  - 4+ CPU cores
  - 8+ GB RAM
  - 100+ GB storage space (SSD recommended)

- **vLLM Servers**:
  - Debian 11+ (Bullseye or newer)
  - 8+ CPU cores
  - 16+ GB RAM
  - 1+ NVIDIA GPU (at least 16GB VRAM recommended)
  - 100+ GB storage space (SSD)

### Software Requirements

On the deployment machine:
- Ansible 2.9+
- Python 3.8+
- SSH access to all target servers

## Deployment Steps

### 1. Prepare the Deployment Environment

Clone the repository to your deployment machine:

```bash
git clone https://github.com/yourusername/container-registry.git
cd container-registry
```

### 2. Configure the Inventory

Edit the inventory file at `ansible/inventory/hosts.yml` to specify your server details:

```yaml
all:
  children:
    registry_servers:
      hosts:
        registry01:
          ansible_host: 192.168.1.101  # Replace with actual IP
    vllm_servers:
      hosts:
        vllm01:
          ansible_host: 192.168.1.201  # Replace with actual IP
  vars:
    ansible_user: debian  # Replace with your SSH user
    ansible_ssh_private_key_file: ~/.ssh/id_rsa  # Path to your SSH key
```

### 3. Configure Role Variables (Optional)

You can customize the deployment by modifying the variables in:
- `ansible/roles/registry/defaults/main.yml` - Registry configuration
- `ansible/roles/vllm/defaults/main.yml` - vLLM configuration

Important variables to consider:
- `registry_storage_path`: Where registry data will be stored
- `registry_auth_username` and `registry_auth_password`: Credentials for registry access
- `vllm_model`: The Hugging Face model ID to deploy
- `vllm_tensor_parallel_size`: Number of GPUs to use for tensor parallelism

### 4. Run the Deployment

From the `ansible` directory, run:

```bash
cd ansible
ansible-playbook site.yml
```

For a phased deployment, you can run specific roles:

```bash
# Deploy only common prerequisites to all servers
ansible-playbook site.yml --tags common

# Deploy only the registry
ansible-playbook site.yml --tags registry

# Deploy only vLLM
ansible-playbook site.yml --tags vllm
```

### 5. Verify the Deployment

#### Registry Verification

Check if the registry is running:

```bash
ssh debian@registry-server '/usr/local/bin/registry-status.sh'
```

Test pushing an image:

```bash
# Log in to your registry
docker login registry-server:5000 -u admin -p your_password

# Pull a test image
docker pull hello-world

# Tag and push to your registry
docker tag hello-world registry-server:5000/hello-world
docker push registry-server:5000/hello-world
```

#### vLLM Verification

Check if vLLM is running:

```bash
ssh debian@vllm-server '/usr/local/bin/vllm-status.sh'
```

Test the inference API:

```bash
curl -X POST http://vllm-server:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Hello, world!",
    "max_tokens": 50,
    "temperature": 0.7
  }'
```

## Post-Deployment Configuration

### Registry Configuration

1. **Replace SSL Certificates**:
   For production, replace the self-signed certificates with proper ones:
   ```bash
   # Copy your certificates to the server
   scp your-cert.crt debian@registry-server:/etc/registry/certs/registry.crt
   scp your-key.key debian@registry-server:/etc/registry/certs/registry.key
   
   # Restart the registry
   ssh debian@registry-server 'docker restart registry'
   ```

2. **Configure External Authentication**:
   For advanced authentication, update the registry configuration to use:
   - LDAP
   - OAuth
   - Custom token-based authentication

### vLLM Configuration

1. **Model Replacement**:
   To use a different model:
   ```bash
   # SSH to the vLLM server
   ssh debian@vllm-server
   
   # Edit the vLLM defaults
   sudo vi /etc/ansible/roles/vllm/defaults/main.yml
   
   # Update the vllm_model variable, then rerun Ansible
   ```

2. **Performance Tuning**:
   Optimize vLLM settings based on your hardware and workloads:
   - Adjust batch sizes
   - Configure tensor parallelism
   - Enable/disable quantization

## Troubleshooting

If you encounter issues during deployment:

1. Check Ansible logs for specific errors
2. Verify network connectivity between deployment machine and servers
3. Ensure all prerequisites are installed
4. Verify SSH access to all servers
5. Check server resource availability
6. Consult the maintenance guide for specific component troubleshooting

For persistent issues, check:
- `/var/log/syslog` on the servers
- Docker logs: `docker logs registry` or `docker logs vllm-server`
- Ansible log with increased verbosity: `ansible-playbook site.yml -vvv`
