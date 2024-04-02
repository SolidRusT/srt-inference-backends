#!/bin/bash

volume="${HOME}/hf_models"

docker run --gpus all --shm-size 1g \
  --group-add=video \
  --ipc=host \
  --cap-add=SYS_PTRACE \
  --security-opt seccomp=unconfined \
  --device /dev/kfd \
  --device /dev/dri \
  -p 8091:8091 \
  -v $volume:/data \
  solidrust/tabby-api

