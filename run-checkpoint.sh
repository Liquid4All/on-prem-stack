#!/bin/bash

usage() {
    echo "Usage: $0 --model-checkpoint <path-to-model-checkpoint> [--port <port_number>] [--gpu-memory-utilization <0.60>] [--max-num-seqs <600>]"
    echo
    echo "Arguments:"
    echo "  --model-checkpoint        Path to the model checkpoint directory"
    echo "  --port                    Port to expose locally (default: 9000)"
    echo "  --gpu                     Specific GPU index to use (e.g., '0', '1', '0,1') (default: all GPUs)"
    echo "  --gpu-memory-utilization  Fraction of GPU memory to use (default: 0.60)"
    echo "  --max-num-seqs            Maximum number of sequences to cache (default: 600)"
    exit 1
}

PORT=9000
GPU="all"
GPU_MEMORY_UTILIZATION=0.60
MAX_NUM_SEQS=600
MODEL_CHECKPOINT=""
MODEL_NAME=""

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install jq first"
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --model-checkpoint)
            MODEL_CHECKPOINT="$2"
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
        --gpu-memory-utilization)
            GPU_MEMORY_UTILIZATION="$2"
            shift 2
            ;;
        --max-num-seqs)
            MAX_NUM_SEQS="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown parameter $1"
            usage
            ;;
    esac
done

if [ -z "$MODEL_CHECKPOINT" ]; then
    echo "Error: Missing required arguments"
    usage
fi

if [ ! -d "$MODEL_CHECKPOINT" ]; then
    echo "Error: Model checkpoint directory does not exist: $MODEL_CHECKPOINT"
    exit 1
fi

MODEL_CHECKPOINT_ABS=$(realpath "$MODEL_CHECKPOINT")

MODEL_METADATA_FILE="$MODEL_CHECKPOINT_ABS/model_metadata.json"
if [ ! -f "$MODEL_METADATA_FILE" ]; then
    echo "Error: model_metadata.json does not exist in the model checkpoint directory"
    exit 1
fi

MODEL_NAME=$(jq -r '.model_name' "$MODEL_METADATA_FILE")
if [ -z "$MODEL_NAME" ]; then
    echo "Error: model_name is not defined in model_metadata.json"
    exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -q "^$MODEL_NAME$"; then
    echo "Container with name '$MODEL_NAME' already exists. Removing it..."
    docker rm -f "$MODEL_NAME" >/dev/null 2>&1
fi

STACK_VERSION=$(grep "STACK_VERSION=" .env | grep -v "^#" | cut -d"=" -f2)
IMAGE_NAME=liquidai/liquid-labs-vllm:${STACK_VERSION}

echo "Launching $IMAGE_NAME from $MODEL_CHECKPOINT_ABS"
echo "GPU: $GPU"
echo "GPU Memory Utilization: $GPU_MEMORY_UTILIZATION"
echo "Max Num Seqs: $MAX_NUM_SEQS"

docker run -d \
    --name "$MODEL_NAME" \
    --gpus "device=$GPU" \
    -p $PORT:8000 \
    --health-cmd="curl --fail http://localhost:8000/health || exit 1" \
    --health-interval=30s \
    -v "$MODEL_CHECKPOINT_ABS:/model" \
    $IMAGE_NAME \
    --host 0.0.0.0 \
    --port 8000 \
    --model "/model" \
    --served-model-name "$MODEL_NAME" \
    --tensor-parallel-size 1 \
    --max-logprobs 0 \
    --dtype bfloat16 \
    --enable-chunked-prefill false \
    --gpu-memory-utilization $GPU_MEMORY_UTILIZATION \
    --max-num-seqs $MAX_NUM_SEQS \
    --max-model-len 32768 \
    --max-seq-len-to-capture 32768

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
