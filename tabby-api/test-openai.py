import os
from openai import OpenAI

client = OpenAI(
    # This is the default and can be omitted
    #api_key=os.environ.get("OPENAI_API_KEY"),
    api_key="sk-not-required",
    base_url = "http://hades:8091/v1/",
    default_headers = {"x-foo": "true"},
)

chat_completion = client.chat.completions.create(
    messages=[
        {
            "role": "user",
            "content": "Say this is a test",
        }
    ],
    model="not-required",
)

print(chat_completion.choices[0].message)
