#!/bin/bash
# remove_container.sh

# Check if container name is provided
if [ $# -eq 0 ]; then
    echo "Usage: ./remove_container.sh <container_name>"
    exit 1
fi

CONTAINER_NAME=$1
PROJECT_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
CONTAINERS_DIR="${PROJECT_DIR}/containers"
DOCKER_COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"

# Check if container directory exists
if [ ! -d "${CONTAINERS_DIR}/${CONTAINER_NAME}" ]; then
    echo "Container directory ${CONTAINERS_DIR}/${CONTAINER_NAME} does not exist"
    exit 1
fi

# Check if docker-compose.yml exists
if [ ! -f "${DOCKER_COMPOSE_FILE}" ]; then
    echo "docker-compose.yml not found at ${DOCKER_COMPOSE_FILE}"
    exit 1
fi

# Stop and remove the container using docker-compose
docker compose -f "${DOCKER_COMPOSE_FILE}" rm -sf "${CONTAINER_NAME}"

# Remove container directory
rm -rf "${CONTAINERS_DIR}/${CONTAINER_NAME}"

# Create temporary file
temp_file=$(mktemp)

# Remove service block from docker-compose.yml
awk -v service="${CONTAINER_NAME}" '
    BEGIN { print_line = 1; found_service = 0 }
    $0 ~ "^  " service ":" {
        print_line = 0;
        found_service = 1;
        next;
    }
    found_service && /^  [^ ]/ {
        print_line = 1;
        found_service = 0;
    }
    print_line { print $0 }
' "${DOCKER_COMPOSE_FILE}" > "$temp_file"

# Replace original file with modified content
mv "$temp_file" "${DOCKER_COMPOSE_FILE}"

echo "Container ${CONTAINER_NAME} has been removed successfully"