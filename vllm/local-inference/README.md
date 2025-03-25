# Local Inference Infrastructure Automation

This repository contains Ansible automation for deploying and managing GPU-enabled inference nodes running vLLM on Debian Linux.

## Prerequisites

- Debian Linux servers with NVIDIA GPUs
- SSH access to the servers
- Ansible installed on the control machine

## Setup

1. Edit the `ansible/inventory.yml` file to include your server information:

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
```

2. Customize variables in `ansible/group_vars/all.yml` if needed.

## Usage

### Deploy the Full Stack

```bash
cd ansible
ansible-playbook site.yml
```

### Run Only Specific Roles

```bash
# Set up only the NVIDIA drivers and CUDA
ansible-playbook -i inventory.yml site.yml --tags nvidia

# Set up only Docker
ansible-playbook -i inventory.yml site.yml --tags docker

# Set up only vLLM
ansible-playbook -i inventory.yml site.yml --tags vllm
```

### Check Configuration

```bash
# Verify the setup without making changes
ansible-playbook -i inventory.yml site.yml --check
```

### Note for WSL Users

If you're running Ansible from WSL (Windows Subsystem for Linux) with the project located in a Windows directory (e.g., /mnt/c/...), you'll need to explicitly specify the inventory file with `-i inventory.yml` for all commands because Ansible ignores config files in world-writable directories for security reasons.

For example:

```bash
# Check connectivity
ansible -i inventory.yml inference_nodes -m ping

# Run playbooks
ansible-playbook -i inventory.yml site.yml
```

## vLLM Configuration

The system is configured with the following vLLM settings by default:

```yaml
# vLLM configuration
vllm_model: "solidrust/Hermes-3-Llama-3.1-8B-AWQ"
vllm_port: "8081"
vllm_max_model_len: "14992"
vllm_gpu_memory: "0.98"
vllm_tensor_parallel_size: "1"
vllm_logging_level: "DEBUG"
vllm_image_tag: "latest"
vllm_tool_call_parser: "hermes"
```

These settings can be customized in `ansible/group_vars/all.yml` or by using the model update playbook.

### HuggingFace Token

If you're using models that require authentication, you can set your HuggingFace token by uncommenting and setting the `huggingface_token` variable in `ansible/group_vars/all.yml`:

```yaml
huggingface_token: "your_token_here"
```

You can also provide it when running the model update playbook.

## Components

The automation includes the following components:

1. **Common Setup**: Basic system configuration and essential packages
2. **NVIDIA Setup**: NVIDIA drivers, CUDA, and container toolkit
3. **Docker Setup**: Docker CE with NVIDIA runtime
4. **vLLM Setup**: vLLM inference server running in Docker

## Directory Structure

```
├── ansible
│   ├── group_vars
│   │   └── all.yml
│   ├── inventory.yml
│   ├── roles
│   │   ├── common
│   │   │   └── tasks
│   │   │       └── main.yml
│   │   ├── docker_setup
│   │   │   └── tasks
│   │   │       └── main.yml
│   │   ├── nvidia_setup
│   │   │   └── tasks
│   │   │       └── main.yml
│   │   └── vllm_setup
│   │       └── tasks
│   │           └── main.yml
│   ├── site.yml
│   └── templates
│       ├── daemon.json.j2
│       ├── docker.list.j2
│       ├── nvidia-container-toolkit.list.j2
│       ├── sources.list.j2
│       ├── start-vllm.sh.j2
│       └── vllm.service.j2
```

## Maintenance

### Adding New Servers

Edit the `ansible/inventory.yml` file to add new servers to the `inference_nodes` group.

### Updating vLLM Configuration

Edit the variables in `ansible/group_vars/all.yml` to change the vLLM configuration.

### Optimizing vLLM Parameters

To optimize vLLM parameters based on the hardware capabilities of your nodes, run:

```bash
cd ansible
ansible-playbook playbooks/optimize-vllm.yml
```

This will analyze the GPU memory on each node and provide recommended settings for:
- `vllm_gpu_memory`: GPU memory utilization (0.0-1.0)
- `vllm_max_num_seqs`: Maximum number of concurrent sequences
- `vllm_max_model_len`: Maximum model sequence length

These recommendations can be applied by updating `ansible/group_vars/all.yml` or by setting host-specific variables in your inventory.

### Custom Models

To use a different model, you can use the model update playbook:

```bash
cd ansible
ansible-playbook playbooks/update-model.yml
```

This will prompt you for the model name, context length, and other parameters.

## Monitoring and Maintenance

### Monitoring

The system includes monitoring scripts that export GPU and vLLM metrics for Prometheus. To set up monitoring:

```bash
cd ansible
ansible-playbook playbooks/monitoring.yml
```

### Health Checks and Auto-Recovery

The system includes automatic health checks and recovery procedures for the vLLM service. To set up the recovery tools:

```bash
cd ansible
ansible-playbook playbooks/recovery.yml
```

To manually trigger recovery on all nodes:

```bash
cd ansible
ansible-playbook playbooks/recovery.yml --tags execute_recovery
```

### Backups

The system automatically creates backups of critical configuration files and logs. To set up the backup system:

```bash
cd ansible
ansible-playbook playbooks/backup.yml
```

### Routine Maintenance

To perform routine maintenance tasks (updates, restarts, cleaning):

```bash
cd ansible
ansible-playbook playbooks/maintenance.yml --tags update      # Update packages
ansible-playbook playbooks/maintenance.yml --tags restart     # Restart services
ansible-playbook playbooks/maintenance.yml --tags clean       # Clean Docker resources
ansible-playbook playbooks/maintenance.yml --tags status      # Check system status
```

## Utilities

### Monitoring Nodes

Use the provided monitoring script to check the status of all nodes:

```bash
./monitor-nodes.sh
```

To check a specific node:

```bash
./monitor-nodes.sh --limit node1
```

### Testing vLLM API

Each node has a test script that can be used to verify the vLLM API:

```bash
ssh user@node1
sudo /opt/inference/vllm/test-vllm.py
```

For more comprehensive testing, use the included interactive test client:

```bash
python test-inference.py -i
```

This allows you to send text completions and chat completions to the vLLM service. See [TESTING.md](TESTING.md) for detailed instructions on testing the inference service.

### Upgrade debian distribution

```bash
SERVERS=(erebus thanatos zelus kratos nyx)

for server in ${SERVERS[@]}; do ssh -tq $server "sudo apt dist-upgrade -y"; done
```

### UEFI boot

From the [Debian Wiki](https://wiki.debian.org/SecureBoot#Adding_your_key_to_DKMS):

```bash
sudo mokutil --import /var/lib/dkms/mok.pub # prompts for one-time password
sudo mokutil --list-new # recheck your key will be prompted on next boot
```
