# ROCm setup

## Install ROCm

```bash
python --version
python -m venv ~/venvs/rocm-6.2.1
source ~/venvs/rocm-6.2.1/bin/activate
pip install -U pip setuptools wheel packaging
# https://download.pytorch.org/whl/nightly/rocm6.2/torch-2.5.0.dev20240912%2Brocm6.2-cp312-cp312-linux_x86_64.whl
#pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/rocm6.2
pip install --pre torch==2.5.0.dev20240912+rocm6.2 torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/rocm6.2
```

```bash
python -m torch.utils.collect_env
python -c "import torch; print(torch.__version__);"
```

## Install vLLM

### Build vLLM from source

```bash
sudo apt install -y ccache cmake clang
cd repos
git clone git@github.com:vllm-project/vllm.git
cd vllm
pip install -U -r requirements-rocm.txt
python setup.py develop
```

### Build vLLM with Docker

```bash
docker system prune
cd repos
git clone git@github.com:vllm-project/vllm.git
cd vllm
# build params
## https://hub.docker.com/r/rocm/pytorch/tags?name=py3.10
BASE_IMAGE="rocm/pytorch:rocm6.2_ubuntu22.04_py3.10_pytorch_release_2.3.0"
PYTORCH_ROCM_ARCH="gfx1100"
BUILD_TRITON=1
TRITON_BRANCH="e192dba"
BUILD_FA=0
# this will take a while
DOCKER_BUILDKIT=1 docker build \
--build-arg BASE_IMAGE=${BASE_IMAGE} \
--build-arg PYTORCH_ROCM_ARCH=${PYTORCH_ROCM_ARCH} \
--build-arg BUILD_TRITON=${BUILD_TRITON} \
--build-arg TRITON_BRANCH=${TRITON_BRANCH} \
--build-arg BUILD_FA=${BUILD_FA} \
-f Dockerfile.rocm \
-t vllm-rocm .
```

### Run vLLM with Docker

```bash
docker run --device /dev/kfd --device /dev/dri --security-opt seccomp=unconfined <image>
```

The purpose of each option is as follows:

`--device /dev/kfd`

This is the main compute interface, shared by all GPUs.

`--device /dev/dri`

This directory contains the Direct Rendering Interface (DRI) for each GPU. To restrict access to specific GPUs, see Restricting GPU access.

`--security-opt seccomp=unconfined` (optional)

This option enables memory mapping, and is recommended for containers running in HPC environments.

Example with a shell:

```bash
docker run -it \
   --network=host \
   --group-add=video \
   --ipc=host \
   --cap-add=SYS_PTRACE \
   --security-opt seccomp=unconfined \
   --device /dev/kfd \
   --device /dev/dri \
   -v ~/.cache/huggingface:/app/model \
   vllm-rocm \
   bash
```

Then inside the container:

```bash
export MODEL_ID="NousResearch/Hermes-3-Llama-3.1-8B"

docker run -it \
   --network=host \
   --group-add=video \
   --ipc=host \
   --cap-add=SYS_PTRACE \
   --security-opt seccomp=unconfined \
   --device /dev/kfd \
   --device /dev/dri \
   --env "VLLM_WORKER_MULTIPROC_METHOD=spawn" \
   --env "VLLM_USE_TRITON_FLASH_ATTN=1" \
   -v $HOME/.cache/huggingface:/root/.cache/huggingface \
   vllm-rocm:latest \
   vllm serve ${MODEL_ID} \
    --tensor-parallel-size 1 \
    --device cuda \
    --dtype auto \
    --kv-cache-dtype auto \
    --max-model-len 16384 \
    --tokenizer ${MODEL_ID} \
    --tool-call-parser hermes \
    --disable-custom-all-reduce
```

## Run vLLM with Docker Compose

```yaml
services:
  vllm-rocm:
    image: vllm-rocm:latest
    device:
      - /dev/kfd
      - /dev/dri
    security_opt:
      - seccomp:unconfined
```

```bash
docker compose up -d
```

```bash
docker compose exec vllm-rocm bash
```

For example, to expose the first and second GPU:

```bash
docker run --device /dev/kfd --device /dev/dri/renderD128 --device /dev/dri/renderD129
```
