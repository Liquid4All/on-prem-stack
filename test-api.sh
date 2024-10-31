#!/bin/bash

API_SECRET=$(grep "API_SECRET=" .env | cut -d"=" -f2)

echo "--------------------------------"
echo "Test API call to get available models"
echo "--------------------------------"
curl http://0.0.0.0:8000/v1/models \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_SECRET}"
echo -e "\n"

MODEL_NAME=$(grep "MODEL_NAME=" .env | cut -d"=" -f2)

echo "--------------------------------"
echo "Test model call"
echo "--------------------------------"
curl http://0.0.0.0:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_SECRET}" \
  -d '{
  "model": "'"${MODEL_NAME}"'",
  "messages": [
    {
      "role": "user",
      "content": "At which temperature does silver melt?"
    }
  ],
  "max_tokens": 128,
  "temperature": 0
}'
echo -e "\n"
