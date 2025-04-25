#!/bin/bash

if [[ "$#" -eq 0 ]]; then
  if [[ -f ./docker-compose.yaml.bak ]]; then
    # If a backup exists, revert to the original docker-compose.yaml file
    mv ./docker-compose.yaml.bak ./docker-compose.yaml
    echo "Reverted to the original docker-compose.yaml file."
    exit 0
  fi
  # Default behavior: switch to no web mode
  mv ./docker-compose.yaml ./docker-compose.yaml.bak
  cp ./docker-compose-no-web.yaml ./docker-compose.yaml
  echo "Switched to no web mode. To revert, run this script again."
  exit 0
else
  case $1 in
    --help)
      echo "Usage: $0 [--help]"
      echo "This script is used to switch between web/no-web mode."
      echo "  --help: Show this help message."
      exit 0
      ;;
    *)
      echo "Invalid argument. Use --help for usage information."
      exit 1
      ;;
  esac
fi
