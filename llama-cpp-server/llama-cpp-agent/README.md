# Llama.cpp backend

OpenAI compatible [HTTP service](https://github.com/ggerganov/llama.cpp/tree/master/examples/server)

```bash
export COMMON_FLAGS="-pipe" ## verify with makefile
export CFLAGS="${COMMON_FLAGS}"
export CXXFLAGS="${COMMON_FLAGS}"
export PATH=$PATH:/usr/local/cuda/bin
export CUDA_HOME="/usr/local/cuda"
export CUDA_PATH="/usr/local/cuda"
export LD_LIBRARY_PATH="/usr/local/cuda"
# checkout llama.cpp repo https://github.com/ggerganov/llama.cpp
make clean
make LLAMA_CUDA=1

## For ROCm support:
# export LD_LIBRARY_PATH=/opt/rocm-5.7.0/lib:$LD_LIBRARY_PATH
# export CPATH=/opt/rocm-5.7.0/llvm/lib/clang/17.0.0/include:$CPATH
# make LLAMA_HIPBLAS=1

./server -m mistral-7b-instruct-v0.2.Q4_K_M.gguf -c 16384 -ngl 33 -b 1024 -t 6 --host 0.0.0.0 --port 8080 -np 2
```

```bash
curl zelus:8080/v1/chat/completions \
    -X POST \
    -d '{
  "model": "solidrust/dolphin-2.9-llama3-8b-AWQ",
  "messages": [
    {
      "role": "system",
      "content": "You are a helpful assistant."
    },
    {
      "role": "user",
      "content": "What is deep learning?"
    }
  ],
  "stream": false,
  "max_tokens": 100
}' \
    -H 'Content-Type: application/json'
```
