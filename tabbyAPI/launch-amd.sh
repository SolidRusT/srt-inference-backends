#!/bin/bash

volume="${HOME}/hf_models"

sudo docker run -it --shm-size 1g \
  --device=/dev/kfd \
  --device=/dev/dri \
  --ipc=host \
  --cap-add=SYS_PTRACE \
  --security-opt seccomp=unconfined \
  --group-add video \
  -p 5000:5000 \
  -v $volume:/hf_models \
  -v ./config.yml:/tabbyAPI/config.yml \
  -v ./api_tokens.yml:/tabbyAPI/api_tokens.yml \
  solidrust/tabby-api  
