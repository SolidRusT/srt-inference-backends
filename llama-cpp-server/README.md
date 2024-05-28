### llama-cpp-server

```bash
#!/bin/bash
model_file="Mistral-7B-Instruct-v0.3-Q4_K_M.gguf"
model_repo="bartowski/Mistral-7B-Instruct-v0.3-GGUF"
# Download the model
pip install -U "huggingface_hub[cli]"
huggingface-cli login --token $HF_TOKEN
huggingface-cli whoami
huggingface-cli download $model_repo $model_file
# Run the llama CPP Server
# not this one "pip install llama-cpp-python[server]"
./server -m $model_file -c 16384 -ngl 33 -b 1024 -t 6 --host 0.0.0.0 --port 8080 -np 2
# ./server -m Mistral-7B-Instruct-v0.3.Q6_K.gguf -c 128000 -ngl 33 -b 1024 -t 10 -fa --grp-attn-n 4 --grp-attn-w 16384 --port 8084 --host 0.0.0.0
```