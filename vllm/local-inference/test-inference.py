#!/usr/bin/env python3
"""
vLLM Inference Test Client

This script provides an easy way to test the vLLM service with different request types:
- Text completion
- Chat completion
- Custom prompts
"""

import argparse
import json
import requests
import time
import sys
from typing import Dict, List, Any, Optional

class VLLMClient:
    """Client for testing vLLM APIs."""
    
    def __init__(self, host: str, port: int, model: str = None):
        """Initialize the vLLM client.
        
        Args:
            host: The hostname of the vLLM server
            port: The port number of the vLLM server
            model: Optional model name to use
        """
        self.base_url = f"http://{host}:{port}/v1"
        self.model = model
        print(f"✓ Configured client for server at {self.base_url}")
        if model:
            print(f"✓ Using model: {model}")
        else:
            print("ℹ️ No model specified, server default will be used")
    
    def test_connection(self) -> bool:
        """Test the connection to the vLLM server."""
        try:
            # Try to get models - this is a lightweight API call to check connectivity
            response = requests.get(f"{self.base_url}/models", timeout=5)
            response.raise_for_status()
            print("✓ Successfully connected to vLLM server")
            return True
        except requests.exceptions.RequestException as e:
            print(f"❌ Connection failed: {e}")
            return False
    
    def completion(self, prompt: str, max_tokens: int = 100, temperature: float = 0.7, 
                  stop: Optional[List[str]] = None) -> Dict[str, Any]:
        """Send a completion request to the vLLM server.
        
        Args:
            prompt: The prompt text
            max_tokens: Maximum number of tokens to generate
            temperature: Sampling temperature
            stop: List of stop sequences
            
        Returns:
            The response JSON
        """
        url = f"{self.base_url}/completions"
        
        data = {
            "prompt": prompt,
            "max_tokens": max_tokens,
            "temperature": temperature
        }
        
        if self.model:
            data["model"] = self.model
            
        if stop:
            data["stop"] = stop
        
        print(f"\n🔄 Sending completion request to {url}")
        print(f"📝 Prompt: {prompt}")
        
        try:
            start_time = time.time()
            response = requests.post(
                url, 
                headers={"Content-Type": "application/json"}, 
                data=json.dumps(data),
                timeout=60
            )
            response.raise_for_status()
            end_time = time.time()
            
            result = response.json()
            print(f"✓ Response received in {end_time - start_time:.2f} seconds")
            return result
        
        except requests.exceptions.RequestException as e:
            print(f"❌ Request failed: {e}")
            if hasattr(e, 'response') and e.response:
                try:
                    print(f"Response: {e.response.json()}")
                except:
                    print(f"Response text: {e.response.text}")
            return None
    
    def chat_completion(self, messages: List[Dict[str, str]], max_tokens: int = 100, 
                       temperature: float = 0.7, stream: bool = False) -> Dict[str, Any]:
        """Send a chat completion request to the vLLM server.
        
        Args:
            messages: List of message dictionaries with 'role' and 'content'
            max_tokens: Maximum number of tokens to generate
            temperature: Sampling temperature
            stream: Whether to stream the response
            
        Returns:
            The response JSON
        """
        url = f"{self.base_url}/chat/completions"
        
        data = {
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "stream": stream
        }
        
        if self.model:
            data["model"] = self.model
        
        print(f"\n🔄 Sending chat completion request to {url}")
        print(f"📝 Messages: {json.dumps(messages, indent=2)}")
        
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
                print("\n🔄 Streaming response:")
                for line in response.iter_lines():
                    if line:
                        try:
                            line_text = line.decode('utf-8')
                            if line_text.startswith('data: '):
                                line_json = json.loads(line_text[6:])
                                if line_json.get('choices') and len(line_json['choices']) > 0:
                                    delta = line_json['choices'][0].get('delta', {})
                                    if 'content' in delta and delta['content']:
                                        print(delta['content'], end='', flush=True)
                        except Exception as e:
                            print(f"\nError parsing stream: {e}")
                print("\n\n✓ Stream completed")
                end_time = time.time()
                print(f"✓ Response completed in {end_time - start_time:.2f} seconds")
                return {"status": "stream_completed"}
            else:
                end_time = time.time()
                result = response.json()
                print(f"✓ Response received in {end_time - start_time:.2f} seconds")
                return result
        
        except requests.exceptions.RequestException as e:
            print(f"❌ Request failed: {e}")
            if hasattr(e, 'response') and e.response:
                try:
                    print(f"Response: {e.response.json()}")
                except:
                    print(f"Response text: {e.response.text}")
            return None

