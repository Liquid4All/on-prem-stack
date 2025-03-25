#!/bin/bash

set -eo pipefail

ENV_FILE=".env"
YAML_FILE="config.yaml"

source ./helpers.sh

UPGRADE_STACK=false
UPGRADE_MODEL=false
SWITCH_MODEL=false
MOUNT_DIR=$(pwd)/local-files

if [ ! -f "$YAML_FILE" ]; then
  echo "ERROR: $YAML_FILE not found. Please contact Liquid support to get a $YAML_FILE file first."
  exit 1
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --upgrade-stack) UPGRADE_STACK=true ;;
    --upgrade-model) UPGRADE_MODEL=true ;;
    --switch-model) SWITCH_MODEL=true ;;
    --mount-dir)
      REAL_INPUT_DIR=$(realpath "$2")
      MOUNT_DIR="$2"
      if [ ! -d "$REAL_INPUT_DIR" ]; then
        echo "ERROR: Input directory is resolved to $REAL_INPUT_DIR but it does not exist"
        exit 1
      fi
      MOUNT_DIR=$REAL_INPUT_DIR
      shift
      ;;
    *) echo "Unknown parameter: $1" >&2; exit 1 ;;
  esac
  shift
done

# Function to display model selection menu and get user choice
# Function to display model selection menu and get user choice
select_model() {
  local yaml_file=$1
  local current_model=$2

  # Get list of models
  readarray -t models < <(parse_yaml "$yaml_file")

  # Display currently running model
  if [ -n "$current_model" ]; then
      echo "Currently running model: $current_model"
  else
      echo "No model is currently running"
  fi

  echo -e "\nYou can switch to one of the following models:"

  # Build selection menu and map
  declare -A model_map
  counter=1
  for model in "${models[@]}"; do
    # Split the line into fields
    IFS=$'\t' read -r name image is_default <<< "$model"

    if [ "$name" = "$current_model" ]; then
        continue
    fi

    # Display name with default indicator if applicable
    if [ "$is_default" = "default" ]; then
        echo "$counter) $name (default)"
    else
        echo "$counter) $name"
    fi

    model_map[$counter]="$name:$image"
    ((counter++))
  done

  if [ $counter -eq 1 ]; then
    echo "No other models available to switch to."
    exit 0
  fi

  echo -e "\nEnter the number of the model you want to switch to (or 'q' to quit):"
  read -r selection

  if [[ "$selection" == "q" ]]; then
    echo "Exiting..."
    exit 0
  fi

  if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -ge "$counter" ]; then
    echo "Invalid selection!"
    exit 1
  fi

  echo "${model_map[$selection]}"
}

get_default_model() {
  local yaml_file=$1

  readarray -t model_data < <(parse_yaml "$yaml_file")

  local default_model=""
  local default_image=""
  local first_model=""
  local first_image=""
  declare -A model_images

  for data in "${model_data[@]}"; do
    # Split the line into fields
    IFS=$'\t' read -r name image is_default <<< "$data"

    if [ -z "$first_model" ] && [ "$is_default" != "default" ]; then
      first_model="$name"
      first_image="$image"
    fi

    model_images["$name"]="$image"

    if [ "$is_default" = "default" ]; then
      default_model="$name"
      default_image="$image"
    fi
  done

  local selected_model=""
  local selected_image=""

  if [ -n "$default_model" ]; then
    selected_model="$default_model"
    selected_image="$default_image"
  elif [ -n "$first_model" ]; then
    selected_model="$first_model"
    selected_image="$first_image"
  else
    echo "Error: No valid models found in $yaml_file" >&2
    exit 1
  fi

  echo "$selected_model:$selected_image"
}

