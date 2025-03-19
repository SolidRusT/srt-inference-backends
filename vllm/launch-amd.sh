#!/bin/bash
SERVICE_VERSION="vllm-v0.2.6"
SERVICE_IMAGE="embeddedllminfo/vllm-rocm:${SERVICE_VERSION}"

# https://docs.vllm.ai/en/latest/models/engine_args.html
docker run \
    --group-add=video \
    --ipc=host \
    --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined \
    --device /dev/kfd \
    --device /dev/dri \
    -v ~/.cache/huggingface:/root/.cache/huggingface \
    --env "HUGGING_FACE_HUB_TOKEN=${HF_TOKEN}" \
    -p 8000:8000 \
    --ipc=host \
    ${SERVICE_IMAGE} \
    --model cognitivecomputations/dolphin-2.6-mistral-7b-dpo-laser \
    --tokenizer-mode auto \
    --trust-remote-code \
    --dtype auto \
    --max-model-len 8192 \
    --tensor-parallel-size 2 \
    --gpu-memory-utilization 0.84
