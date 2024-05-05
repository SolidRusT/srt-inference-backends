#!/bin/bash
curl http://hades:8081/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "llama3",
        "messages": [
            {
                "role": "system",
                "content": "You are a helpful AI assistant who answers mundane questions from humans."
            },
            {
                "role": "user",
                "content": "Why is the sky blue?"
            }
        ]
    }' | jq -r '.choices[0].message.content'
