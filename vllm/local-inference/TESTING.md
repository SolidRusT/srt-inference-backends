# Testing the vLLM Inference Service

This guide provides instructions for testing the vLLM inference service after deployment.

## Quick Start

### Local Testing

The simplest way to test your vLLM service is using the included client-side scripts:

```bash
# Basic test with default prompt
python test-inference.py --host <server-ip> --port 8081

# Or use the shell script for a more guided experience
bash test-model.sh
```

If testing on the same machine where the service is running:

```bash
python test-inference.py
```

This will send a default test prompt and display the response.

### Server-Side Testing

On deployed servers, you can use the pre-installed test scripts:

```bash
# Basic test script
sudo /opt/inference/vllm/test-vllm.py

# Advanced test script with more options
sudo /opt/inference/vllm/advanced-test-vllm.py

# Interactive chat test script
sudo /opt/inference/vllm/test-chat.sh
```

## Interactive Testing

For more comprehensive testing, use the interactive mode:

```bash
python test-inference.py -i
```

This provides a menu-driven interface to:
- Test text completions
- Test chat completions
- Configure parameters like max tokens and temperature
- Stream responses in real-time

## Test Scripts Overview

| Script | Location | Description |
|--------|----------|-------------|
| `test-inference.py` | Client-side | Comprehensive interactive testing tool for local use |
| `chat-test.py` | Client-side | Simple script focused on chat completions |
| `test-model.sh` | Client-side | Bash wrapper for easy testing from the command line |
| `test-vllm.py` | Server-side | Basic test script installed on each node |
| `advanced-test-vllm.py` | Server-side | Advanced test script with more options |
| `test-chat.sh` | Server-side | Interactive bash script for chat testing |

## Request Types

### Text Completion

Text completion is the simplest form of inference, where you provide a prompt and receive a continuation.

Example:
```bash
python test-inference.py --prompt "Write a haiku about mountains:" --max-tokens 50
```

Or on the server:
```bash
sudo /opt/inference/vllm/advanced-test-vllm.py --prompt "Write a haiku about mountains:" --max-tokens 50
```

### Chat Completion

Chat completion allows you to simulate a conversation with the model, with messages from different roles (system, user, assistant).

Example using the dedicated chat test script:
```bash
python chat-test.py --system "You are a helpful assistant specialized in poetry." --prompt "Write a haiku about mountains." --stream
```

Or on the server, use the interactive chat script:
```bash
sudo /opt/inference/vllm/test-chat.sh
```

In interactive mode, you can build a conversation and test the model's responses. Select option 2 for chat mode, then:

- Enter messages starting with `system:`, `user:`, or `assistant:` to set the role
- Type `send` to send the current conversation
- Type `reset` to clear the conversation
- Type `show` to see the current conversation
- Type `exit` to quit

## API Server Configuration

The vLLM service is configured to run on:
- Default host: localhost
- Default port: 8081 (configured in ansible/group_vars/all.yml)
- Default model: solidrust/Hermes-3-Llama-3.1-8B-AWQ (or as configured in ansible/group_vars/all.yml)

## Troubleshooting

### Connection Errors

If you see connection errors:

1. Verify the server is running:
   ```bash
   sudo systemctl status vllm
   ```

2. Check the server logs:
   ```bash
   sudo journalctl -u vllm -n 50
   ```

3. Ensure the firewall allows connections to the vLLM port (default 8081):
   ```bash
   sudo ufw status
   ```

### Out of Memory Errors

If the server crashes with out-of-memory errors:

1. Reduce the GPU memory utilization in `ansible/group_vars/all.yml`:
   ```yaml
   vllm_gpu_memory: "0.80"  # Try a lower value like 0.75 or 0.70
   ```

2. Reduce the maximum number of concurrent sequences:
   ```yaml
   vllm_max_num_seqs: "32"  # Lower from default 64
   ```

3. Apply the changes:
   ```bash
   ansible-playbook -i inventory.yml site.yml --tags vllm
   ```

## Using the OpenAI Python Client

You can also test the vLLM service using the official OpenAI Python client, as the API is compatible:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8081/v1",
    api_key="dummy"  # vLLM doesn't require a real API key by default
)

# Text completion
completion = client.completions.create(
    model="solidrust/Hermes-3-Llama-3.1-8B-AWQ",  # Use your model name
    prompt="Write a poem about artificial intelligence:",
    max_tokens=100
)
print(completion.choices[0].text)

# Chat completion
chat_completion = client.chat.completions.create(
    model="solidrust/Hermes-3-Llama-3.1-8B-AWQ",  # Use your model name
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Tell me about the benefits of AI."}
    ],
    max_tokens=100
)
print(chat_completion.choices[0].message.content)
```

## Performance Testing

For load testing, you can use tools like `wrk` or a custom script that sends multiple parallel requests.

Example basic load test with 10 parallel requests:

```python
import concurrent.futures
import time
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8081/v1",
    api_key="dummy"
)

def send_request(i):
    start = time.time()
    response = client.completions.create(
        model="solidrust/Hermes-3-Llama-3.1-8B-AWQ",
        prompt=f"Write a one-sentence summary of request {i}:",
        max_tokens=20
    )
    elapsed = time.time() - start
    return (i, elapsed, response.choices[0].text.strip())

# Send 10 requests in parallel
with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
    futures = [executor.submit(send_request, i) for i in range(10)]
    for future in concurrent.futures.as_completed(futures):
        i, elapsed, text = future.result()
        print(f"Request {i}: {elapsed:.2f}s - {text}")
```

## Additional Testing Tips

### Testing with CURL

You can use simple CURL commands to test the vLLM API directly:

```bash
# Text completion
curl -X POST "http://localhost:8081/v1/completions" \
     -H "Content-Type: application/json" \
     -d '{
       "model": "solidrust/Hermes-3-Llama-3.1-8B-AWQ",
       "prompt": "Write a poem about artificial intelligence:",
       "max_tokens": 100,
       "temperature": 0.7
     }'

# Chat completion
curl -X POST "http://localhost:8081/v1/chat/completions" \
     -H "Content-Type: application/json" \
     -d '{
       "model": "solidrust/Hermes-3-Llama-3.1-8B-AWQ",
       "messages": [
         {"role": "system", "content": "You are a helpful assistant."},
         {"role": "user", "content": "Tell me about the benefits of AI."}
       ],
       "max_tokens": 100,
       "temperature": 0.7
     }'
```

### Testing Streaming Responses

To test streaming responses with CURL:

```bash
curl -X POST "http://localhost:8081/v1/chat/completions" \
     -H "Content-Type: application/json" \
     -d '{
       "model": "solidrust/Hermes-3-Llama-3.1-8B-AWQ",
       "messages": [
         {"role": "system", "content": "You are a helpful assistant."},
         {"role": "user", "content": "Tell me a story about a brave knight."}
       ],
       "max_tokens": 100,
       "temperature": 0.7,
       "stream": true
     }'
```

## Advanced Configuration

For more advanced testing scenarios, refer to the [vLLM documentation](https://docs.vllm.ai/en/latest/serving/openai_compatibility.html) for additional API parameters and capabilities.
