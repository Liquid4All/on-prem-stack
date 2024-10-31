#!/bin/bash

ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: $ENV_FILE does not exist. Please run the launch script first."
  exit 1
fi

echo "Shutting down the Liquid Labs stack..."
docker compose --env-file "$ENV_FILE" down

echo "Liquid Labs stack has been shut down."
echo "The postgres_data volume is not deleted. If needed, please remove it manually."
