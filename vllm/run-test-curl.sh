#!/bin/bash

curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
"model": "cognitivecomputations/dolphin-2.6-mistral-7b-dpo-laser",
"prompt": "San Francisco is a",
"max_tokens": 512,
"temperature": 7
}'
