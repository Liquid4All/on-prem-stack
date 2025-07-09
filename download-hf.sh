#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 <repo-name>"
  echo "Example: $0 google/flan-t5-small"
  exit 1
fi

REPO_NAME="$1"
OUTPUT_DIR="${REPO_NAME#*/}"

mkdir -p models

echo "Downloading $REPO_NAME into models/$OUTPUT_DIR..."
huggingface-cli download "$REPO_NAME" \
    --local-dir "models/$OUTPUT_DIR" \
    --exclude "*optim*" \
    --exclude "optimizer.pt" \
    --exclude "optim.pt" \
    --exclude "optim_state_dict.pt"

rm -rf models/$OUTPUT_DIR/.cache
rm -rf models/$OUTPUT_DIR/__pycache__
