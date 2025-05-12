#!/bin/bash

PORT=8000
API_SECRET=$(grep "API_SECRET=" .env | grep -v "^#" | cut -d"=" -f2)
MODEL_NAME=$(grep "MODEL_NAME=" .env | grep -v "^#" | cut -d"=" -f2)
DEFAULT_IMAGE_PATH="file:///local-files/image.jpg"
IMAGE_SOURCE=""
VLM_MODE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --model-name)
      MODEL_NAME="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --image-url)
      IMAGE_URL="$2"
      shift 2
      ;;
    --vlm)
      VLM_MODE=true
      shift 1
      ;;
    *)
      echo "Unknown parameter: $1"
      echo "Usage: $0 [--model-name MODEL_NAME] [--port PORT] [--vlm] [--image-url URL]"
      exit 1
      ;;
  esac
done

if [[ "$VLM_MODE" = true ]]; then
  if [ -n "$IMAGE_URL" ]; then
    IMAGE_SOURCE="$IMAGE_URL"
  else
    IMAGE_SOURCE="$DEFAULT_IMAGE_PATH"
  fi
fi

echo "--------------------------------"
echo "Test API call to get available models"
echo "--------------------------------"
curl http://0.0.0.0:${PORT}/v1/models \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_SECRET}"
echo -e "\n"

echo "--------------------------------"
echo "Test model call"
echo "--------------------------------"

if [[ "$VLM_MODE" = true ]]; then
  # VLM request
  curl http://0.0.0.0:${PORT}/v1/chat/completions \
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
else
  # LLM request
  curl http://0.0.0.0:${PORT}/v1/chat/completions \
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
fi
echo -e "\n"
