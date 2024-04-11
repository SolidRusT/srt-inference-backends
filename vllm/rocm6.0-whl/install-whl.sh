#!/bin/bash
wget https://download.pytorch.org/whl/nightly/rocm6.0/torch-2.4.0.dev20240410%2Brocm6.0-cp311-cp311-linux_x86_64.whl
wget https://download.pytorch.org/whl/nightly/pytorch_triton_rocm-3.0.0%2B0a22a91d04-cp311-cp311-linux_x86_64.whl
wget https://download.pytorch.org/whl/nightly/rocm6.0/torchvision-0.19.0.dev20240410%2Brocm6.0-cp311-cp311-linux_x86_64.whl
wget https://download.pytorch.org/whl/nightly/rocm6.0/torchaudio-2.2.0.dev20240410%2Brocm6.0-cp311-cp311-linux_x86_64.whl
wget https://download.pytorch.org/whl/triton-2.2.0-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
wget https://download.pytorch.org/whl/cu121/nvidia_nccl_cu12-2.19.3-py3-none-manylinux1_x86_64.whl
wget https://download.pytorch.org/whl/cu121/xformers-0.0.25.post1-cp311-cp311-manylinux2014_x86_64.whl

pip install *.whl --force --use-deprecated=legacy-resolver

pip install -U git+https://github.com/ROCm/flash-attention@howiejay/navi_support
