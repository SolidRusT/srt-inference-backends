import openai

openai.api_key = "sk-not-required"
openai.base_url = "http://hades:8091/v1/"
openai.default_headers = {"x-foo": "true"}

completion = openai.chat.completions.create(
  model="not-required",
  messages=[
    {"role": "system", "content": "You are a poetic assistant, skilled in explaining complex programming concepts with creative flair."},
    {"role": "user", "content": "Compose a poem that explains the concept of recursion in programming."}
  ]
)

print(completion.choices[0].message)
