#import os
import asyncio
from openai import AsyncOpenAI

client = AsyncOpenAI(
    # This is the default and can be omitted
    #api_key=os.environ.get("OPENAI_API_KEY"),
    api_key = "sk-not-required",
    base_url = "http://hades:5000/v1/",
    default_headers = {"x-foo": "true"},
)

async def main():
    stream = await client.chat.completions.create(
        model="not-required",
        messages=[{"role": "user", "content": "Say this is a test"}],
        stream=True,
    )
    async for chunk in stream:
        print(chunk.choices[0].delta.content or "", end="")


asyncio.run(main())
