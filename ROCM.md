# Install for ROCm

Ubuntu 22.04 Server minimal install

```bash
sudo apt update
sudo apt install -y "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
sudo usermod -a -G render,video $LOGNAME # Add the current user to the render and video groups
wget https://repo.radeon.com/amdgpu-install/6.2.1/ubuntu/noble/amdgpu-install_6.2.60201-1_all.deb
sudo apt install ./amdgpu-install_6.2.60201-1_all.deb
sudo apt update
sudo apt install amdgpu-dkms rocm
```

reboot, and test ROCm installation

```bash
rocm-smi
# add to ldconfig
sudo tee --append /etc/ld.so.conf.d/rocm.conf <<EOF
/opt/rocm/lib
/opt/rocm/lib64
EOF
sudo ldconfig
# add to path
export PATH=$PATH:/opt/rocm-6.2.1/bin
dkms status
```

```bash
sudo apt update
sudo apt install -y python3 \
python3-dev python3-pip python3-wheel python3-venv python3-setuptools \
python-is-python3
```

```bash
python --version
python -m venv ~/venvs/rocm-6.2.1
source ~/venvs/rocm-6.2.1/bin/activate
pip install wheel setuptools
pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/rocm6.2
```

```bash
python -m torch.utils.collect_env
python -c "import torch; print(torch.__version__);"
```
