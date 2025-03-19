# Inference Infrastructure Installation Guide

This document provides step-by-step instructions for setting up the Inference Infrastructure with Debian, vLLM, and Ansible.

## Overview

The system consists of:

1. **Controller Node**: Machine running Ansible to manage all inference nodes
2. **Inference Nodes**: Debian machines with NVIDIA GPUs running containerized vLLM

## Prerequisites

### Controller Node
- Debian-based Linux distribution (Debian, Ubuntu, etc.)
- Python 3.8+
- SSH access to all inference nodes
- Network connectivity to all inference nodes

### Inference Nodes
- Debian 12 (bookworm)
- NVIDIA GPU(s) with CUDA support
- At least 16GB RAM (32GB+ recommended)
- At least 100GB free disk space
- Network connectivity

## Quick Start

### 1. Set Up the Controller

Clone this repository:

```bash
git clone https://your-repository-url.git inference
cd inference
```

Run the setup script:

```bash
chmod +x setup-controller.sh
./setup-controller.sh
```

This will:
- Install required packages
- Install Ansible
- Set up the SSH key
- Prepare the environment

### 2. Configure Your Inventory

Edit the inventory file to include your inference nodes:

```bash
nano ansible/inventory.yml
```

Example configuration:

```yaml
all:
  children:
    inference_nodes:
      hosts:
        node1:
          ansible_host: 192.168.1.101
          ansible_user: shaun
        node2:
          ansible_host: 192.168.1.102
          ansible_user: shaun
      vars:
        ansible_python_interpreter: /usr/bin/python3
```

### 3. Copy SSH Key to Inference Nodes

For each inference node:

```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub username@node-ip
```

### 4. Test Connection

Verify that Ansible can connect to all nodes:

```bash
cd ansible
ansible inference_nodes -m ping
```

### 5. Deploy Infrastructure

Run the master playbook to set up everything:

```bash
cd ansible
ansible-playbook master.yml
```

This will:
- Configure the OS
- Install NVIDIA drivers and CUDA
- Set up Docker with NVIDIA runtime
- Deploy vLLM
- Configure monitoring
- Set up backup systems
- Deploy auto-recovery tools

### 6. Verify Deployment

Check the status of all nodes:

```bash
./monitor-nodes.sh
```

Test the vLLM API:

```bash
ansible inference_nodes -a "sudo /opt/inference/vllm/test-vllm.py"
```

## Advanced Setup

### Custom Model Setup

To use a different model:

```bash
cd ansible
ansible-playbook playbooks/update-model.yml
```

Follow the prompts to specify:
- Model name (e.g., meta-llama/Meta-Llama-3-8B)
- Maximum context length
- GPU memory utilization
- Maximum number of sequences
- Tensor parallel size (for multi-GPU setups)

### Optimizing vLLM Parameters

To avoid out-of-memory errors and optimize performance, you can get hardware-specific parameter recommendations:

```bash
cd ansible
ansible-playbook playbooks/optimize-vllm.yml
```

This will analyze the GPU on each node and provide recommended values for:
- `vllm_gpu_memory`: Controls how much GPU memory vLLM will use (0.0-1.0)
- `vllm_max_num_seqs`: Maximum number of concurrent sequences/requests
- `vllm_max_model_len`: Maximum sequence length supported

These recommendations help avoid CUDA out-of-memory errors during initialization and operations.

### Monitoring Configuration

The system is preconfigured to export metrics for Prometheus. Point your Prometheus server to scrape from:

```
http://<node-ip>:9100/metrics
```

Key metrics:
- NVIDIA GPU metrics (temperature, memory, utilization)
- vLLM container metrics (CPU, memory, network)

### Maintenance Tasks

Common maintenance commands:

```bash
# Update system packages
cd ansible
ansible-playbook playbooks/maintenance.yml --tags update

# Clean up Docker resources
ansible-playbook playbooks/maintenance.yml --tags clean

# Restart services
ansible-playbook playbooks/maintenance.yml --tags restart

# Check system status
ansible-playbook playbooks/maintenance.yml --tags status
```

### Adding New Nodes

To add a new inference node:

```bash
./add-node.sh -n node3 -i 192.168.1.103 -u shaun
./update-nodes.sh -l node3
```

## Special Considerations for WSL Users

If you're running Ansible from Windows Subsystem for Linux (WSL) with the project located in a Windows directory (e.g., /mnt/c/...), you'll need to use the following adaptations:

1. **Always specify the inventory file** with all Ansible commands:
   ```bash
   ansible -i inventory.yml inference_nodes -m ping
   ansible-playbook -i inventory.yml site.yml
   ```

2. **Use the provided scripts** which already include the `-i inventory.yml` parameter:
   ```bash
   ./update-nodes.sh
   ./monitor-nodes.sh
   ./check-logs.sh
   ```

## Troubleshooting

### vLLM Service Not Starting

Check the logs:

```bash
ansible inference_nodes -a "sudo journalctl -u vllm.service -n 50"
```

Common issues:
- GPU driver not properly initialized
- Docker issues
- Network connectivity problems

Run the recovery playbook:

```bash
cd ansible
ansible-playbook playbooks/recovery.yml --tags execute_recovery
```

### NVIDIA Driver Issues

If the GPU is not detected:

```bash
ansible inference_nodes -a "sudo /opt/inference/scripts/recovery.sh"
```

If that doesn't resolve the issue, you may need to reinstall the NVIDIA drivers:

```bash
cd ansible
ansible-playbook site.yml --tags nvidia
```

## Backup and Recovery

The system automatically creates daily backups of:
- Configuration files
- Service definitions
- Log files

Backups are stored in `/opt/inference/backups/` on each node.

To manually trigger a backup:

```bash
ansible inference_nodes -a "sudo /opt/inference/backups/backup-inference.sh"
```
