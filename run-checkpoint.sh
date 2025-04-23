#!/bin/bash

source ./helpers.sh

usage() {
    echo "Usage: $0 --model-checkpoint <path-to-model-checkpoint> [--model-name] [--port <port_number>] [--gpu-memory-utilization <0.60>] [--max-num-seqs <600>] [--mount-dir <path>]"
    echo
    echo "Arguments:"
    echo "  --model-checkpoint        Path to the model checkpoint directory"
    echo "  --model-name              Override model name (default: read from model_metadata.json)"
    echo "  --port                    Port to expose locally (default: 9000)"
    echo "  --gpu                     Specific GPU index to use (e.g., '0', '1', '0,1') (default: all GPUs)"
    echo "  --gpu-memory-utilization  Fraction of GPU memory to use (default: 0.60)"
    echo "  --max-num-seqs            Maximum number of sequences to cache (default: 600)"
    echo "  --mount-dir               Directory to mount to /local-files in the container (default: ./local-files)"
    exit 1
}

PORT=9000
GPU="all"
GPU_MEMORY_UTILIZATION=0.60
MAX_NUM_SEQS=600
MODEL_CHECKPOINT=""
MODEL_NAME=""
MOUNT_DIR="$(pwd)/local-files"

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
        --model-name)
            MODEL_NAME="$2"
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
        --mount-dir)
            MOUNT_DIR="$2"
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

if [ ! -d "$MOUNT_DIR" ]; then
    echo "Creating mount directory: $MOUNT_DIR"
    mkdir -p "$MOUNT_DIR"
fi

echo "Local files directory mounted in vLLM container: $MOUNT_DIR"
echo "Any files under there can be passed in as file:///local-files/<filename>"

MOUNT_DIR_ABS=$(realpath "$MOUNT_DIR")
MODEL_CHECKPOINT_ABS=$(realpath "$MODEL_CHECKPOINT")

MODEL_METADATA_FILE="$MODEL_CHECKPOINT_ABS/model_metadata.json"
if [ ! -f "$MODEL_METADATA_FILE" ]; then
    echo "Warning: model_metadata.json does not exist in the model checkpoint directory. If you are trying to run VLM, it will fail."
fi

# TODO: this is a temporary fix for vLLM e5bb8474e8
if [ -z "$MODEL_NAME" ]; then
    if [ -f "$MODEL_METADATA_FILE" ]; then
        echo "Reading model name from model_metadata.json"
        MODEL_NAME=$(jq -r '.model_name' "$MODEL_METADATA_FILE")
    else
        echo "Error: model_name is not defined in model_metadata.json and no --model-name argument was provided."
        exit 1
    fi
fi

if docker ps -a --format '{{.Names}}' | grep -q "^$MODEL_NAME$"; then
    echo "Container with name '$MODEL_NAME' already exists. Removing it..."
    docker rm -f "$MODEL_NAME" >/dev/null 2>&1
fi

VLLM_VERSION=$(grep "VLLM_VERSION=" .env | grep -v "^#" | cut -d"=" -f2)
IMAGE_NAME=liquidai/liquid-labs-vllm:${VLLM_VERSION}

echo "Launching $MODEL_NAME from $MODEL_CHECKPOINT_ABS"
echo "GPU: $GPU"
echo "GPU Memory Utilization: $GPU_MEMORY_UTILIZATION"
echo "Max Num Seqs: $MAX_NUM_SEQS"
echo "Mount Directory: $MOUNT_DIR_ABS -> /local-files"

docker run -d \
    --name "$MODEL_NAME" \
    --gpus "device=$GPU" \
    -p $PORT:8000 \
    --health-cmd="curl --fail http://localhost:8000/health || exit 1" \
    --health-interval=30s \
    -v "$MODEL_CHECKPOINT_ABS:/model" \
    -v "$MOUNT_DIR_ABS:/local-files" \
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
    --max-seq-len-to-capture 32768 \
    --allowed_local_media_path "/local-files"

if [ $? -eq 0 ]; then
    print_usage_instructions "$MODEL_NAME" "$PORT"
else
    echo "Failed to start container"
    echo "Please check the container logs for more information:"
    echo "  docker logs $MODEL_NAME"
    exit 1
fi
