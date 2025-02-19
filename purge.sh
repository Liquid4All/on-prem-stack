#!/bin/bash

echo "WARNING: This script will remove all Liquid Labs components:"
echo "  - Stop and remove all containers"
echo "  - Delete postgres_data volume (all database data will be lost)"
echo "  - Remove liquid_labs_network"
echo "  - Clean up dangling images"
echo
read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Cleanup cancelled."
    exit 1
fi

echo "Starting full cleanup of Liquid Labs stack..."

# Shutdown all containers
echo "Shutting down containers..."
docker compose down

# Remove the postgres volume
echo "Removing postgres_data volume..."
if docker volume ls | grep -q "postgres_data"; then
    docker volume rm postgres_data
    echo "postgres_data volume removed."
else
    echo "postgres_data volume not found."
fi

# Remove the network
echo "Removing liquid_labs_network..."
if docker network ls | grep -q "liquid_labs_network"; then
    docker network rm liquid_labs_network
    echo "liquid_labs_network removed."
else
    echo "liquid_labs_network not found."
fi

echo "Deleting .env file..."
rm -f .env

echo "Cleanup complete. All Liquid on-prem stack components have been removed."
