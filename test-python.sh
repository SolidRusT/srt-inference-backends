#!/bin/bash

# Install the OpenAI Python package
pyenv update
pyenv install 3.11 -s
pip install openai --quiet

# Run the Python script
python - <<EOF

from openai import OpenAI

client = OpenAI(
    base_url = 'http://hades:8081/v1',
    api_key='ollama', # required, but unused
)

response = client.chat.completions.create(
  model="llama3",
  messages=[
    {"role": "system", "content": "You are a helpful AI assistant who answers mundane questions from humans."},
    {"role": "user", "content": "Why is the sky blue?"},
  ]
)

# Print the output of the response
print(response.choices[0].message.content)

EOF
