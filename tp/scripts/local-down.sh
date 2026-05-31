#!/bin/bash
# Détruit le déploiement local (cluster k3d + stack Docker).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
CLUSTER_NAME="tp-k8s"

echo "[1/2] Suppression du cluster k3d..."
K3D=${K3D:-k3d}
if ! command -v "$K3D" >/dev/null 2>&1 && [ -x "/c/Users/yassi/bin/k3d.exe" ]; then
  K3D="/c/Users/yassi/bin/k3d.exe"
fi
"$K3D" cluster delete "${CLUSTER_NAME}" 2>/dev/null || true

echo "[2/2] Arrêt du stack Docker..."
cd "${ROOT_DIR}/docker"
docker compose down -v

echo "Nettoyage terminé."
