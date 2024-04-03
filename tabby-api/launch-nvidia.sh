#!/bin/bash

volume="${HOME}/hf_models"

docker run --gpus all --shm-size 1g \
  -p 5000:5000 \
  -v $volume:/data \
  -v ./config.yml:/tabbyAPI/config.yml \
  -v ./api_tokens.yml:/tabbyAPI/api_tokens.yml \
  solidrust/tabby-api
