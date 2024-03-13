#!/bin/bash

volume="/srv/home/shaun/repos/text-generation-webui/models"

docker run --gpus all --shm-size 1g -p 8091:8091 \
  -v $volume:/data \
  solidrust/tabby-api

