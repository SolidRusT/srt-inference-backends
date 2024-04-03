# tabbyAPI

API service to run fp16 and exl2 models. See more on the [tabbyAPI Official Site](https://github.com/theroyallab/tabbyAPI).

## AMD ROCm 6.x

### Run with Docker

For CUDA:

```bash
docker build -f Dockerfile-nvidia -t solidrust/tabby-api .
```

For ROCm:

```bash
docker build -f Dockerfile-amd -t solidrust/tabby-api .
```

```bash
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
  -v $volume:/hf_models \
  -v ./config.yml:/tabbyAPI/config.yml \
  -v ./api_tokens.yml:/tabbyAPI/api_tokens.yml \
  solidrust/tabby-api
```

## NVIDIA CUDA 12.x

### Run with Docker

```bash
docker build -f Dockerfile-nvidia -t solidrust/tabby-api .
```

```bash
#!/bin/bash

volume="${HOME}/hf_models"

docker run --gpus all --shm-size 1g \
  -p 8091:8091 \
  -v $volume:/hf_models \
  solidrust/tabby-api
```
