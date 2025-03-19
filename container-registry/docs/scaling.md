# Scaling Guide for Container Registry Solution

This document outlines strategies for scaling the Container Registry and vLLM services to handle increased load.

## Registry Scaling

### Horizontal Scaling

The Container Registry can be horizontally scaled by adding more registry servers behind a load balancer:

1. Add new servers to your inventory file:
   ```yaml
   registry_servers:
     hosts:
       registry01:
         ansible_host: 192.168.1.101
       registry02:
         ansible_host: 192.168.1.102
       registry03:  # New server
         ansible_host: 192.168.1.103
   ```

2. Run the Ansible playbook to deploy to the new server:
   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml --limit registry03
   ```

3. Set up a load balancer (e.g., HAProxy, Nginx) in front of all registry instances.

4. Configure shared storage between registry instances:
   - Option 1: Use an NFS mount for `/var/lib/registry`
   - Option 2: Use a cloud storage backend like S3 or Azure Blob Storage (requires modifying `config.yml.j2`)

### Vertical Scaling

To vertically scale a registry server:

1. Increase server resources (CPU, RAM, disk).
2. Tune the Docker daemon settings in `daemon.json.j2` for better performance:
   ```json
   {
     "max-concurrent-downloads": 10,
     "max-concurrent-uploads": 10
   }
   ```

## vLLM Scaling

### Tensor Parallelism

vLLM supports tensor parallelism for distributing model weights across multiple GPUs:

1. Set `vllm_tensor_parallel_size` to the number of GPUs you want to use in `ansible/roles/vllm/defaults/main.yml`:
   ```yaml
   vllm_tensor_parallel_size: 4  # Use 4 GPUs for single inference
   ```

### Horizontal Scaling

To scale vLLM horizontally:

1. Add new vLLM servers to your inventory:
   ```yaml
   vllm_servers:
     hosts:
       vllm01:
         ansible_host: 192.168.1.201
       vllm02:
         ansible_host: 192.168.1.202
       vllm03:  # New server
         ansible_host: 192.168.1.203
   ```

2. Run the Ansible playbook to deploy:
   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml --limit vllm03
   ```

3. Set up a load balancer to distribute inference requests across servers.

### Optimizing Performance

1. **Model Quantization**:
   - Enable quantization to reduce memory footprint:
   ```yaml
   vllm_quantization: "awq"  # or "squeezellm"
   ```

2. **GPU Memory Optimization**:
   - Tune the GPU memory utilization:
   ```yaml
   vllm_gpu_memory_utilization: 0.95  # Use 95% of available GPU memory
   ```

3. **Prefill and Decode Batch Sizes**:
   - Add these parameters to the vLLM server script to optimize throughput:
   ```python
   llm = LLM(
       model=args.model,
       tensor_parallel_size=args.tensor_parallel_size,
       gpu_memory_utilization=args.gpu_memory_utilization,
       max_model_len=args.max_model_len,
       quantization=args.quantization,
       trust_remote_code=True,
       prefill_batch_size=4,  # Adjust based on your workload
       decode_batch_size=16,  # Adjust based on your workload
   )
   ```

## Load Testing

To identify scaling bottlenecks, perform load testing:

1. **Registry Load Testing**:
   ```bash
   docker run -it --rm containersol/docker-bench -t http://registry-url:5000/ -n 1000 -c 50
   ```

2. **vLLM Load Testing**:
   ```bash
   pip install locust
   # Create a locust file and run:
   locust -f vllm_locustfile.py --host=http://vllm-host:8000
   ```

## Monitoring During Scaling

Monitor these key metrics during scaling operations:

- Network throughput between registry instances
- Disk I/O on registry storage
- GPU utilization and memory on vLLM servers
- Request latency under increasing load

Adjust your scaling strategy based on which resources become bottlenecks first.