def display_response(response: Dict[str, Any]) -> None:
    """Display the response in a readable format."""
    if not response:
        return
    
    # For chat completion response
    if "choices" in response and len(response["choices"]) > 0:
        if "message" in response["choices"][0]:
            print("\n📬 Response message:")
            message = response["choices"][0]["message"]
            print(f"Role: {message.get('role', 'unknown')}")
            print(f"\nContent:\n{message.get('content', '')}")
        elif "text" in response["choices"][0]:
            print("\n📬 Generated text:")
            print(response["choices"][0]["text"])
    
    # Display usage information if available
    if "usage" in response:
        usage = response["usage"]
        print("\n📊 Token usage:")
        print(f"  Prompt tokens: {usage.get('prompt_tokens', 'N/A')}")
        print(f"  Completion tokens: {usage.get('completion_tokens', 'N/A')}")
        print(f"  Total tokens: {usage.get('total_tokens', 'N/A')}")

def interactive_mode(client: VLLMClient) -> None:
    """Run an interactive session with the vLLM server."""
    print("\n🔄 Starting interactive mode (Ctrl+C to exit)")
    print("Select mode:")
    print("1. Text completion")
    print("2. Chat completion")
    
    try:
        mode = int(input("\nEnter mode (1 or 2): ").strip())
        if mode == 1:
            # Text completion mode
            while True:
                prompt = input("\nEnter prompt (or 'exit' to quit): ")
                if prompt.lower() == 'exit':
                    break
                
                max_tokens = int(input("Max tokens (default 100): ") or "100")
                temp = float(input("Temperature (default 0.7): ") or "0.7")
                
                response = client.completion(prompt, max_tokens, temp)
                display_response(response)
                
        elif mode == 2:
            # Chat completion mode
            messages = []
            print("\nChat mode - enter messages one by one")
            print("Start with 'system:', 'user:', or 'assistant:' to indicate the role")
            print("Enter 'send' to send the conversation, 'reset' to clear, or 'exit' to quit")
            
            while True:
                line = input("\nEnter message: ")
                if line.lower() == 'exit':
                    break
                elif line.lower() == 'send':
                    if not messages:
                        print("⚠️ No messages to send")
                        continue
                    
                    print(f"📤 Sending {len(messages)} messages...")
                    max_tokens = int(input("Max tokens (default 100): ") or "100")
                    temp = float(input("Temperature (default 0.7): ") or "0.7")
                    stream = input("Stream response? (y/n, default n): ").lower() == 'y'
                    
                    response = client.chat_completion(messages, max_tokens, temp, stream)
                    if not stream:  # Only display non-streamed responses
                        display_response(response)
                    
                    # Add response to messages if not streaming
                    if not stream and response and "choices" in response:
                        try:
                            asst_msg = response["choices"][0]["message"]
                            messages.append(asst_msg)
                            print("\n✓ Added assistant response to conversation")
                        except (KeyError, IndexError):
                            print("⚠️ Could not add response to conversation")
                    
                elif line.lower() == 'reset':
                    messages = []
                    print("🗑️ Conversation reset")
                elif line.lower() == 'show':
                    if not messages:
                        print("⚠️ No messages in conversation")
                    else:
                        print("\n💬 Current conversation:")
                        for i, msg in enumerate(messages, 1):
                            print(f"{i}. {msg['role']}: {msg['content'][:50]}...")
                else:
                    # Parse the role prefix
                    if line.startswith("system:"):
                        role = "system"
                        content = line[7:].strip()
                    elif line.startswith("user:"):
                        role = "user"
                        content = line[5:].strip()
                    elif line.startswith("assistant:"):
                        role = "assistant"
                        content = line[10:].strip()
                    else:
                        # Default to user if no prefix
                        role = "user"
                        content = line
                    
                    messages.append({"role": role, "content": content})
                    print(f"✓ Added {role} message")
        else:
            print("❌ Invalid mode selected")
    
    except KeyboardInterrupt:
        print("\n\n👋 Exiting interactive mode")
    except Exception as e:
        print(f"\n❌ Error in interactive mode: {e}")

def main():
    parser = argparse.ArgumentParser(description="Test vLLM API")
    parser.add_argument("--host", default="localhost", help="vLLM server hostname")
    parser.add_argument("--port", type=int, default=8081, help="vLLM server port")
    parser.add_argument("--model", default=None, help="Model name (leave empty to use server default)")
    parser.add_argument("--interactive", "-i", action="store_true", help="Start in interactive mode")
    parser.add_argument("--prompt", "-p", help="Prompt for completion (for non-interactive mode)")
    parser.add_argument("--max-tokens", type=int, default=100, help="Maximum tokens to generate")
    parser.add_argument("--temperature", type=float, default=0.7, help="Sampling temperature")
    
    args = parser.parse_args()
    
    client = VLLMClient(args.host, args.port, args.model)
    
    # Test the connection
    if not client.test_connection():
        print("❌ Could not connect to vLLM server. Please check that the server is running.")
        sys.exit(1)
    
    if args.interactive:
        interactive_mode(client)
    elif args.prompt:
        # Single prompt mode
        response = client.completion(args.prompt, args.max_tokens, args.temperature)
        display_response(response)
    else:
        # Default test with a simple prompt
        response = client.completion(
            "Write a short poem about artificial intelligence:",
            args.max_tokens,
            args.temperature
        )
        display_response(response)
    
    print("\n👋 Test completed.")

if __name__ == "__main__":
    main()
