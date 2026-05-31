#!/bin/bash
# Apply prod + dev manifests to the k3s cluster.
# Prereq: KUBECONFIG points to the cluster.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."

echo "==> Generating and applying K8s Secrets (random passwords)..."
bash "${SCRIPT_DIR}/gen-k8s-secrets.sh"

echo "==> Waiting for Longhorn storage class..."
for i in $(seq 1 60); do
  if kubectl get storageclass longhorn >/dev/null 2>&1; then
    echo "Longhorn ready."
    break
  fi
  sleep 5
done

echo "==> Applying PROD manifests (MySQL)..."
kubectl kustomize --load-restrictor=LoadRestrictionsNone "${ROOT_DIR}/kubernetes/prod" | kubectl apply -f -

echo "==> Applying DEV manifests (PostgreSQL)..."
kubectl kustomize --load-restrictor=LoadRestrictionsNone "${ROOT_DIR}/kubernetes/dev" | kubectl apply -f -

echo ""
echo "==> Waiting for all pods to be Ready..."
kubectl -n gp-prod wait --for=condition=Ready pod -l app=mysql --timeout=300s || true
kubectl -n gp-prod wait --for=condition=Ready pod -l app=php   --timeout=300s || true
kubectl -n gp-dev  wait --for=condition=Ready pod -l app=postgres --timeout=300s || true
kubectl -n gp-dev  wait --for=condition=Ready pod -l app=php       --timeout=300s || true

echo ""
echo "==============================================="
echo "Pods:"
kubectl -n gp-prod get pods,pvc,svc,ingress
echo ""
kubectl -n gp-dev  get pods,pvc,svc,ingress
echo "==============================================="
