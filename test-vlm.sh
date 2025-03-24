#!/bin/bash

API_SECRET=$(grep "API_SECRET=" .env | grep -v "^#" | cut -d"=" -f2)

echo "--------------------------------"
echo "Test API call to get available models"
echo "--------------------------------"
curl http://0.0.0.0:8000/v1/models \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_SECRET}"
echo -e "\n"

MODEL_NAME=$(grep "MODEL_NAME=" .env | grep -v "^#" | cut -d"=" -f2)
IMAGE_PATH="/local-files/image.jpg"

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
      "content": [
        {
          "type": "image_url",
          "image_url": {
            "url": "file://'"${IMAGE_PATH}"'"
          }
        },
        {
          "type": "text",
          "text": "What is in this image?"
        }
      ]
    }
  ],
  "max_tokens": 512,
  "temperature": 0
}'
echo -e "\n"
