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
cd repos
git clone git@github.com:vllm-project/vllm.git
cd vllm
# this will take a while
DOCKER_BUILDKIT=1 docker build --build-arg BUILD_FA="0" -f Dockerfile.rocm -t vllm-rocm .
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

```bash
export VLLM_USE_TRITON_FLASH_ATTN=0
python -m vllm.entrypoints.api_server \
--model cognitivecomputations/dolphin-2.6-mistral-7b-dpo-laser \
--tensor-parallel-size 1 \
--device auto \
--dtype auto \
--kv-cache-dtype auto \
--max-model-len 8192
```

or

```bash
VLLM_WORKER_MULTIPROC_METHOD=spawn VLLM_USE_TRITON_FLASH_ATTN=0 vllm serve cognitivecomputations/dolphin-2.6-mistral-7b-dpo-laser --tensor-parallel-size 1 --device auto --dtype auto --kv-cache-dtype auto --max-model-len 8192

VLLM_WORKER_MULTIPROC_METHOD=spawn VLLM_USE_TRITON_FLASH_ATTN=0 vllm serve NousResearch/Hermes-3-Llama-3.1-8B --tensor-parallel-size 1 --device auto --dtype auto --kv-cache-dtype auto --max-model-len 131072
```

Docker Compose:

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
