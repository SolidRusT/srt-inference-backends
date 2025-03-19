# Available Models for Inference Solution

This document lists the models tested and confirmed working with our AWS EC2 Inference Solution. When selecting a model, ensure your EC2 instance has sufficient GPU memory for the model size.

## Recommended Instance Types

| AWS Instance | GPU | VRAM | Suitable For |
|--------------|-----|------|-------------|
| g6.xlarge    | 1x NVIDIA L4 | 24GB | 8B-13B models, quantized models |
| g6.2xlarge   | 1x NVIDIA L4 | 24GB | Same as g6.xlarge but with twice the CPU/RAM |
| g6.4xlarge   | 1x NVIDIA L4 | 24GB | Same as g6.2xlarge but with twice the CPU/RAM and faster network |
| g6.12xlarge  | 4x NVIDIA L4 | 96GB (4x24GB) | 32B+ models, long context models |
| g6.48xlarge  | 8x NVIDIA L4 | 192GB (8x24GB) | Multiple large models, highest throughput |

## Tool Call Parser

vLLM supports different parsers for function/tool calling, which need to be chosen based on the model being used:

| Parser | Recommended For |
|--------|----------------|
| `granite-20b-fc` | Granite 20B models |
| `granite` | Other Granite models |
| `hermes` | Hermes-based models (e.g., Hermes-Llama) |
| `internlm` | InternLM models |
| `jamba` | Jamba models |
| `llama3_json` | Llama 3 models |
| `mistral` | Mistral models |
| `pythonic` | General purpose, works with many models including Qwen |

Using the wrong parser may result in issues with function/tool calling functionality.

## Parallelism Strategy

For large models or instances with multiple GPUs, vLLM supports two parallelism strategies:

1. **Tensor Parallelism** (`tensor_parallel_size`): Splits individual tensors across multiple GPUs.
   - Use when your model is too large to fit on a single GPU
   - Typically set to the number of GPUs on your instance (e.g., 4 for g6.12xlarge)
   - Best for large models where memory is the bottleneck

2. **Pipeline Parallelism** (`pipeline_parallel_size`): Splits the model's layers across multiple GPUs.
   - Use when you have more GPUs than needed for tensor parallelism
   - Creates multiple pipeline stages and enables processing multiple requests simultaneously
   - Best for throughput optimization when serving many concurrent users
   - Typically set to 1 for most workloads

## Supported Models

### Hermes 3 Llama (8B AWQ)
**Model ID:** `solidrust/Hermes-3-Llama-3.1-8B-AWQ`
- **GPU Requirements:** 12GB VRAM minimum
- **Recommended Instance:** g6.xlarge
- **Context Length:** 14,992 tokens
- **Quantization:** AWQ (Activation-aware Weight Quantization)
- **Description:** Optimized custom model based on Llama 3.1 with AWQ quantization for efficient inference
- **Use Cases:** General purpose assistant, content generation, summarization
- **Performance Notes:** Excellent performance-to-resource ratio due to quantization
- **Configuration Settings:**
  - tensor_parallel_size = 1
  - pipeline_parallel_size = 1
  - tool_call_parser = "hermes"

### Llama 3.1 Instruct (8B)
**Model ID:** `meta-llama/Llama-3.1-8B-Instruct`
- **GPU Requirements:** 24GB VRAM
- **Recommended Instance:** g6.xlarge
- **Context Length:** 8,192 tokens
- **Quantization:** None (full precision)
- **Description:** Meta's instruction-tuned model for general-purpose use with industry-leading performance in its size class
- **Use Cases:** Chatbots, instruction following, creative writing
- **Performance Notes:** Good balance of capabilities and resource requirements
- **Configuration Settings:**
  - tensor_parallel_size = 1
  - pipeline_parallel_size = 1
  - tool_call_parser = "llama3_json"

