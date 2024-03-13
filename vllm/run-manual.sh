#!/bin/bash
# https://docs.vllm.ai/en/latest/serving/distributed_serving.html

# Setup Python - not required when using nvidia-python docker.
VENV="${HOME}/venv-vLLM"
pyenv update
pyenv install -f 3.11
pyenv shell 3.11
rm -rf ${VENV}
python -m venv ${VENV}
source ${VENV}/bin/activate

# Setup vLLM
pip install ray vllm

python -m vllm.entrypoints.api_server \
--model cognitivecomputations/dolphin-2.6-mistral-7b-dpo-laser \
--tensor-parallel-size 2 \
--device auto \
--dtype auto \
--kv-cache-dtype auto \
--max-model-len 8192

#usage: api_server.py [-h] [--host HOST] [--port PORT] [--ssl-keyfile SSL_KEYFILE] [--ssl-certfile SSL_CERTFILE]
#                     [--root-path ROOT_PATH] [--model MODEL] [--tokenizer TOKENIZER] [--revision REVISION]
#                     [--code-revision CODE_REVISION] [--tokenizer-revision TOKENIZER_REVISION]
#                     [--tokenizer-mode {auto,slow}] [--trust-remote-code] [--download-dir DOWNLOAD_DIR]
#                     [--load-format {auto,pt,safetensors,npcache,dummy}]
#                     [--dtype {auto,half,float16,bfloat16,float,float32}] [--kv-cache-dtype {auto,fp8_e5m2}]
#                     [--max-model-len MAX_MODEL_LEN] [--worker-use-ray]
#                     [--pipeline-parallel-size PIPELINE_PARALLEL_SIZE] [--tensor-parallel-size TENSOR_PARALLEL_SIZE]
#                     [--max-parallel-loading-workers MAX_PARALLEL_LOADING_WORKERS] [--block-size {8,16,32,128}]
#                     [--seed SEED] [--swap-space SWAP_SPACE] [--gpu-memory-utilization GPU_MEMORY_UTILIZATION]
#                     [--max-num-batched-tokens MAX_NUM_BATCHED_TOKENS] [--max-num-seqs MAX_NUM_SEQS]
#                     [--max-paddings MAX_PADDINGS] [--disable-log-stats] [--quantization {awq,gptq,squeezellm,None}]
#                     [--enforce-eager] [--max-context-len-to-capture MAX_CONTEXT_LEN_TO_CAPTURE]
#                     [--disable-custom-all-reduce] [--enable-lora] [--max-loras MAX_LORAS]
#                     [--max-lora-rank MAX_LORA_RANK] [--lora-extra-vocab-size LORA_EXTRA_VOCAB_SIZE]
#                     [--lora-dtype {auto,float16,bfloat16,float32}] [--max-cpu-loras MAX_CPU_LORAS]
#                     [--device {auto,cuda,neuron}] [--engine-use-ray] [--disable-log-requests]
#                     [--max-log-len MAX_LOG_LEN]