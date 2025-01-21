#!/bin/bash

usage() {
    echo "Usage: $0 --model-name <container_name> --model-path <huggingface_model_id> [--port <port_number>]"
    echo
    echo "Arguments:"
    echo "  --model-name  Name for the Docker container"
    echo "  --model-path  Path to the model checkpoint"
    echo "  --port        Port to expose locally (default: 9000)"
    echo "  --gpu         Specific GPU index to use (e.g., '0', '1', '0,1') (default: all GPUs)"
    exit 1
}

PORT=9000
GPU="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        --model-name)
            MODEL_NAME="$2"
            shift 2
            ;;
        --model-path)
            MODEL_PATH="$2"
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

if [ -z "$MODEL_NAME" ] || [ -z "$MODEL_PATH" ]; then
    echo "Error: Missing required arguments"
    usage
fi

if docker ps -a --format '{{.Names}}' | grep -q "^${MODEL_NAME}$"; then
    echo "Container with name '$MODEL_NAME' already exists. Removing it..."
    docker rm -f "$MODEL_NAME" >/dev/null 2>&1
fi

STACK_VERSION=$(grep "STACK_VERSION=" .env | grep -v "^#" | cut -d"=" -f2)
IMAGE_NAME=liquidai/liquid-labs-vllm:${STACK_VERSION}

echo "Launching $IMAGE_NAME with model checkpoint: $MODEL_PATH"
docker run -d \
    --name "$MODEL_NAME" \
    --gpus "device=$GPU" \
    -p $PORT:8000 \
    --health-cmd="curl --fail http://localhost:8000/health || exit 1" \
    --health-interval=30s \
    $IMAGE_NAME \
    --host 0.0.0.0 \
    --port 8000 \
    --model "$MODEL_PATH" \
    --tensor-parallel-size 1

if [ $? -eq 0 ]; then
    echo "Container '$MODEL_NAME' started successfully"
    echo "vLLM API is accessible at http://localhost:$PORT"
    echo "To check container logs: docker logs -f $MODEL_NAME"
    echo "To stop container: docker stop $MODEL_NAME"
else
    echo "Failed to start container"
    echo "Please check the container logs for more information:"
    echo "  docker logs $MODEL_NAME"
    exit 1
fi
