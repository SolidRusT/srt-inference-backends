#!/usr/bin/env python3
"""
vLLM Chat Completion Test Client

A simple script to test chat completion with the vLLM service.
"""

import argparse
import json
import requests
import time
import sys

def chat_completion(host, port, model, messages, max_tokens=100, temperature=0.7, stream=False):
    """Send a chat completion request to the vLLM server."""
    url = f"http://{host}:{port}/v1/chat/completions"
    
    data = {
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "stream": stream
    }
    
    if model:
        data["model"] = model
    
    print(f"Sending request to {url}")
    print(f"Messages: {json.dumps(messages, indent=2)}")
    
    try:
        start_time = time.time()
        response = requests.post(
            url, 
            headers={"Content-Type": "application/json"}, 
            data=json.dumps(data),
            timeout=60,
            stream=stream
        )
        response.raise_for_status()
        
        if stream:
            print("\nStreaming response:")
            for line in response.iter_lines():
                if line:
                    line_text = line.decode('utf-8')
                    if line_text.startswith('data: '):
                        try:
                            line_json = json.loads(line_text[6:])
                            if line_json.get('choices') and len(line_json['choices']) > 0:
                                delta = line_json['choices'][0].get('delta', {})
                                if 'content' in delta and delta['content']:
                                    print(delta['content'], end='', flush=True)
                        except Exception as e:
                            print(f"\nError parsing stream: {e}")
            print("\n\nStream completed")
            end_time = time.time()
            print(f"Response completed in {end_time - start_time:.2f} seconds")
            return {"status": "stream_completed"}
        else:
            end_time = time.time()
            result = response.json()
            print(f"Response received in {end_time - start_time:.2f} seconds")
            
            # Display the response content
            if "choices" in result and len(result["choices"]) > 0:
                if "message" in result["choices"][0]:
                    message = result["choices"][0]["message"]
                    print(f"\nRole: {message.get('role', 'unknown')}")
                    print(f"Content:\n{message.get('content', '')}")
            
            # Display usage information
            if "usage" in result:
                usage = result["usage"]
                print(f"\nPrompt tokens: {usage.get('prompt_tokens', 'N/A')}")
                print(f"Completion tokens: {usage.get('completion_tokens', 'N/A')}")
                print(f"Total tokens: {usage.get('total_tokens', 'N/A')}")
            
            return result
    
    except requests.exceptions.RequestException as e:
        print(f"Request failed: {e}")
        if hasattr(e, 'response') and e.response:
            try:
                print(f"Response: {e.response.json()}")
            except:
                print(f"Response text: {e.response.text}")
        return None

def main():
    parser = argparse.ArgumentParser(description="Test vLLM Chat API")
    parser.add_argument("--host", default="localhost", help="vLLM server hostname")
    parser.add_argument("--port", type=int, default=8081, help="vLLM server port")
    parser.add_argument("--model", default=None, help="Model name (leave empty to use server default)")
    parser.add_argument("--max-tokens", type=int, default=100, help="Maximum tokens to generate")
    parser.add_argument("--temperature", type=float, default=0.7, help="Sampling temperature")
    parser.add_argument("--prompt", help="User prompt (optional, overrides default)")
    parser.add_argument("--system", help="System message (optional)")
    parser.add_argument("--stream", action="store_true", help="Stream the response")
    
    args = parser.parse_args()
    
    # Build messages
    messages = []
    
    # Add system message if provided
    if args.system:
        messages.append({"role": "system", "content": args.system})
    else:
        # Default system message
        messages.append({"role": "system", "content": "You are a helpful AI assistant."})
    
    # Add user message
    if args.prompt:
        messages.append({"role": "user", "content": args.prompt})
    else:
        # Default user message
        messages.append({"role": "user", "content": "Tell me a short joke."})
    
    # Send the request
    chat_completion(args.host, args.port, args.model, messages, args.max_tokens, args.temperature, args.stream)

if __name__ == "__main__":
    main()
