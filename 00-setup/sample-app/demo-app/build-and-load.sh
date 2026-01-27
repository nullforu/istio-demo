#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="demo-app"
IMAGE_TAG="latest"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-istio-demo}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Building demo-app image...${NC}"

cd "$SCRIPT_DIR"

if command -v podman &> /dev/null; then
    CONTAINER_ENGINE="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_ENGINE="docker"
else
    echo -e "${RED}Error: Neither podman nor docker found${NC}"
    exit 1
fi

echo "Using container engine: $CONTAINER_ENGINE"

$CONTAINER_ENGINE build -t ${IMAGE_NAME}:${IMAGE_TAG} .

echo -e "${YELLOW}Loading image to Kind cluster '${KIND_CLUSTER_NAME}'...${NC}"

if ! kind get clusters | grep -q "${KIND_CLUSTER_NAME}"; then
    echo -e "${RED}Error: Kind cluster '${KIND_CLUSTER_NAME}' not found${NC}"
    exit 1
fi

if [ "$CONTAINER_ENGINE" = "podman" ]; then
    TEMP_TAR=$(mktemp).tar
    $CONTAINER_ENGINE save -o "$TEMP_TAR" ${IMAGE_NAME}:${IMAGE_TAG}
    kind load image-archive "$TEMP_TAR" --name ${KIND_CLUSTER_NAME}
    rm -f "$TEMP_TAR"

    echo -e "${YELLOW}Tagging image in Kind worker node...${NC}"
    for node in $(kind get nodes --name ${KIND_CLUSTER_NAME}); do
        podman exec "$node" ctr --namespace k8s.io images tag \
            "localhost/${IMAGE_NAME}:${IMAGE_TAG}" \
            "docker.io/library/${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || true
    done
else
    kind load docker-image ${IMAGE_NAME}:${IMAGE_TAG} --name ${KIND_CLUSTER_NAME}
fi

echo -e "${GREEN}Successfully built and loaded ${IMAGE_NAME}:${IMAGE_TAG}${NC}"
