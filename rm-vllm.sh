#!/bin/bash

list_containers() {
    local containers=($(docker ps --filter "ancestor=vllm/vllm-openai" --format "{{.Names}}"))

    if [ ${#containers[@]} -eq 0 ]; then
        echo "No running vLLM containers found."
        return 1
    fi

    echo "Running vLLM containers:"
    echo "----------------------"

    counter=1
    for i in "${!containers[@]}"; do
        local name="${containers[$i]}"
        local port=$(docker port "$name" 8000 2>/dev/null | cut -d ':' -f2)
        echo "$counter) $name (Port: $port)"
        ((counter++))
    done

    return 0
}

stop_container() {
    local containers=($(docker ps --filter "ancestor=vllm/vllm-openai:latest" --format "{{.Names}}"))
    local selection=$1

    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -lt ${#containers[@]} ]; then
        local container_name="${containers[$selection]}"
        echo "Stopping and removing container: $container_name"
        docker stop "$container_name" && docker rm "$container_name"
        if [ $? -eq 0 ]; then
            echo "Successfully stopped and removed $container_name"
        else
            echo "Failed to stop and remove $container_name"
        fi
    else
        echo "Invalid selection: $selection"
    fi
}

while true; do
    clear

    if list_containers; then
        echo
        echo "Enter container number to stop it, or 'q' to quit:"
        read -r input

        if [ "$input" = "q" ]; then
            echo "Exiting..."
            break
        fi

        stop_container "$input"

        # pause to show the result
        echo
        echo "Press Enter to continue..."
        read -r
    else
        echo
        echo "Press Enter to refresh, or 'q' to quit:"
        read -r input

        if [ "$input" = "q" ]; then
            echo "Exiting..."
            break
        fi
    fi
done
