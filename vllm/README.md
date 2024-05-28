# vLLM - SRT Inference Backeneds

## How to configure the vLLM inference service

### Basic vLLM Provider

Launch a vLLM backend using a python virtual environment.

```bash
#export HF_TOKEN=<your_huggingface_token>
python -m venv ~/venv-vllm
source ~/venv-vllm/bin/activate
pip install vllm openai autoawq --no-cache-dir

python -m vllm.entrypoints.openai.api_server --model solidrust/Mistral-7B-instruct-v0.3-AWQ --dtype auto --api-key $HF_TOKEN --max-model-len 28350 --device auto --gpu-memory-utilization 0.98 --quantization awq --enforce-eager --tensor-parallel-size 2 --port 8081
```

Launch a backend using NVIDIA Docker.

```bash
model="solidrust/Mistral-7B-instruct-v0.3-AWQ"  # Quantized model
#model="mistralai/Mistral-7B-instruct-v0.3"  # Production model

# vLLM NVIDIA example
# https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html

docker run --runtime nvidia --gpus all \
    -v ~/.cache/huggingface:/root/.cache/huggingface \
    --env "HUGGING_FACE_HUB_TOKEN=${HF_TOKEN}" \
    -p 8081:8000 \
    --ipc=host \
    vllm/vllm-openai:latest \
    --model $model --tokenizer $model \
    --trust-remote-code \
    --dtype auto \
    --device auto \
    --engine-use-ray \
    --tensor-parallel-size 2 \
    --gpu-memory-utilization 0.90 \
    --quantization awq \
    --max-model-len 32768
```

### Thanatos inference vLLM AWQ example

Open a tmux or screens session, and launch the vLLM server using docker.

```bash
#export HF_TOKEN=<your_huggingface_token>
docker run --runtime nvidia --gpus all     -v ~/.cache/huggingface:/root/.cache/huggingface     --env "HUGGING_FACE_HUB_TOKEN=${HF_TOKEN}"     -p 8081:8000     --ipc=host     vllm/vllm-openai:latest     --model solidrust/Mistral-7B-instruct-v0.3-AWQ --tokenizer solidrust/Mistral-7B-instruct-v0.3-AWQ --trust-remote-code --dtype auto --device auto --gpu-memory-utilization 0.98 --quantization awq  --max-model-len 28350 --enforce-eager
```

Test inference using curl.

```bash
curl -f -X POST http://thanatos:8081/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "solidrust/Mistral-7B-instruct-v0.3-AWQ",
    "prompt": "Role: You are a creative and imaginative storywriter.\nInstruction: Write a simple and engaging poem about who kicked my dog.\nInput:",
    "max_tokens": 512,
    "temperature": 5
  }'
```

### Zelus inference vLLM

Meta Llama-3 8B Instruct AWQ example.

```bash
#export HF_TOKEN=<your_huggingface_token>
model="solidrust/Meta-Llama-3-8B-Instruct-AWQ"
max_gpu=0.95
#max_model_len=65535
max_model_len=8192
local_port=8081

docker run --runtime nvidia --gpus all -v ~/.cache/huggingface:/root/.cache/huggingface --env "HUGGING_FACE_HUB_TOKEN=${HF_TOKEN}" -p $local_port:8000 --ipc=host \
  vllm/vllm-openai:latest \
  --model $model --tokenizer $model --trust-remote-code --dtype auto --kv-cache-dtype auto --gpu-memory-utilization $max_gpu --max-model-len $max_model_len --device auto --enforce-eager
```

or (broken)

```bash
Zelus-AI$ python -m vllm.entrypoints.openai.api_server --model microsoft/Phi-3-mini-128k-instruct --dtype auto --max-model-len 65536 --device auto --gpu-memory-utilization 0.95 --enforce-eager --port 8081
```

```bash
curl -f -X POST http://zelus:8081/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "solidrust/Meta-Llama-3-8B-Instruct-AWQ",
    "prompt": "Role: You are a creative and imaginative storywriter.\nInstruction: Write a simple and engaging poem about who kicked my dog.\nInput:",
    "max_tokens": 512,
    "temperature": 5
  }'
```

### [WIP] vLLM ray server (optional)

```bash
python -m venv ~/venv-vllm
source ~/venv-vllm/bin/activate
pip install ray
```

#### Server only

```bash
#export HF_TOKEN=<your_huggingface_token>
ray start --head
# Save this connection address var as RAY_HEAD_ADDRESS on your clients.
```

Launch a vLLM backend using python within the ray server head node environment.

```bash
python -m vllm.entrypoints.openai.api_server --model solidrust/Mistral-7B-instruct-v0.3-AWQ --dtype auto --max-model-len 28350 --device auto --gpu-memory-utilization 0.98 --quantization awq --enforce-eager --port 8081

python -m vllm.entrypoints.openai.api_server --model solidrust/Meta-Llama-3-8B-Instruct-AWQ --dtype auto --max-model-len 8192 --device auto --gpu-memory-utilization 0.98 --quantization awq --enforce-eager --port 8081
```

Play with the `--tensor-parallel-size 2` to distribute the work across the ray server client nodes.

#### Client only

Add a client node to the ray server

```bash
#export RAY_HEAD_ADDRESS=<ray-head-address>
ray start --address=$RAY_HEAD_ADDRESS
```
