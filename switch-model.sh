#!/bin/bash

source ./helpers.sh

# Check if config.yaml exists
if [ ! -f "config.yaml" ]; then
  echo "Error: config.yaml not found!"
  exit 1
fi

# Get list of model names from yaml for pattern matching
model_names=$(parse_yaml "config.yaml" | cut -f1 | paste -sd "|" -)

# Get currently running container
running_container=$(docker ps --format '{{.Names}}' | grep -E "(${model_names})")

if [ -n "$running_container" ]; then
  echo "Currently running model: $running_container"
else
  echo "No model is currently running"
fi

# Read and parse models from yaml
echo -e "\nYou can switch to one of the following models:"
readarray -t models < <(parse_yaml "config.yaml")

# Filter out running container and display options
declare -A model_image_map
declare -A model_name_map
counter=1
for model in "${models[@]}"; do
  # Split the line into fields
  IFS=$'\t' read -r name image is_default <<< "$model"

  if [ "$name" = "$running_container" ]; then
    continue
  fi

  # Display name with default indicator if applicable
  if [ "$is_default" = "default" ]; then
    echo "$counter) $name (default)"
  else
    echo "$counter) $name"
  fi

  model_image_map[$counter]="$image"
  model_name_map[$counter]="$name"
  ((counter++))
done

# Get user selection
echo -e "\nEnter the number of the model you want to switch to (or 'q' to quit):"
read -r selection

# Validate input
if [[ "$selection" == "q" ]]; then
  echo "Exiting..."
  exit 0
fi

if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -ge "$counter" ]; then
  echo "Invalid selection!"
  exit 1
fi

# Get selected image and name
selected_image="${model_image_map[$selection]}"
selected_name="${model_name_map[$selection]}"

if [ ! -f ".env" ]; then
  echo "Error: .env file not found!"
  exit 1
fi

# Create backup of .env
cp .env .env.backup

# Update MODEL_IMAGE and MODEL_NAME in .env
sed -i.bak "s|^MODEL_IMAGE=.*|MODEL_IMAGE=$selected_image|" .env
sed -i.bak "s|^MODEL_NAME=.*|MODEL_NAME=$selected_name|" .env
rm .env.bak

echo "Updated .env with MODEL_IMAGE=$selected_image and MODEL_NAME=$selected_name"

# Launch new container
echo "Shutting down old model and launching new model..."

# It's important to remove the model volume container first. Otherwise, the vLLM
# container will keep referencing the volume created by the previous container.
docker compose stop liquid-labs-model-volume liquid-labs-vllm && \
docker compose rm -f liquid-labs-model-volume && \
./launch.sh
