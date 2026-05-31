#!/bin/bash
# Expose le déploiement local au monde via 4 Cloudflare Quick Tunnels (gratuit, sans compte).
# Chaque tunnel rewrite l'en-tête Host pour qu'il matche le hostname attendu par Traefik.
#
# - tunnel 1 → http://localhost:80   Host: prod.gestion-produits.local
# - tunnel 2 → http://localhost:80   Host: dev.gestion-produits.local
# - tunnel 3 → http://localhost:8081 Host: prod-k8s.gestion-produits.local
# - tunnel 4 → http://localhost:8081 Host: dev-k8s.gestion-produits.local
#
# Prérequis : cloudflared installé (https://github.com/cloudflare/cloudflared/releases)
# Usage : bash scripts/start-tunnels.sh
# Garder le terminal ouvert pendant que le prof teste.

set -euo pipefail

CF=${CLOUDFLARED:-cloudflared}
if ! command -v "$CF" >/dev/null 2>&1; then
  if [ -x "/c/Users/yassi/bin/cloudflared.exe" ]; then
    CF="/c/Users/yassi/bin/cloudflared.exe"
  else
    echo "ERROR: cloudflared introuvable. Voir https://github.com/cloudflare/cloudflared/releases" >&2
    exit 1
  fi
fi

mkdir -p /tmp/tp-tunnels
PIDS=()

start_tunnel() {
  local name="$1"
  local target="$2"
  local host_header="$3"
  local logfile="/tmp/tp-tunnels/${name}.log"

  echo "[start] $name : $target  (Host: $host_header)"
  "$CF" tunnel \
    --url "$target" \
    --http-host-header "$host_header" \
    --no-autoupdate \
    --logfile "$logfile" \
    --loglevel info \
    > "$logfile.stdout" 2>&1 &
  PIDS+=($!)
}

start_tunnel "docker-prod" "http://localhost:80"   "prod.gestion-produits.local"
start_tunnel "docker-dev"  "http://localhost:80"   "dev.gestion-produits.local"
start_tunnel "k8s-prod"    "http://localhost:8081" "prod-k8s.gestion-produits.local"
start_tunnel "k8s-dev"     "http://localhost:8081" "dev-k8s.gestion-produits.local"

cleanup() {
  echo ""
  echo "Arrêt des tunnels..."
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  exit 0
}
trap cleanup INT TERM

echo ""
echo "Attente des URLs publiques (10-20s)..."
sleep 15

echo ""
echo "============================================================"
echo "URLs publiques (à donner au prof) :"
echo "============================================================"
for name in docker-prod docker-dev k8s-prod k8s-dev; do
  url=$(grep -ohE 'https://[a-z0-9-]+\.trycloudflare\.com' "/tmp/tp-tunnels/${name}.log.stdout" 2>/dev/null | head -1 || echo "(en attente — relancer dans 10s)")
  printf "  %-12s %s\n" "$name :" "$url"
done
echo "============================================================"
echo ""
echo "Ctrl+C pour arrêter les tunnels."
wait
