#!/bin/bash

cleanup_containers() {
  echo "Removing all stopped containers..."
  docker container prune -f
  echo "Stopped containers removed"
}

cleanup_images() {
  echo "Removing unused images..."
  docker image prune -a -f
  echo "Unused images removed"
}

cleanup_compose() {
  if [ -f "docker-compose.yml" ]; then
    echo "Stopping and removing Docker Compose containers..."
    docker-compose down --volumes --remove-orphans
    echo "Docker Compose containers stopped and removed"
  else
    echo "docker-compose.yml file not found in current directory"
  fi
}

cleanup_all() {
  echo "Starting a full Docker cleanup..."

  echo "Stopping all containers..."
  docker stop $(docker ps -a -q)

  echo "Delete all containers..."
  docker rm $(docker ps -a -q)

  echo "Delete all images..."
  docker rmi $(docker images -q)

  echo "Delete all volumes..."
  docker volume rm $(docker volume ls -q)

  echo "Delete all networks..."
  docker network prune -f

  echo "Docker cleanup complete"
}

show_help() {
  echo "Script usage:"
  echo "  ./docker-cleanup.sh [command]"
  echo ""
  echo "Available commands:"
  echo "  containers  - remove stopped containers"
  echo "  images     - remove unused images"
  echo "  compose    - clear Docker Compose"
  echo "  all        - Docker full cleanup"
  echo "  help       - show this help message"
}

case "$1" in
"containers")
  cleanup_containers
  ;;
"images")
  cleanup_images
  ;;
"compose")
  cleanup_compose
  ;;
"all")
  cleanup_all
  ;;
"help" | "")
  show_help
  ;;
*)
  echo "Unknown command: $1"
  show_help
  exit 1
  ;;
esac
