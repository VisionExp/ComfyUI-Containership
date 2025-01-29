#!/bin/bash

# Configuration variables
BASE_DIR="containers"
SHARED_MODELS_DIR="$(pwd)/shared_models"
DOCKER_NETWORK="comfyui_network"
BASE_PORT=8188
DOCKER_COMPOSE_FILE="docker-compose.yml"
TEMPLATES_DIR="templates"

if [ ! -d "$BASE_DIR" ]; then
  echo "Containers directory not found!"
  mkdir -p "containers"
  echo "Containers directory was created!"
fi

# Check if templates directory exists
if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "Error: Templates directory not found!"
    echo "Please create '$TEMPLATES_DIR' directory with:"
    echo "  - dockerfile.template"
    echo "  - service.template"
    echo "  - setup.template"
    exit 1
fi

# Function to replace template variables
replace_template_vars() {
    local template="$1"
    local output="$2"
    sed -e "s|{{container_name}}|$CONTAINER_NAME|g" \
        -e "s|{{port}}|$PORT|g" \
        -e "s|{{shared_models_dir}}|$SHARED_MODELS_DIR|g" \
        -e "s|{{network}}|$DOCKER_NETWORK|g" \
        "$template" > "$output"
}

# Function to check if docker-compose.yml exists and create if not
init_docker_compose() {
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        cat > "$DOCKER_COMPOSE_FILE" << EOL
version: '3.8'

services:

networks:
  ${DOCKER_NETWORK}:
    external: true
EOL
    fi
}

# Function to get next available port
get_next_port() {
    local highest_port=$(grep -oP '"\K[0-9]+(?=:8188")' "$DOCKER_COMPOSE_FILE" 2>/dev/null | sort -rn | head -1)
    if [ -z "$highest_port" ]; then
        echo $BASE_PORT
    else
        echo $((highest_port + 1))
    fi
}

# Function to add new service to docker-compose.yml
add_service_to_compose() {
    local container_name=$1
    local port=$2

    # Create temporary service file from template
    replace_template_vars "$TEMPLATES_DIR/service.template" "temp_service.yml"

    # Insert new service before the last line (networks section)
    sed -i '$r temp_service.yml' "$DOCKER_COMPOSE_FILE"
    rm temp_service.yml
}

# Function to create container directory structure
create_container_directory() {
    local container_name=$1
    local container_dir="$container_name"

    echo "Creating container directory structure for $container_name..."

    # Create directory structure
    mkdir -p "$container_dir"/{input,output,custom_nodes,scripts}

    # Create Dockerfile from template
    replace_template_vars "$TEMPLATES_DIR/dockerfile.template" "$container_dir/Dockerfile"

    # Create setup script from template
    replace_template_vars "$TEMPLATES_DIR/setup.template" "$container_dir/scripts/example_setup.sh"
    chmod +x "$container_dir/scripts/example_setup.sh"
}

# Main script execution
if [ $# -ne 1 ]; then
    echo "Usage: $0 <container_name>"
    exit 1
fi

CONTAINER_NAME=$1

# Create Docker network if it doesn't exist
docker network create $DOCKER_NETWORK 2>/dev/null || true

# Initialize docker-compose.yml if it doesn't exist
init_docker_compose

# Get next available port
PORT=$(get_next_port)

# Create container directory
create_container_directory "$CONTAINER_NAME"

# Add service to docker-compose.yml
add_service_to_compose "$CONTAINER_NAME" "$PORT"

echo "
Container setup complete!
New service '$CONTAINER_NAME' added to $DOCKER_COMPOSE_FILE
Port assigned: $PORT

To start all containers:
  docker-compose up -d --build

To start only this container:
  docker-compose up -d --build $CONTAINER_NAME

Access new ComfyUI instance at http://localhost:$PORT

Note: All containers share models from: $SHARED_MODELS_DIR
"