### Qwen QwQ (32B)
**Model ID:** `Qwen/QwQ-32B`
- **GPU Requirements:** 48GB VRAM minimum (tensor parallelism recommended)
- **Recommended Instance:** g6.12xlarge
- **Context Length:** 32,768 tokens (32K)
- **Quantization:** None (full precision)
- **Description:** High-capacity reasoning model with extended context window from Alibaba Cloud
- **Use Cases:** Complex reasoning, long document analysis, specialized knowledge tasks
- **Performance Notes:** 
  - Requires multi-GPU setup for optimal performance
  - With g6.12xlarge (4x24GB GPUs), use tensor parallelism across all 4 GPUs
  - Set `gpu_memory_utilization` to 0.95 for stability
- **Configuration Settings:**
  - tensor_parallel_size = 4 (for g6.12xlarge)
  - pipeline_parallel_size = 1
  - tool_call_parser = "hermes"

## Configuration Examples

Here are examples of terraform.tfvars configurations for different models:

### For Hermes 3 Llama (8B AWQ)
```hcl
# EC2 instance settings
use_gpu_instance  = true
gpu_instance_type = "g6.xlarge"

# vLLM Configuration
model_id               = "solidrust/Hermes-3-Llama-3.1-8B-AWQ"
max_model_len          = 14992
gpu_memory_utilization = 0.98
tensor_parallel_size   = 1
pipeline_parallel_size = 1
tool_call_parser       = "hermes"
```

### For Llama 3.1 Instruct (8B)
```hcl
# EC2 instance settings
use_gpu_instance  = true
gpu_instance_type = "g6.xlarge"

# vLLM Configuration
model_id               = "meta-llama/Llama-3.1-8B-Instruct"
max_model_len          = 8192
gpu_memory_utilization = 0.98
tensor_parallel_size   = 1
pipeline_parallel_size = 1
tool_call_parser       = "llama3_json"
```

### For Qwen QwQ (32B)
```hcl
# EC2 instance settings
use_gpu_instance  = true
gpu_instance_type = "g6.12xlarge"  # Provides 4x24GB GPUs

# vLLM Configuration
model_id               = "Qwen/QwQ-32B"
max_model_len          = 32768
gpu_memory_utilization = 0.95    # reduced for greater stability
tensor_parallel_size   = 4       # Use all 4 GPUs on g6.12xlarge
pipeline_parallel_size = 1
tool_call_parser       = "hermes"  # Seems to work fine with QwQ
```

### For Maximum Throughput on g6.48xlarge
```hcl
# EC2 instance settings
use_gpu_instance  = true
gpu_instance_type = "g6.48xlarge"  # Provides 8x24GB GPUs

# vLLM Configuration
model_id               = "Qwen/QwQ-32B"
max_model_len          = 32768
gpu_memory_utilization = 0.95    # reduced for greater stability
tensor_parallel_size   = 4       # Split model across 4 GPUs
pipeline_parallel_size = 2       # Create 2 pipeline stages for throughput
tool_call_parser       = "hermes"  # Seems to work fine with QwQ
```

## Adding New Models

To add a new model:

1. Verify the model is compatible with vLLM by checking the [vLLM supported models list](https://vllm.readthedocs.io/en/latest/models/supported_models.html)
2. Ensure your HuggingFace token has access to the model (if it's gated)
3. Update `terraform.tfvars` with the appropriate model_id and parameters
4. If needed, adjust the instance type to match GPU requirements
5. Set appropriate tensor_parallel_size and pipeline_parallel_size based on your instance and model
6. Increment the `ec2_instance_version` to force a redeployment
7. Run `terraform apply` to deploy the changes

## Troubleshooting

If you encounter issues when deploying a new model:

1. Check the vLLM logs on the EC2 instance: `docker logs vllm-service`
2. Verify your HuggingFace token is valid: `/usr/local/bin/get-hf-token.sh`
3. For large models, try reducing `gpu_memory_utilization` to 0.8 or lower
4. If the model fails to load, ensure the instance has sufficient GPU memory
5. For multi-GPU setups, verify tensor parallelism is working correctly:
   - Check for logs like "Using tensor parallelism with 4 GPUs"
   - Run `nvidia-smi` to verify all GPUs are being utilized
6. If using pipeline parallelism, ensure you have set the right combination of tensor_parallel_size and pipeline_parallel_size (their product should not exceed the total number of GPUs)
