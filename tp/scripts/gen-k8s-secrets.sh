#!/bin/bash
# Generate strong random passwords and create the K8s Secrets directly via kubectl.
# Bypasses the committed secret.yaml placeholders. Run AFTER terraform K8s apply.
#
# Usage: bash tp/scripts/gen-k8s-secrets.sh
# Requires: KUBECONFIG set to the k3s cluster.

set -euo pipefail

# Make sure namespaces exist (idempotent)
kubectl apply -f "$(dirname "$0")/../kubernetes/prod/namespace.yaml"
kubectl apply -f "$(dirname "$0")/../kubernetes/dev/namespace.yaml"

# --- prod (MySQL) ---
MYSQL_ROOT_PWD="$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)"
MYSQL_APP_PWD="$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)"

kubectl -n gp-prod create secret generic gp-prod-db \
  --from-literal=MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PWD}" \
  --from-literal=MYSQL_USER=appuser \
  --from-literal=MYSQL_PASSWORD="${MYSQL_APP_PWD}" \
  --from-literal=MYSQL_DATABASE=gestion_produits \
  --dry-run=client -o yaml | kubectl apply -f -

# --- dev (PostgreSQL) ---
PG_APP_PWD="$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)"

kubectl -n gp-dev create secret generic gp-dev-db \
  --from-literal=POSTGRES_USER=appuser \
  --from-literal=POSTGRES_PASSWORD="${PG_APP_PWD}" \
  --from-literal=POSTGRES_DB=gestion_produits \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "==============================================="
echo "Secrets generated and applied. The placeholder"
echo "secret.yaml in the repo is no longer used."
echo "==============================================="
