#!/bin/bash

ENV_FILE=".env"
YAML_FILE="models.yaml"

source ./helpers.sh

UPGRADE_STACK=false
UPGRADE_MODEL=false

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --upgrade-stack) UPGRADE_STACK=true ;;
    --upgrade-model) UPGRADE_MODEL=true ;;
    *) echo "Unknown parameter: $1" >&2; exit 1 ;;
  esac
  shift
done

get_model_from_yaml() {
  local yaml_file=$1

  if [ ! -f "$yaml_file" ]; then
    echo "Error: $yaml_file not found!" >&2
    exit 1
  fi

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

extract_model_name() {
  local image_tag="$1"
  local pattern="liquidai/[^-]+-([^:]+)"

  if [[ $image_tag =~ $pattern ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "No match found" >&2
    return 1
  fi
}

touch "$ENV_FILE"

set_and_export_env_var "JWT_SECRET" "$(generate_random_string 64)"
set_and_export_env_var "API_SECRET" "local_api_token"
set_and_export_env_var "AUTH_SECRET" "$(generate_random_string 64)"

set_and_export_env_var "STACK_VERSION" "c3d7dbacd1" "$UPGRADE_STACK"

declare -A model_images
model_info=$(get_model_from_yaml "$YAML_FILE")
model_name=$(echo "$model_info" | cut -d':' -f1)
model_image=$(echo "$model_info" | cut -d':' -f2-)

echo "Default model: $model_name with image: $model_image"
set_and_export_env_var "MODEL_IMAGE" "$model_image" "$UPGRADE_MODEL"
set_and_export_env_var "MODEL_NAME" "$model_name" true

set_and_export_env_var "POSTGRES_DB" "liquid_labs"
set_and_export_env_var "POSTGRES_USER" "local_user"
set_and_export_env_var "POSTGRES_PORT" "5432"
set_and_export_env_var "POSTGRES_SCHEMA" "labs"
set_and_export_env_var "POSTGRES_PASSWORD" "local_password"
# The url is liquid-labs-postgres, which must be the same as the service
# name in the docker compose file.
set_and_export_env_var "DATABASE_URL" "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@liquid-labs-postgres:5432/$POSTGRES_DB" true

if ! docker volume inspect postgres_data > /dev/null 2>&1; then
  echo "Creating Docker volume: postgres_data"
  docker volume create postgres_data
else
  echo "Docker volume postgres_data already exists"
fi

docker compose --env-file "$ENV_FILE" up -d --wait

echo "The on-prem stack is now running."

print_usage_instructions "$MODEL_NAME" 8000 "$API_SECRET"
