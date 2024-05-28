# SolidRust TGI

## Pre-requisites

- [Docker](https://docs.docker.com/get-docker/)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

## Build

```bash
TAG="v1.0.0"
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 078744956360.dkr.ecr.us-west-2.amazonaws.com

docker pull ghcr.io/huggingface/text-generation-inference:latest
docker build -t solidrust/solidrust-tgi .

docker tag solidrust/solidrust-tgi:latest 078744956360.dkr.ecr.us-west-2.amazonaws.com/solidrust/solidrust-tgi:latest
docker tag solidrust/solidrust-tgi:latest 078744956360.dkr.ecr.us-west-2.amazonaws.com/solidrust/solidrust-tgi:${TAG}

docker push 078744956360.dkr.ecr.us-west-2.amazonaws.com/solidrust/solidrust-tgi:latest
docker push 078744956360.dkr.ecr.us-west-2.amazonaws.com/solidrust/solidrust-tgi:${TAG}
```

Using the image:

```bash
docker pull 078744956360.dkr.ecr.us-west-2.amazonaws.com/solidrust/solidrust-tgi:latest
```

Curl inference example:

```bash
# https://huggingface.co/docs/text-generation-inference/main/en/messages_api
curl erebus:8081/v1/chat/completions \
    -X POST \
    -d '{
  "model": "solidrust/dolphin-2.9-llama3-8b-AWQ",
  "messages": [
    {
      "role": "system",
      "content": "You are a helpful assistant."
    },
    {
      "role": "user",
      "content": "What is deep learning?"
    }
  ],
  "stream": false,
  "max_tokens": 100
}' \
    -H 'Content-Type: application/json'
```

### TGI NVIDIA

```bash
#!/bin/bash
# model="solidrust/Mistral-7B-instruct-v0.3-AWQ"
model=${MODEL}
num_shard=${NUM_SHARD}
volume="${HOME}/${HOSTNAME}-AI/text-generation" # share a volume
service_version=${SERVICE_VERSION}
service_port=${SERVICE_PORT}
max_input_length=${MAX_INPUT_LENGTH}
max_total_tokens=${MAX_TOTAL_TOKENS}
max_batch_prefill_tokens=${MAX_PREFILL_TOKENS}
gpus=${GPUS}
image_uri=${IMAGE_URI}
token=${HUGGING_FACE_HUB_TOKEN}

# test
#docker run --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
# --gpus '"device=0,2"'

# update the cache
docker pull $image_uri:$service_version

# run
docker run --gpus "device=$gpus" --shm-size 4g -p $service_port:80 \
  -e HUGGING_FACE_HUB_TOKEN=$token \
  -v $volume:/data $image_uri:$service_version \
  --model-id $model --num-shard $num_shard \
  --trust-remote-code \
  --max-concurrent-requests 128 \
  --max-best-of 2 \
  --max-stop-sequences 4 \
  --max-input-length $max_input_length \
  --max-total-tokens $max_total_tokens \
  --max-batch-prefill-tokens $max_batch_prefill_tokens \
  --quantize awq
```

### TGI AMD ROCm

```bash
model=meta-llama/Meta-Llama-3-8B-Instruct
volume=$PWD/data
token=$HF_TOKEN

docker run --rm -it --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
    --device=/dev/kfd --device=/dev/dri --group-add video \
    --ipc=host --shm-size 256g --net host -v $volume:/data -e HUGGING_FACE_HUB_TOKEN=$token \
    ghcr.io/huggingface/text-generation-inference:2.0.4-rocm \
    --model-id $model
```
