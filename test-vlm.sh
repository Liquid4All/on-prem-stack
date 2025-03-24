#!/bin/bash

API_SECRET=$(grep "API_SECRET=" .env | grep -v "^#" | cut -d"=" -f2)

DEFAULT_IMAGE_PATH="https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg"

while [[ $# -gt 0 ]]; do
  case $1 in
    --image-url)
      IMAGE_URL="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      echo "Usage: $0 [--image-url URL]"
      exit 1
      ;;
  esac
done

echo "--------------------------------"
echo "Test API call to get available models"
echo "--------------------------------"
curl http://0.0.0.0:8000/v1/models \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_SECRET}"
echo -e "\n"

MODEL_NAME=$(grep "MODEL_NAME=" .env | grep -v "^#" | cut -d"=" -f2)

if [ -n "$IMAGE_URL" ]; then
  IMAGE_SOURCE="$IMAGE_URL"
else
  IMAGE_SOURCE="$DEFAULT_IMAGE_PATH"
fi

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
            "url": "'"${IMAGE_SOURCE}"'"
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
