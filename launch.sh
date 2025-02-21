#!/bin/bash

ENV_FILE=".env"

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
set_and_export_env_var "MODEL_IMAGE" "liquidai/lfm-3b-jp:0.0.2-e" "$UPGRADE_MODEL"

MODEL_NAME=lfm-$(extract_model_name "$MODEL_IMAGE")
set_and_export_env_var "MODEL_NAME" "$MODEL_NAME" true

set_and_export_env_var "POSTGRES_DB" "liquid_labs"
set_and_export_env_var "POSTGRES_USER" "local_user"
set_and_export_env_var "POSTGRES_PORT" "5432"
set_and_export_env_var "POSTGRES_SCHEMA" "labs"
set_and_export_env_var "POSTGRES_PASSWORD" "local_password"
# The url is liquid-labs-postgres, which must be the same as the service
# name in the docker compose file.
set_and_export_env_var "DATABASE_URL" "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@liquid-labs-postgres:5432/$POSTGRES_DB" true
set_and_export_env_var "DEFAULT_SYSTEM_PROMPT" "以下は、タスクを説明する指示と、文脈のある入力の組み合わせです。要求を適切に満たす応答を書きなさい。"

if ! docker volume inspect postgres_data > /dev/null 2>&1; then
  echo "Creating Docker volume: postgres_data"
  docker volume create postgres_data
else
  echo "Docker volume postgres_data already exists"
fi

docker compose --env-file "$ENV_FILE" up -d --wait

echo "The on-prem stack is now running."

print_usage_instructions "$MODEL_NAME" 8000 "$API_SECRET"
