#!/bin/bash
# Build and push the gestion-produits PHP image to GHCR for arm64 (OCI A1) and amd64.
#
# Prereqs:
#   - Docker Desktop with buildx (default)
#   - A GitHub Personal Access Token with write:packages scope
#   - GHCR_USER and GHCR_TOKEN env vars set, or do `docker login ghcr.io` first

set -euo pipefail

GHCR_USER="${GHCR_USER:-zouitni-yassine}"
IMAGE_TAG="${IMAGE_TAG:-tp}"
IMAGE="ghcr.io/${GHCR_USER}/gestion-produits-php:${IMAGE_TAG}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHP_DIR="${SCRIPT_DIR}/../docker/php"

if [ -n "${GHCR_TOKEN:-}" ]; then
  echo "${GHCR_TOKEN}" | docker login ghcr.io -u "${GHCR_USER}" --password-stdin
fi

docker buildx create --use --name gp-builder 2>/dev/null || docker buildx use gp-builder

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag "${IMAGE}" \
  --push \
  "${PHP_DIR}"

echo ""
echo "==============================================="
echo "Pushed ${IMAGE}"
echo ""
echo "Now make this package PUBLIC on GitHub:"
echo "  https://github.com/${GHCR_USER}?tab=packages"
echo "  → click on gestion-produits-php → Package settings → Change visibility → Public"
echo "==============================================="
