from openai import OpenAI

llm_model = "cognitivecomputations/dolphin-2.6-mistral-7b-dpo-laser"

# Modify OpenAI's API key and API base to use vLLM's API server.
openai_api_key = "EMPTY"
openai_api_base = "http://localhost:8000/v1"
client = OpenAI(
    api_key=openai_api_key,
    base_url=openai_api_base,
)

system_message = """\
You are Dolphin, a superior AI from the future sent back in time to assist humans."""

prompt = "Compare the physical and chemical properties between Hydrogen and Helium."

chat_response = client.chat.completions.create(
    model=llm_model,
    messages=[
        {"role": "system", "content": system_message},
        {"role": "user", "content": prompt},
    ]
)

print("Chat response:", chat_response)
