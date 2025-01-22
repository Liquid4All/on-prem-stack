#!/bin/bash

source ./helpers.sh

if [ ! -d ~/.cache/huggingface/hub/.locks ]; then
    echo "Creating directory for Hugging Face cache"
    mkdir -p ~/.cache/huggingface/hub/.locks
fi

if ! command -v huggingface-cli >/dev/null 2>&1; then
  echo "Installing Hugging Face CLI..."
  pip install -U "huggingface_hub[cli]"
fi

if huggingface-cli whoami 2>&1 | grep -q "Not logged in"; then
  echo "Currently not logged into Hugging Face. Please log in first..."
  huggingface-cli login
fi

usage() {
    echo "Usage: $0 --model-name <arbitrary-model-name> --hf-model-path <huggingface-model-id> --hf-token <huggingface-token> [--port <port-number>]"
    echo
    echo "Arguments:"
    echo "  --model-name     Arbitrary name that will be used as the Docker container and the model ID for API call"
    echo "  --hf-model-path  Hugging Face model ID (e.g., 'meta-llama/Llama-2-7b-chat-hf')"
    echo "  --hf-token       Hugging Face access token"
    echo "  --port           Port to expose locally (default: 9000)"
    echo "  --gpu            Specific GPU index to use (e.g., '0', '1', '0,1') (default: all GPUs)"
    exit 1
}

HF_TOKEN=""
PORT=9000
GPU="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        --model-name)
            MODEL_NAME="$2"
            shift 2
            ;;
        --hf-model-path)
            HF_MODEL_PATH="$2"
            shift 2
            ;;
        --hf-token)
            HF_TOKEN="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --gpu)
            GPU="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown parameter $1"
            usage
            ;;
    esac
done

if [ -z "$MODEL_NAME" ] || [ -z "$HF_MODEL_PATH" ]; then
    echo "Error: Missing required arguments"
    usage
fi

if docker ps -a --format '{{.Names}}' | grep -q "^${MODEL_NAME}$"; then
    echo "Container with name '$MODEL_NAME' already exists. Removing it..."
    docker rm -f "$MODEL_NAME" >/dev/null 2>&1
fi

echo "Launching vLLM container with model: $HF_MODEL_PATH"
docker run -d \
    --name "$MODEL_NAME" \
    --gpus "device=$GPU" \
    -p $PORT:8000 \
    -e HUGGING_FACE_HUB_TOKEN="$HF_TOKEN" \
    --health-cmd="curl --fail http://localhost:8000/health || exit 1" \
    --health-interval=30s \
    vllm/vllm-openai:latest \
    --host 0.0.0.0 \
    --port 8000 \
    --model "$HF_MODEL_PATH" \
    --served-model-name "$MODEL_NAME" \
    --tensor-parallel-size 1

if [ $? -eq 0 ]; then
    print_usage_instructions "$MODEL_NAME" "$PORT"
    cat <<EOF
Container '$MODEL_NAME' started successfully
vLLM API will be accessible at http://localhost:$PORT
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
else
    echo "Failed to start container"
    echo "Please check the container logs for more information:"
    echo "  docker logs $MODEL_NAME"
    exit 1
fi
