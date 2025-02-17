#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <token>"
  exit 1
fi

TOKEN=$1

docker run -d --network liquid_labs_network \
    cloudflare/cloudflared:latest tunnel \
    --no-autoupdate run \
    --protocol h2mux \
    --token $TOKEN
