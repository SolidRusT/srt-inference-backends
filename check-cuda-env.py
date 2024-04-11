import os
import subprocess
import torch

def check_pytorch_and_cuda():
    print(f"PyTorch version: {torch.__version__}")
    cuda_available = torch.cuda.is_available()
    print(f"CUDA available for PyTorch: {cuda_available}")
    
    if cuda_available:
        print(f"CUDA version (used by PyTorch): {torch.version.cuda}")
        print(f"Number of CUDA devices: {torch.cuda.device_count()}")
        for i in range(torch.cuda.device_count()):
            print(f"  Device {i}: {torch.cuda.get_device_name(i)}")
            print(f"    Memory Allocated: {torch.cuda.memory_allocated(i)} bytes")
            print(f"    Memory Cached: {torch.cuda.memory_reserved(i)} bytes")
    else:
        print("No CUDA devices are available for PyTorch.")

def check_cuda_toolkit_version():
    try:
        nvcc_version = subprocess.check_output(["nvcc", "--version"]).decode("utf-8")
        print("\nCUDA Toolkit (nvcc) version:")
        print(nvcc_version.strip().split('\n')[-1])
    except FileNotFoundError:
        print("\nCUDA Toolkit (nvcc) is not installed or not in the PATH.")

def check_environment_variables():
    print("\nChecking CUDA related environment variables:")
    env_vars = ["PATH", "CUDA_HOME", "LD_LIBRARY_PATH", "CUDA_VISIBLE_DEVICES"]
    for var in env_vars:
        value = os.getenv(var)
        if value is None:
            print(f"{var} is not set.")
        else:
            print(f"{var}={value}")

if __name__ == "__main__":
    check_pytorch_and_cuda()
    check_cuda_toolkit_version()
    check_environment_variables()
