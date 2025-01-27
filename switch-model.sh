#!/bin/bash

# Function to read yaml file
parse_yaml() {
    local yaml_file=$1
    awk '
        /^[[:space:]]+[^[:space:]]+:$/ {
            # Extract model name by removing trailing colon and leading spaces
            model=$1
            sub(/:$/, "", model)
            sub(/^[[:space:]]+/, "", model)
        }
        /^[[:space:]]+image:/ {
            # Extract image value by removing quotes and "image:"
            image=substr($2, 2, length($2)-2)
            print model "\t" image
        }
    ' "$yaml_file"
}

# Check if models.yaml exists
if [ ! -f "models.yaml" ]; then
    echo "Error: models.yaml not found!"
    exit 1
fi

# Get list of model names from yaml for pattern matching
model_names=$(parse_yaml "models.yaml" | cut -f1 | paste -sd "|" -)

# Get currently running container
running_container=$(docker ps --format '{{.Names}}' | grep -E "(${model_names})")

if [ -n "$running_container" ]; then
    echo "Currently running model: $running_container"
else
    echo "No model is currently running"
fi

# Read and parse models from yaml
echo -e "\nYou can switch to one of the following models:"
readarray -t models < <(parse_yaml "models.yaml")

# Filter out running container and display options
declare -A model_map
counter=1
for model in "${models[@]}"; do
    name=$(echo "$model" | cut -f1)
    image=$(echo "$model" | cut -f2)

    # Skip if this is the running container
    if [ "$name" = "$running_container" ]; then
        continue
    fi

    echo "$counter) $name"
    model_map[$counter]="$image"
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

# Get selected image
selected_image="${model_map[$selection]}"

# Update .env file
if [ ! -f ".env" ]; then
    echo "Error: .env file not found!"
    exit 1
fi

# Create backup of .env
cp .env .env.backup

# Update MODEL_IMAGE in .env
sed -i.bak "s|^MODEL_IMAGE=.*|MODEL_IMAGE=$selected_image|" .env
rm .env.bak

echo "Updated .env with MODEL_IMAGE=$selected_image"

# Launch new container
echo "Launching new model..."
./launch.sh
