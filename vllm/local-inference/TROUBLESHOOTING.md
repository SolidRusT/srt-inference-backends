# Troubleshooting Guide

This document provides solutions for common issues you might encounter when using the Inference Infrastructure automation.

## Ansible Issues

### "Ansible is being run in a world writable directory, ignoring it as an ansible.cfg source"

**Problem**: When running Ansible commands from WSL in a Windows directory, you see:
```
[WARNING]: Ansible is being run in a world writable directory, ignoring it as an ansible.cfg source.
[WARNING]: No inventory was parsed, only implicit localhost is available
```

**Solution**: Always explicitly specify the inventory file with the `-i` flag:
```bash
ansible -i inventory.yml inference_nodes -m ping
ansible-playbook -i inventory.yml site.yml
```

Or use the provided utility scripts which already include this parameter:
```bash
./update-nodes.sh
./monitor-nodes.sh
./check-logs.sh
```

**Explanation**: For security reasons, Ansible ignores configuration files in world-writable directories, which is how Windows directories appear when accessed from WSL.

### Task Hanging at "Add NVIDIA GPG key to keyring"

**Problem**: The deployment hangs at the "Add NVIDIA GPG key to keyring" task:

```
TASK [nvidia_setup : Add NVIDIA container toolkit repository key] ******************************************************
changed: [nyx]

TASK [nvidia_setup : Add NVIDIA GPG key to keyring] ********************************************************************
```

**Solution**: Use the `--skip-gpg` flag with the update-nodes.sh script:

```bash
./update-nodes.sh --skip-gpg
```

This will bypass the problematic GPG key operations while still setting up the rest of the system.

Alternatively, you can manually create the keyring file on the target nodes:

```bash
sudo touch /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
sudo chmod 644 /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
```

Then run Ansible again and it will skip these tasks.

### "SSH Permission Denied" or "Host Key Verification Failed"

**Problem**: Ansible can't connect to your nodes via SSH:
```
node1 | UNREACHABLE! => {
    "changed": false,
    "msg": "Failed to connect to the host via ssh: Permission denied (publickey,password).",
    "unreachable": true
}
```

**Solutions**:
1. Ensure you've copied your SSH key to the node:
   ```bash
   ssh-copy-id -i ~/.ssh/id_rsa.pub user@host
   ```

2. Manually try SSH first to accept the host key:
   ```bash
   ssh user@host
   ```

3. Check if you can connect with password by modifying your inventory:
   ```yaml
   node1:
     ansible_host: 192.168.1.101
     ansible_user: shaun
     ansible_ssh_pass: your_password
     ansible_become_pass: your_password
   ```

## vLLM Issues

### vLLM Service Not Starting

**Problem**: The vLLM service fails to start or keeps restarting.

**Solutions**:

1. Check the logs:
   ```bash
   ./check-logs.sh
   ```

2. Verify Docker and NVIDIA setup:
   ```bash
   ansible -i inventory.yml inference_nodes -m shell -a "docker info | grep -i nvidia"
   ansible -i inventory.yml inference_nodes -m shell -a "nvidia-smi"
   ```

3. Try running the recovery playbook:
   ```bash
   ansible-playbook -i inventory.yml playbooks/recovery.yml --tags execute_recovery
   ```

### CUDA Out of Memory During Startup

**Problem**: The vLLM service fails with a "CUDA out of memory" error during startup, particularly during sampler warmup:

```
RuntimeError: CUDA out of memory occurred when warming up sampler with 1024 dummy requests. Please try lowering `max_num_seqs` or `gpu_memory_utilization` when initializing the engine.
```

**Solutions**:

1. Lower the GPU memory utilization in `ansible/group_vars/all.yml`:
   ```yaml
   vllm_gpu_memory: "0.80"  # Reduce from 0.98/0.85 to a lower value
   ```

2. Decrease the maximum number of concurrent sequences:
   ```yaml
   vllm_max_num_seqs: "32"  # Reduce from 64 to a lower value
   ```

3. Re-deploy the configuration:
   ```bash
   ansible-playbook -i inventory.yml site.yml --tags vllm
   ```

4. For very low memory environments, consider using a smaller model or more aggressive quantization.

### Model Download Errors

**Problem**: vLLM can't download the model due to authentication issues.

**Solution**: If you're using a model that requires authentication, make sure to provide your HuggingFace token:

1. Edit `ansible/group_vars/all.yml` and add:
   ```yaml
   huggingface_token: "your_token_here"
   ```

2. Or use the model update playbook and provide the token when prompted:
   ```bash
   ansible-playbook -i inventory.yml playbooks/update-model.yml
   ```

## NVIDIA Driver Issues

### "NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver"

**Problem**: The NVIDIA driver isn't loaded properly.

**Solutions**:

1. Run the recovery script:
   ```bash
   ansible -i inventory.yml inference_nodes -m shell -a "sudo /opt/inference/scripts/recovery.sh"
   ```

2. Reinstall the NVIDIA components:
   ```bash
   ansible-playbook -i inventory.yml site.yml --tags nvidia
   ```

3. Check if Secure Boot is enabled and properly configured:
   ```bash
   ansible -i inventory.yml inference_nodes -m shell -a "sudo mokutil --sb-state"
   ```

## Docker Issues

### Docker Can't Access GPU

**Problem**: Docker can't see or use the NVIDIA GPU.

**Solutions**:

1. Verify NVIDIA Container Toolkit is properly set up:
   ```bash
   ansible -i inventory.yml inference_nodes -m shell -a "sudo nvidia-ctk runtime configure --runtime=docker"
   ```

2. Restart Docker service:
   ```bash
   ansible -i inventory.yml inference_nodes -m shell -a "sudo systemctl restart docker"
   ```

3. Verify Docker can see GPUs:
   ```bash
   ansible -i inventory.yml inference_nodes -m shell -a "docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi"
   ```

## Performance Issues

### High GPU Memory Usage

**Problem**: The vLLM service is using too much GPU memory.

**Solution**: Adjust the GPU memory utilization setting in `ansible/group_vars/all.yml`:
```yaml
vllm_gpu_memory: "0.80"  # Use 80% of available GPU memory
```

Then restart the service:
```bash
ansible -i inventory.yml inference_nodes -m shell -a "sudo systemctl restart vllm"
```

### Slow Model Loading

**Problem**: Model takes a long time to load when starting vLLM.

**Solutions**:

1. Use an AWQ quantized model for faster loading and reduced memory usage
2. Enable persistent cache by ensuring the HuggingFace cache is mounted correctly
3. Increase system swap space if RAM is limited:
   ```bash
   ansible -i inventory.yml inference_nodes -m shell -a "sudo fallocate -l 16G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
   ```
