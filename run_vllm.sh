#!/bin/bash

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
    echo "Usage: $0 --model-name <container_name> --hf-model-path <huggingface_model_id> [--port <port_number>]"
    echo
    echo "Arguments:"
    echo "  --model-name     Name for the Docker container"
    echo "  --hf-model-path  Hugging Face model ID (e.g., 'meta-llama/Llama-2-7b-chat-hf')"
    echo "  --port           Port to expose locally (default: 9000)"
    exit 1
}

PORT=9000

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
        --port)
            PORT="$2"
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

echo "Launching vLLM container with model: $HF_MODEL_PATH"
docker run -d \
    --name "$MODEL_NAME" \
    --gpus all \
    -p $PORT:8000 \
    --health-cmd="curl --fail http://localhost:8000/health || exit 1" \
    --health-interval=30s \
    ghcr.io/vllm-project/vllm \
    --host 0.0.0.0 \
    --model "$HF_MODEL_PATH" \
    --tensor-parallel-size 1

if [ $? -eq 0 ]; then
    echo "Container '$MODEL_NAME' started successfully"
    echo "vLLM API is accessible at http://localhost:$PORT"
    echo "To check container logs: docker logs $MODEL_NAME"
    echo "To stop container: docker stop $MODEL_NAME"
else
    echo "Failed to start container"
    exit 1
fi
