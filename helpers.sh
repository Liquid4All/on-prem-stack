#!/bin/bash

# Example usage:
# print_usage_instructions "lfm-3b" 9000              # Uses custom port 3000
# print_usage_instructions "lfm-3b" 9000 "sk-abc123"  # Uses custom port and API key
print_usage_instructions() {
    local MODEL_NAME=$1
    local PORT=$2
    local API_KEY=$3

    cat <<EOF
Model '$MODEL_NAME' started successfully
The vLLM API will be accessible at http://localhost:$PORT
Please wait 1-2 minutes for the model to load before making API calls
You can check the container logs for more information:
  docker logs -f $MODEL_NAME

To stop the container:
  docker stop $MODEL_NAME

To check model status:
  curl http://localhost:$PORT/v1/models

To chat with the model:
  curl http://localhost:$PORT/v1/chat/completions \\
  -H "Content-Type: application/json" \\
EOF

    # Add authorization header if API key is provided
    if [ -n "$API_KEY" ]; then
        echo "  -H \"Authorization: Bearer $API_KEY\" \\"
    fi

    # Complete the curl command
    cat <<EOF
  -d '{
    "model": "$MODEL_NAME",
    "messages": [
      {
        "role": "user",
        "content": "At which temperature does silver melt?"
      }
    ],
    "max_tokens": 128,
    "temperature": 0
  }'
EOF
}
