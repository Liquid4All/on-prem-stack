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
EOF

    if [ -n "$API_KEY" ]; then
        echo "  curl http://localhost:$PORT/v1/models \\"
        echo "  -H \"Authorization: Bearer $API_KEY\""
    else
        echo "  curl http://localhost:$PORT/v1/models"
    fi

    echo -e "\nTo chat with the model:"
    echo "  curl http://localhost:$PORT/v1/chat/completions \\"
    echo "  -H \"Content-Type: application/json\" \\"

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

# Function to read yaml file
parse_yaml() {
    local yaml_file=$1

    local model_count=$(grep -c "^[[:space:]]\+[^[:space:]]\+:$" "$yaml_file")
    if [ "$model_count" -eq 0 ]; then
        echo "Error: No models found in $yaml_file" >&2
        exit 1
    fi

    awk '
        /^models:/ {in_models=1; next}
        in_models && /^[[:space:]]+[^[:space:]]+:$/ {
            # Extract model name by removing trailing colon and leading spaces
            model=$1
            sub(/:$/, "", model)
            sub(/^[[:space:]]+/, "", model)
        }
        in_models && /^[[:space:]]+image:/ {
            # Extract image value by removing quotes and "image:"
            image=substr($2, 2, length($2)-2)
            print model "\t" image
        }
        in_models && /^[[:space:]]+default:[[:space:]]+true/ {
            # Mark the current model as default
            print model "\tdefault"
        }
    ' "$yaml_file"
}
