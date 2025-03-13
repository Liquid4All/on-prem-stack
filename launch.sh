#!/bin/bash

ENV_FILE=".env"
YAML_FILE="config.yaml"

source ./helpers.sh

UPGRADE_STACK=false
UPGRADE_MODEL=false
SWITCH_MODEL=false

echo "Checking for config file: $YAML_FILE"
if [ ! -f "$YAML_FILE" ]; then
  echo "ERROR: $YAML_FILE not found. Please contact Liquid support to get a $YAML_FILE file first."
  exit 1
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --upgrade-stack) UPGRADE_STACK=true ;;
    --upgrade-model) UPGRADE_MODEL=true ;;
    --switch-model) SWITCH_MODEL=true ;;
    *) echo "Unknown parameter: $1" >&2; exit 1 ;;
  esac
  shift
done

# Function to parse yaml file
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
        name=$(echo "$model" | cut -f1)
        value=$(echo "$model" | cut -f2)

        if [ "$name" = "$current_model" ]; then
            continue
        fi

        echo "$counter) $name"
        model_map[$counter]="$name:$value"
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

  for data in "${model_data[@]}"; do
    local name=$(echo "$data" | cut -f1)
    local value=$(echo "$data" | cut -f2)

    if [ -z "$first_model" ] && [ "$value" != "default" ]; then
      first_model="$name"
      first_image="$value"
    fi

    if [ "$value" != "default" ] && [ -n "$name" ]; then
      model_images["$name"]="$value"
    fi

    if [ "$value" = "default" ]; then
      default_model="$name"
    fi
  done

  local selected_model=""
  local selected_image=""

  if [ -n "$default_model" ] && [ -n "${model_images[$default_model]}" ]; then
    selected_model="$default_model"
    selected_image="${model_images[$default_model]}"
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
      echo "$var_name in $ENV_FILE is overridden with new value and exported"
    else
      export "${var_name}=${existing_value}"
      echo "$var_name already exists in $ENV_FILE, the existing value is exported"
    fi
  else
    echo "${var_name}=${var_default_value}" >> "$ENV_FILE"
    export "${var_name}=${var_default_value}"
    echo "$var_name is added to $ENV_FILE and exported"
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
set_and_export_env_var "STACK_VERSION" "c3d7dbacd1" "$UPGRADE_STACK"

set_and_export_env_var "POSTGRES_DB" "liquid_labs"
set_and_export_env_var "POSTGRES_USER" "local_user"
set_and_export_env_var "POSTGRES_PORT" "5432"
set_and_export_env_var "POSTGRES_SCHEMA" "labs"
set_and_export_env_var "POSTGRES_PASSWORD" "local_password"
# The url is liquid-labs-postgres, which must be the same as the service
# name in the docker compose file.
set_and_export_env_var "DATABASE_URL" "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@liquid-labs-postgres:5432/$POSTGRES_DB" true

echo

# Handle model selection logic
declare -A model_images
current_model=""

if [ "$SWITCH_MODEL" = true ]; then
  # Case 1: User wants to switch models
  echo "Switching model..."

  if [ -f "$ENV_FILE" ] && grep -q "^MODEL_NAME=" "$ENV_FILE"; then
    current_model=$(grep "^MODEL_NAME=" "$ENV_FILE" | cut -d '=' -f2-)
  fi

  model_selection=$(select_model "$YAML_FILE" "$current_model")

  if [ -n "$model_selection" ]; then
    model_name=$(echo "$model_selection" | cut -d':' -f1)
    model_image=$(echo "$model_selection" | cut -d':' -f2-)

    echo "Switching to model: $model_name with image: $model_image"

    # Update .env file
    set_and_export_env_var "MODEL_IMAGE" "$model_image" true
    set_and_export_env_var "MODEL_NAME" "$model_name" true

    # Shut down old containers and restart
    echo "Shutting down old model and launching new model..."
    docker compose stop liquid-labs-model-volume liquid-labs-vllm && \
    docker compose rm -f liquid-labs-model-volume
  else
    exit 0
  fi
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
