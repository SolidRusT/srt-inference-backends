import requests
from typing import List

# Configuration parameters
OPENAI_API_KEY = 'sk-OSxxxxx'
MODEL = 'gpt-3.5-turbo'  # Specify the OpenAI model to use
ENDPOINT_URL = 'http://hades:8091/v1/completions'  # Endpoint URL
HEADERS = {"Authorization": f"Bearer {OPENAI_API_KEY}"}
MAX_TOKENS = 2048  # Maximum number of tokens to generate in each completion
TEMPERATURE = 0.7  # Sampling temperature
TOP_P = 1.0  # Nucleus sampling parameter
FREQUENCY_PENALTY = 0.0  # Frequency penalty parameter
PRESENCE_PENALTY = 0.0  # Presence penalty parameter
STOP_SEQUENCES = ["\n"]  # Sequences to stop generation

class BasicChatbot:
    def __init__(self, model: str, endpoint_url: str, headers: dict):
        self.model = model
        self.endpoint_url = endpoint_url
        self.headers = headers
        self.chat_history: List[str] = []

    def ask(self, prompt: str) -> str:
        self.chat_history.append(f"You: {prompt}")
        full_prompt = self._build_full_prompt(prompt)
        completion = self._generate_completion(full_prompt)
        self.chat_history.append(f"AI: {completion}")
        return completion

    def _build_full_prompt(self, prompt: str) -> str:
        return "\n".join(self.chat_history[-(2048//4):]) + f"\nAI:"

    def _generate_completion(self, prompt: str) -> str:
        data = {
            "model": self.model,
            "prompt": prompt,
            "max_tokens": MAX_TOKENS,
            "temperature": TEMPERATURE,
            "top_p": TOP_P,
            "frequency_penalty": FREQUENCY_PENALTY,
            "presence_penalty": PRESENCE_PENALTY,
            "stop": STOP_SEQUENCES,
        }
        response = requests.post(self.endpoint_url, headers=self.headers, json=data)
        response_data = response.json()
        completion = response_data['choices'][0]['text'].strip()
        return completion

# Initialize the chatbot
chatbot = BasicChatbot(MODEL, ENDPOINT_URL, HEADERS)

prompt = f"""Refactor the following wordplay question to be funny and make logical sense:
How many mothers could a motherfucker fuck, if a motherfucker could fuck a mother?
"""

# Example usage
response = chatbot.ask(prompt)
print(f"Chatbot: {response}")

