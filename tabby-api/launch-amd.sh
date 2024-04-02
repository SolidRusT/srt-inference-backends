#!/bin/bash

volume="${HOME}/hf_models"

sudo docker run -it --shm-size 1g \
  --device=/dev/kfd \
  --device=/dev/dri \
  --ipc=host \
  --cap-add=SYS_PTRACE \
  --security-opt seccomp=unconfined \
  --group-add video \
  -p 8091:8091 \
  -v $volume:/data \
  solidrust/tabby-api \
  
