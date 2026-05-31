# TP noté – IaC Terraform + Conteneurisation avancée

**Auteur** : Yassine Zouitni — M1 DEV EPSI
**Module** : IaC – Terraform / Conteneurisation avancée
**Date** : mai 2026
**Application déployée** : [gestion-produits](https://gl.avalone-fr.com/anthony/gestion-produits) (PHP + MySQL/MariaDB → PostgreSQL pour la version dev)

---

## Objectif

Déployer l'application `gestion-produits` (PHP + base de données) sur deux infrastructures distinctes, **toutes les deux décrites en Terraform** :

1. **Infra Docker** — 1 VM avec Traefik en reverse proxy frontal
2. **Infra Kubernetes (k3s)** — cluster 3 nœuds avec stockage partagé

Avec en plus une **version dev** utilisant PostgreSQL (au lieu de MySQL) déployée sur les deux infras.

---

## Note importante sur la cible de déploiement

Le TP autorise n'importe quelle infrastructure (Proxmox, hyperviseur, cloud public…) tant qu'elle est **automatisable** et **testable**.

J'ai écrit deux variantes complètes du code Terraform :

| Variante | Provider | But | Statut |
|---|---|---|---|
| **Cloud (OCI)** — [`terraform/docker-infra/`](terraform/docker-infra/), [`terraform/k8s-infra/`](terraform/k8s-infra/) | `oracle/oci` | Cible Oracle Cloud Always Free (4 vCPU ARM, 24 GB RAM, gratuit à vie) — c'était mon plan initial | ⚠️ Validé par `terraform plan`, mais `terraform apply` échoue avec `Out of host capacity` : Oracle a limité fortement la disponibilité des ARM A1 Free Tier depuis 2024, et la région `eu-paris-1` était saturée au moment du rendu. Problème connu et reproductible côté OCI, pas dans le code. |
| **Local (Plan B reproductible)** — [`scripts/local-up.sh`](scripts/local-up.sh) | `kreuzwerker/docker` (Docker Compose) + **k3d** (cluster k3s in Docker) | Reproduit en local strictement la même architecture (Traefik + 1 host Docker, cluster k3s 3 nœuds) pour que le prof puisse tester via Cloudflare Tunnel | ✅ Validé bout en bout : login admin/password OK sur les 4 URLs |

Les deux variantes utilisent **exactement les mêmes** :
- images Docker (mêmes Dockerfile)
- `docker-compose.yml` (avec Traefik et les labels d'Ingress)
- manifests Kubernetes (kustomize prod + dev)
- script de génération des Secrets aléatoires

→ Le Plan B est isofonctionnel au déploiement cloud. Avec un compte OCI ayant accès à la capacité ARM, `terraform apply` sur les deux dossiers `terraform/*-infra/` provisionnerait l'infra publique sans modification du code applicatif.

---

## Architecture

```
                ┌────────────────────────────────────────┐
                │  Poste local (hosts file)              │
                │  prod.gestion-produits.local           │
                │  dev.gestion-produits.local            │
                │  prod-k8s.gestion-produits.local       │
                │  dev-k8s.gestion-produits.local        │
                └──────────────────┬─────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                                         ▼
   ┌──────────────────────────┐         ┌────────────────────────────────┐
   │  INFRA DOCKER             │         │  INFRA KUBERNETES              │
   │  (Terraform OCI ou        │         │  (Terraform OCI ou k3d local)  │
   │   docker compose local)   │         │                                │
   │  ──────────────────────   │         │  k3s 3 nœuds                   │
   │  Ubuntu/Linux + Docker    │         │  + Traefik Ingress (intégré)   │
   │                           │         │  + Storage (Longhorn / k3d     │
   │                           │         │    local-path)                 │
   │  ┌──────┐                 │         │                                │
   │  │Traefik│ :80            │         │  ┌─ namespace gp-prod ─┐       │
   │  └──┬───┘                 │         │  │ Deployment php × 2 │       │
   │     ├──→ php-prod ──→ mysql         │  │ Deployment mysql   │       │
   │     │   (prod.*)          │         │  │ PVC 5Gi            │       │
   │     └──→ php-dev  ──→ postgres      │  │ Ingress prod-k8s.* │       │
   │         (dev.*)           │         │  └────────────────────┘       │
   │                           │         │  ┌─ namespace gp-dev ─┐       │
   │                           │         │  │ Deployment php × 2 │       │
   │                           │         │  │ Deployment postgres│       │
   │                           │         │  │ PVC 5Gi            │       │
   │                           │         │  │ Ingress dev-k8s.*  │       │
   │                           │         │  └────────────────────┘       │
   └──────────────────────────┘         └────────────────────────────────┘
                       │                                  │
                       │  Cloudflare Quick Tunnel         │
                       └────────────┬─────────────────────┘
                                    ▼
                    https://*.trycloudflare.com (URLs publiques)
```

---

## Structure du dépôt

```
tp/
├── README.md                # Ce fichier
├── CHECKLIST.md             # Suivi détaillé des tâches
├── docker/                  # Conteneurisation
│   ├── docker-compose.yml         # Stack complète prod + dev + Traefik
│   ├── docker-compose.prod.yml    # Juste prod, pour test local rapide
│   ├── .env.example
│   ├── php/                 # Image PHP custom (PDO mysql + pgsql)
│   │   ├── Dockerfile
│   │   └── www/             # Code de l'app modifié
│   ├── mysql/               # Image MySQL avec init data
│   │   ├── Dockerfile
│   │   └── init/01-gestion_produits.sql
│   └── postgres/            # Image PostgreSQL avec init data (dev)
│       ├── Dockerfile
│       └── init/01-gestion_produits.sql
├── terraform/
│   ├── docker-infra/        # OCI : 1 VM ARM avec Docker
│   └── k8s-infra/           # OCI : 3 VMs ARM avec k3s + Longhorn
├── kubernetes/
│   ├── prod/                # Manifests MySQL backend
│   └── dev/                 # Manifests PostgreSQL backend
└── scripts/
    ├── local-up.sh          # Déploiement local complet (Docker + k3d + K8s)
    ├── local-down.sh        # Nettoyage local
    ├── start-tunnels.sh     # Cloudflare Tunnel pour rendre les URLs publiques
    ├── gen-k8s-secrets.sh   # Génération de Secrets aléatoires
    ├── deploy-k8s.sh        # Apply des manifests K8s sur un cluster existant
    └── build-and-push-php.sh # Build + push de l'image PHP sur GHCR
```

---

## Modifications apportées à l'application

Le code original avait :
- **Credentials hardcodés** dans [`connect.php`](docker/php/www/connect.php) (host=`db`, user=`root`, password=`root`)
- **`SHA2()`** côté SQL pour le hash du mot de passe dans [`auth.php`](docker/php/www/auth.php) — fonction spécifique à MySQL

Pour permettre le déploiement avec MySQL **et** PostgreSQL :

| Fichier | Modification |
|---|---|
| `connect.php` | Lecture des credentials depuis variables d'env (`DB_TYPE`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`). Le DSN PDO change selon `DB_TYPE` (mysql ou pgsql). |
| `auth.php` | Hash SHA-256 calculé **en PHP** (`hash('sha256', $password)`) au lieu de `SHA2()` côté SQL. Identique en MySQL et PostgreSQL. `display_errors` retiré. |

---

## Prérequis

- **Terraform** ≥ 1.5 (ou OpenTofu)
- **Docker Desktop**
- **kubectl** ≥ 1.28
- **k3d** ≥ 5.0 — `curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash`
- **cloudflared** (pour les tunnels publics) — `winget install Cloudflare.cloudflared` (Windows) / `brew install cloudflared` (macOS)
- **SSH key** : `~/.ssh/id_ed25519` + `.pub` (pour la variante OCI)

---

## Quickstart — déploiement local (Plan B, testé ✅)

```bash
# 1. Tout déployer (build images + k3d + manifests + secrets)
bash tp/scripts/local-up.sh

# 2. Tester depuis ton poste avec curl
curl -H 'Host: prod.gestion-produits.local'    http://localhost/        # Docker prod (MySQL)
curl -H 'Host: dev.gestion-produits.local'     http://localhost/        # Docker dev (PostgreSQL)
curl -H 'Host: prod-k8s.gestion-produits.local' http://localhost:8081/  # K8s prod
curl -H 'Host: dev-k8s.gestion-produits.local'  http://localhost:8081/  # K8s dev

# 3. Pour le navigateur, ajouter dans %SystemRoot%\System32\drivers\etc\hosts :
#    127.0.0.1 prod.gestion-produits.local dev.gestion-produits.local
#    127.0.0.1 prod-k8s.gestion-produits.local dev-k8s.gestion-produits.local
#    (les URLs K8s s'ouvrent avec :8081)

# 4. Pour rendre les URLs accessibles à un testeur externe (prof)
bash tp/scripts/start-tunnels.sh
# Cloudflare affiche 2 URLs https://*.trycloudflare.com (une par port)

# 5. Nettoyage à la fin
bash tp/scripts/local-down.sh
```

**Login app** : `admin` / `password`

---

## Quickstart — déploiement cloud (Plan A, à utiliser si OCI a de la capacité)

### A. Setup OCI (compte + API key)

1. https://www.oracle.com/cloud/free/ → Start for free, CB pour vérification (aucun débit)
2. Choisir le **home region**
3. Générer une clé API localement et l'uploader dans **My profile → API keys** :
   ```bash
   mkdir -p ~/.oci
   openssl genrsa -out ~/.oci/oci_api_key.pem 2048
   chmod 600 ~/.oci/oci_api_key.pem
   openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem
   ```
4. Récupérer les OCID Tenancy + User + le Fingerprint

### B. Déploiement Docker infra

```bash
cd tp/terraform/docker-infra
cp terraform.tfvars.example terraform.tfvars
# éditer terraform.tfvars
terraform init
terraform apply
```

Provisionne : VCN `10.10.0.0/16` + IGW + route + Security List (22,80,443) + Subnet public + Instance `VM.Standard.A1.Flex` Ubuntu 22.04 ARM avec cloud-init qui installe Docker, clone le repo, et lance `docker compose up -d`.

### C. Déploiement K8s infra

```bash
cd tp/terraform/k8s-infra
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

Provisionne : VCN `10.20.0.0/16` + 1 instance k3s-server + 2 instances k3s-agent. Cloud-init installe k3s + Longhorn automatiquement. Le token de cluster est généré par `random_password` et partagé entre les nœuds.

Récupération du kubeconfig :
```bash
ssh ubuntu@<IP_SERVER> sudo cat /etc/rancher/k3s/k3s.yaml \
  | sed "s|127.0.0.1|<IP_SERVER>|" > kubeconfig
export KUBECONFIG=$PWD/kubeconfig
```

Puis :
```bash
bash tp/scripts/build-and-push-php.sh    # publication image PHP sur GHCR
bash tp/scripts/deploy-k8s.sh            # apply manifests prod + dev
```

---

## Mise à jour de l'application (4 pts)

Le processus de MàJ est automatisé :

```bash
# 1. Modifier le code dans tp/docker/php/www/
# 2. Rebuild + push de l'image
bash tp/scripts/build-and-push-php.sh

# 3a. Rollout sur Docker (VM Docker ou local)
cd tp/docker && docker compose up -d --build

# 3b. Rollout sur Kubernetes (zero-downtime grâce aux 2 replicas + readinessProbe)
kubectl -n gp-prod rollout restart deployment/php
kubectl -n gp-dev  rollout restart deployment/php
```

La version dev (PostgreSQL) est déjà déployée à côté de la prod (MySQL). Le passage de l'une à l'autre se fait par une simple variable d'env `DB_TYPE` (mysql/pgsql) lue par `connect.php`.

---

## URLs finales

| Environnement | Infra | URL locale | URL publique (Cloudflare Tunnel) |
|---|---|---|---|
| Prod (MySQL) | Docker | http://prod.gestion-produits.local/ | https://satisfaction-blessed-span-pens.trycloudflare.com |
| Dev (PostgreSQL) | Docker | http://dev.gestion-produits.local/ | https://indicators-falls-ticket-magnet.trycloudflare.com |
| Prod (MySQL) | Kubernetes | http://prod-k8s.gestion-produits.local:8081/ | https://honor-railway-burlington-facilitate.trycloudflare.com |
| Dev (PostgreSQL) | Kubernetes | http://dev-k8s.gestion-produits.local:8081/ | https://conclude-lesson-enhancement-fog.trycloudflare.com |

**Credentials de l'app** : `admin` / `password`

> Les URLs publiques sont des tunnels Cloudflare Quick (anonymes, gratuits). Elles restent valides tant que le tunnel tourne sur mon poste (`bash scripts/start-tunnels.sh`). Si une URL ne répond plus, c'est que le tunnel a été coupé — me prévenir.

---

## Points spécifiques à noter pour la lecture du TP

| Exigence du sujet | Comment c'est traité |
|---|---|
| URL sur ports par défaut (80/443) | Les 4 URLs publiques Cloudflare Tunnel sont en `https://...trycloudflare.com` → **port 443 par défaut**. En local, le stack Docker est sur :80 et le cluster k3d est sur :8081 (port libre, conflit physique avec :80 sur le même host) — invisible depuis l'extérieur via le tunnel. |
| Stockage partagé K8s 3 nœuds | **Code Terraform OCI** : Longhorn v1.7.2 installé via cloud-init sur le k3s-server (`tp/terraform/k8s-infra/cloud-init/k3s-server.yaml`). **Repli local k3d** : `local-path` car les 3 nœuds k3d sont des conteneurs Docker sur le même host (filesystem partagé de fait). Le sed dans `local-up.sh` remplace `storageClassName: longhorn` → `local-path`. |
| 2 replicas PHP K8s (HA) | Manifests = `replicas: 2`. Pour la démo, scaled à 1 (session PHP locale au pod, pas de Redis = pas de session-sharing). Voir `kubernetes/prod/php-deployment.yaml` ligne 23. En prod réelle on ajouterait un Redis pour les sessions. |
| Automatisation max | Tout est piloté par 4 scripts shell : `local-up.sh` (déploie tout en 1 commande), `start-tunnels.sh` (publie via Cloudflare), `gen-k8s-secrets.sh` (mdp aléatoires), `local-down.sh` (nettoyage). Pour OCI : `terraform apply` une fois par dossier. |
| Conteneurisation environnements multi | Image PHP unique (`yassinezouitni/gestion-produits-php`) déployée 4× avec env vars différentes — même artefact en prod et en dev, sur Docker et K8s. |

## Limitations / vulnérabilités connues (upstream)

Le code source de l'application `gestion-produits` (fourni par le prof) contient
des vulnérabilités héritées qui n'ont **pas** été corrigées car elles sont hors
scope du TP (qui porte sur l'IaC + la conteneurisation). Si on devait livrer en
prod réelle il faudrait :

- `validation.php` n'a pas de `secu()` → ajout/suppression de produits accessible
  sans session (Broken Access Control)
- Upload de fichiers : pas de validation MIME/extension stricte (Arbitrary File
  Upload → RCE potentielle)
- Sortie HTML : pas de `htmlspecialchars()` autour des valeurs DB
  (XSS stocké/reflété sur `home.php`, `produit.php`, `form_produit.php`)
- Hash mot de passe : SHA-256 simple, devrait être `password_hash()` bcrypt/argon2id

Côté infra/conteneurisation (notre périmètre), corrections appliquées :

- Traefik dashboard (port 8080) bindé sur `127.0.0.1` uniquement → accès via
  tunnel SSH `ssh -L 8080:localhost:8080 ubuntu@<IP>`
- `ini_set('display_errors', '1')` retiré d'`auth.php` (pas de stack trace en prod)
- Secrets K8s générés à la volée par `scripts/gen-k8s-secrets.sh`
  (`openssl rand -base64 32`) plutôt que versionnés en clair

## Auteur

Yassine Zouitni — yassine.zouitni@linctra.com
Dépôt : https://github.com/Zouitni-Yassine/IAC-Terraform-Automatisation
