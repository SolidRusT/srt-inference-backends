import os
import subprocess
import torch

def check_pytorch_and_rocm():
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
        print("No CUDA devices are available for PyTorch, checking ROCm compatibility.")
        # This command checks ROCm's installation and version
        try:
            rocm_info = subprocess.check_output(["/opt/rocm/bin/rocm-info"], stderr=subprocess.STDOUT)
            print("\nROCm Information:")
            print(rocm_info.decode('utf-8'))
        except FileNotFoundError:
            print("ROCm is not installed or not in the PATH.")

def check_environment_variables():
    print("\nChecking CUDA/ROCm related environment variables:")
    env_vars = ["PATH", "CUDA_HOME", "LD_LIBRARY_PATH", "ROCm_PATH", "HSA_FORCE_FINE_GRAIN_PCIE"]
    for var in env_vars:
        value = os.getenv(var)
        if value is None:
            print(f"{var} is not set.")
        else:
            print(f"{var}={value}")

def locate_libtorch_cuda():
    print("\nAttempting to locate libtorch_cuda.so...")
    try:
        # Adjust the path as necessary for your environment
        lib_paths = ["/usr/local/lib", "/opt/rocm/lib", os.getenv("LD_LIBRARY_PATH", "").split(":")]
        found = False
        for path in lib_paths:
            if os.path.exists(f"{path}/libtorch_cuda.so"):
                print(f"Found libtorch_cuda.so in {path}")
                found = True
                break
        if not found:
            print("libtorch_cuda.so not found in standard paths. Check your PyTorch installation and LD_LIBRARY_PATH.")
    except Exception as e:
        print(f"Error locating libtorch_cuda.so: {e}")

if __name__ == "__main__":
    check_pytorch_and_rocm()
    check_environment_variables()
    locate_libtorch_cuda()