set_and_export_env_var() {
  local var_name=$1
  local var_default_value=$2
  local override=${3:-false}

  if grep -q "^${var_name}=" "$ENV_FILE"; then
    local existing_value=$(grep "^${var_name}=" "$ENV_FILE" | cut -d '=' -f2-)
    if [ "$override" = true ]; then
      sed -i "s|^${var_name}=.*|${var_name}=${var_default_value}|" "$ENV_FILE"
      export "${var_name}=${var_default_value}"
    else
      export "${var_name}=${existing_value}"
    fi
  else
    echo "${var_name}=${var_default_value}" >> "$ENV_FILE"
    export "${var_name}=${var_default_value}"
  fi
}

generate_random_string() {
  local length=$1
  tr -dc A-Za-z0-9 </dev/urandom | head -c "$length"; echo
}

ENV_EXISTS=false
if [ -f "$ENV_FILE" ]; then
  ENV_EXISTS=true
fi

if ! $ENV_EXISTS; then
  touch "$ENV_FILE"
fi

set_and_export_env_var "JWT_SECRET" "$(generate_random_string 64)"
set_and_export_env_var "API_SECRET" "local_api_token"
set_and_export_env_var "AUTH_SECRET" "$(generate_random_string 64)"
set_and_export_env_var "STACK_VERSION" "e5bb8474e8" "$UPGRADE_STACK"

set_and_export_env_var "POSTGRES_DB" "liquid_labs"
set_and_export_env_var "POSTGRES_USER" "local_user"
set_and_export_env_var "POSTGRES_PORT" "5432"
set_and_export_env_var "POSTGRES_SCHEMA" "labs"
set_and_export_env_var "POSTGRES_PASSWORD" "local_password"
# The url is liquid-labs-postgres, which must be the same as the service
# name in the docker compose file.
set_and_export_env_var "DATABASE_URL" "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@liquid-labs-postgres:5432/$POSTGRES_DB" true

if [ -n "$MOUNT_DIR" ]; then
  # Set mount directory if provided
  set_and_export_env_var "LOCAL_FILES_DIR" "$MOUNT_DIR" true
  echo "Local files directory mounted in vLLM container: $MOUNT_DIR"
  echo "Any files under there can be access as file:///local-files/<filename>"
else
  # Unset the variable if it exists and no mount dir is provided
  if grep -q "^LOCAL_FILES_DIR=" "$ENV_FILE"; then
    sed -i '/^LOCAL_FILES_DIR=/d' "$ENV_FILE"
  fi
fi

# Handle model selection logic
declare -A model_images
current_model=""

if [ "$SWITCH_MODEL" = true ]; then
  # Case 1: User wants to switch models
  echo "Switching model..."

  exec ./switch-model.sh
elif ! $ENV_EXISTS || ! grep -q "^MODEL_NAME=" "$ENV_FILE" || ! grep -q "^MODEL_IMAGE=" "$ENV_FILE" || [ "$UPGRADE_MODEL" = true ]; then
  # Case 2: No .env file or model info missing or upgrade requested - use default from YAML
  model_info=$(get_default_model "$YAML_FILE")
  model_name=$(echo "$model_info" | cut -d':' -f1)
  model_image=$(echo "$model_info" | cut -d':' -f2-)

  echo "Launching a brand new on-prem stack..."
  echo "Using model: $model_name with image: $model_image"
  set_and_export_env_var "MODEL_IMAGE" "$model_image" true
  set_and_export_env_var "MODEL_NAME" "$model_name" true
else
  # Case 3: Use existing model from .env file
  echo "Re-launching the existing on-prem stack..."
  model_name=$(grep "^MODEL_NAME=" "$ENV_FILE" | cut -d '=' -f2-)
  model_image=$(grep "^MODEL_IMAGE=" "$ENV_FILE" | cut -d '=' -f2-)
  echo "Using existing model: $model_name with image: $model_image"
fi

if ! docker volume inspect postgres_data > /dev/null 2>&1; then
  echo "Creating Docker volume: postgres_data"
  docker volume create postgres_data
else
  echo "Docker volume postgres_data already exists"
fi

docker compose --env-file "$ENV_FILE" up -d --wait

echo "The on-prem stack is now running."

print_usage_instructions "$MODEL_NAME" 8000 "$API_SECRET"
