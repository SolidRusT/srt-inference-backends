#!/bin/bash

# Install the OpenAI Python package
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
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "Who won the world series in 2020?"},
    {"role": "assistant", "content": "The LA Dodgers won in 2020."},
    {"role": "user", "content": "Where was it played?"}
  ]
)

# Print the output of the response
print(response.choices[0].message.content)

EOF
