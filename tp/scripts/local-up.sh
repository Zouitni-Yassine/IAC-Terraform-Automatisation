#!/bin/bash
# Plan B local : reproduit en local ce que les Terraform OCI auraient fait.
#
#   - Stack Docker (Traefik + prod MySQL + dev PostgreSQL) via docker compose
#   - Cluster Kubernetes 3 nœuds (1 server + 2 agents) via k3d (= k3s in Docker)
#   - StorageClass: local-path (par défaut dans k3d, équivalent fonctionnel
#     de Longhorn pour cette démo, vu qu'on est sur 1 host Docker)
#   - Ingress Traefik fourni nativement par k3s/k3d
#
# Prérequis : Docker Desktop, kubectl, k3d (https://k3d.io)
# Installer k3d :  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
CLUSTER_NAME="tp-k8s"

# ============= 1. Stack Docker (prod + dev + Traefik) =============
echo ""
echo "============================================================"
echo "[1/4] Stack Docker (Traefik + prod + dev)"
echo "============================================================"
cd "${ROOT_DIR}/docker"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "[info] .env créé depuis .env.example (mdp de démo)"
fi
docker compose up -d --build

# ============= 2. Cluster k3d (3 nœuds) =============
echo ""
echo "============================================================"
echo "[2/4] Cluster Kubernetes ${CLUSTER_NAME} (k3d, 1 server + 2 agents)"
echo "============================================================"
K3D=${K3D:-k3d}
if ! command -v "$K3D" >/dev/null 2>&1; then
  if [ -x "/c/Users/yassi/bin/k3d.exe" ]; then
    K3D="/c/Users/yassi/bin/k3d.exe"
  else
    echo "ERROR: k3d introuvable. Installer: https://k3d.io" >&2; exit 1
  fi
fi
if "$K3D" cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME} "; then
  echo "[info] cluster ${CLUSTER_NAME} déjà existant, recyclage"
else
  # Le LB k3d écoute sur 8081 (host) → 80 (ingress) parce que 80 est déjà
  # pris par le Traefik du stack Docker au-dessus.
  "$K3D" cluster create "${CLUSTER_NAME}" \
    --servers 1 \
    --agents 2 \
    --port "8081:80@loadbalancer" \
    --wait
fi

# Sur Windows + Docker Desktop, host.docker.internal n'est pas résolvable depuis kubectl
# côté hôte. On réécrit l'API server vers 127.0.0.1 (k3d expose la LB sur localhost).
KUBECONFIG_FILE="${HOME}/.kube/config-tp-k8s"
mkdir -p "$(dirname "$KUBECONFIG_FILE")"
"$K3D" kubeconfig get "${CLUSTER_NAME}" | sed 's|host.docker.internal|127.0.0.1|g' > "$KUBECONFIG_FILE"
export KUBECONFIG="$KUBECONFIG_FILE"
echo "[info] KUBECONFIG => $KUBECONFIG_FILE"

kubectl cluster-info
kubectl get nodes -o wide

# ============= 3. Secrets aléatoires =============
echo ""
echo "============================================================"
echo "[3/4] Secrets K8s (mdp aléatoires via openssl)"
echo "============================================================"
bash "${SCRIPT_DIR}/gen-k8s-secrets.sh"

# ============= 4. Manifests prod + dev =============
echo ""
echo "============================================================"
echo "[4/4] Manifests K8s prod (MySQL) + dev (PostgreSQL)"
echo "============================================================"
# En local on n'a pas Longhorn (1 seul host Docker), on bascule sur local-path
# que k3d fournit nativement. Cela ne change rien à l'application déployée.
for d in prod dev; do
  kubectl kustomize --load-restrictor=LoadRestrictionsNone "${ROOT_DIR}/kubernetes/${d}" \
    | sed 's/storageClassName: longhorn/storageClassName: local-path/g' \
    | kubectl apply -f -
done

echo ""
echo "[info] attente que les pods soient Ready (peut prendre quelques minutes)..."
kubectl -n gp-prod wait --for=condition=Ready pod -l app=mysql --timeout=300s || true
kubectl -n gp-prod wait --for=condition=Ready pod -l app=php   --timeout=300s || true
kubectl -n gp-dev  wait --for=condition=Ready pod -l app=postgres --timeout=300s || true
kubectl -n gp-dev  wait --for=condition=Ready pod -l app=php       --timeout=300s || true

echo ""
echo "============================================================"
echo "Déploiement local terminé."
echo "============================================================"
echo ""
echo "DOCKER (port 80) :"
echo "  curl -H 'Host: prod.gestion-produits.local' http://localhost/"
echo "  curl -H 'Host: dev.gestion-produits.local'  http://localhost/"
echo ""
echo "KUBERNETES (port 8081) :"
echo "  curl -H 'Host: prod-k8s.gestion-produits.local' http://localhost:8081/"
echo "  curl -H 'Host: dev-k8s.gestion-produits.local'  http://localhost:8081/"
echo ""
echo "Pour accès navigateur local, ajouter dans le hosts :"
echo "  127.0.0.1 prod.gestion-produits.local dev.gestion-produits.local"
echo "  127.0.0.1 prod-k8s.gestion-produits.local dev-k8s.gestion-produits.local"
echo "  (et utiliser http://prod-k8s.gestion-produits.local:8081/ pour K8s)"
echo ""
echo "Pour accès public (prof) : bash scripts/start-tunnels.sh"
echo "============================================================"
