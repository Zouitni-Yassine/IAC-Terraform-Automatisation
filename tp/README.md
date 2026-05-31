# TP noté – IaC Terraform + Conteneurisation avancée

**Auteur** : Yassine Zouitni — M1 DEV EPSI
**Module** : IaC – Terraform / Conteneurisation avancée
**Date** : mai 2026
**Application déployée** : [gestion-produits](https://gl.avalone-fr.com/anthony/gestion-produits) (PHP + MySQL/MariaDB → PostgreSQL pour la version dev)

---

## Objectif

Déployer l'application `gestion-produits` (PHP + base de données) sur deux infrastructures distinctes, toutes deux décrites en Terraform :

1. **Infra Docker** — 1 VM avec Traefik en reverse proxy frontal
2. **Infra Kubernetes (k3s)** — cluster 3 nœuds avec stockage partagé

Une **version dev** utilisant PostgreSQL (au lieu de MySQL) est également déployée sur les deux infras.

---

## Cible de déploiement

Le sujet autorise n'importe quelle infrastructure (Proxmox, hyperviseur, cloud public…) tant qu'elle est automatisable et testable. Deux variantes Terraform sont fournies :

| Variante | Provider | Description | Statut |
|---|---|---|---|
| **Cloud (OCI)** — [`terraform/docker-infra/`](terraform/docker-infra/), [`terraform/k8s-infra/`](terraform/k8s-infra/) | `oracle/oci` | Cible Oracle Cloud Always Free (4 vCPU ARM, 24 GB RAM). | `terraform plan` validé (authentification, réseau, droits OK). `terraform apply` retourne `Out of host capacity` : les **shapes gratuites des fournisseurs cloud sont en quantité très limitée** et fréquemment saturées — c'est le cas notamment du tier gratuit OCI ARM A1 en `eu-paris-1` au moment du rendu. La capacité gratuite n'est jamais garantie. Le code IaC reste correct : un compte payant ou une région avec stock disponible déploierait immédiatement. |
| **Local reproductible** — [`scripts/local-up.sh`](scripts/local-up.sh) | `kreuzwerker/docker` (Docker Compose) + **k3d** (cluster k3s in Docker) | Reproduit la même architecture (Traefik + 1 host Docker, cluster k3s 3 nœuds) sur la machine de l'auteur. | Validé bout en bout : login `admin/password` OK sur les 4 URLs. |

Les deux variantes utilisent exactement les mêmes :
- images Docker (mêmes Dockerfile)
- `docker-compose.yml` (Traefik + labels d'Ingress)
- manifests Kubernetes (kustomize prod + dev)
- script de génération des Secrets aléatoires

→ Avec un compte OCI disposant de capacité ARM, `terraform apply` sur les deux dossiers `terraform/*-infra/` provisionne l'infrastructure publique sans aucune modification du code applicatif ni des manifests.

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
│   ├── docker-compose.prod.yml    # Prod uniquement (test local rapide)
│   ├── .env.example
│   ├── traefik/dynamic.yml        # Routes Traefik (file provider)
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
│   ├── docker-infra/        # OCI : 1 VM ARM avec Docker + Traefik
│   └── k8s-infra/           # OCI : 3 VMs ARM avec k3s + Longhorn
├── kubernetes/
│   ├── prod/                # Manifests MySQL backend (kustomize)
│   └── dev/                 # Manifests PostgreSQL backend (kustomize)
└── scripts/
    ├── local-up.sh          # Déploiement local complet (Docker + k3d + K8s)
    ├── local-down.sh        # Nettoyage local
    ├── start-tunnels.sh     # Exposition publique via Cloudflare Quick Tunnels
    ├── gen-k8s-secrets.sh   # Génération de Secrets aléatoires
    ├── deploy-k8s.sh        # Apply des manifests K8s sur un cluster existant
    └── build-and-push-php.sh # Build + push de l'image PHP sur GHCR
```

---

## Modifications apportées à l'application

Le code source original contenait :
- des credentials hardcodés dans [`connect.php`](docker/php/www/connect.php) (host=`db`, user=`root`, password=`root`) ;
- un appel à `SHA2()` côté SQL dans [`auth.php`](docker/php/www/auth.php) — fonction spécifique à MySQL.

Adaptations pour le double déploiement MySQL / PostgreSQL :

| Fichier | Modification |
|---|---|
| `connect.php` | Lecture des credentials depuis des variables d'environnement (`DB_TYPE`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`). Le DSN PDO change selon `DB_TYPE` (`mysql` / `pgsql`). Une `PDOStatement` personnalisée remappe les noms de colonnes pour absorber la case-sensitivity PostgreSQL. |
| `auth.php` | Hash SHA-256 calculé en PHP (`hash('sha256', $password)`) au lieu de `SHA2()` côté SQL. Identique en MySQL et PostgreSQL. `display_errors` retiré pour éviter les fuites d'erreur en production. |

---

## Prérequis

- **Terraform** ≥ 1.5 (ou OpenTofu)
- **Docker Desktop**
- **kubectl** ≥ 1.28
- **k3d** ≥ 5.0 — `curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash`
- **cloudflared** (optionnel, pour exposition publique du déploiement local) — `winget install Cloudflare.cloudflared` (Windows) / `brew install cloudflared` (macOS)
- **SSH key** : `~/.ssh/id_ed25519` + `.pub` (pour la variante OCI)

---

## Comment tester l'application sans rien installer

Les 4 URLs publiques (tableau ci-dessous) sont accessibles depuis n'importe quel navigateur. Aucune installation requise.

1. Ouvrir l'URL souhaitée dans un navigateur (par exemple https://satisfaction-blessed-span-pens.trycloudflare.com pour la prod Docker)
2. Sur la page de login, saisir :
   - Utilisateur : `admin`
   - Mot de passe : `password`
3. La liste des 5 produits doit s'afficher
4. Cliquer sur un produit pour voir sa fiche, ajouter/modifier/supprimer si besoin

Les mêmes étapes fonctionnent à l'identique pour les 4 URLs (Docker prod, Docker dev, K8s prod, K8s dev).

---

## Comment déployer le projet localement (de zéro)

### Étape 1 — Installer les prérequis

| Outil | Commande d'installation |
|---|---|
| Docker Desktop | https://docs.docker.com/desktop/install/ |
| kubectl | `winget install Kubernetes.kubectl` (Windows) / `brew install kubectl` (macOS) / `sudo snap install kubectl --classic` (Linux) |
| k3d | `curl -L https://github.com/k3d-io/k3d/releases/latest/download/k3d-windows-amd64.exe -o k3d.exe` (Windows) ou `brew install k3d` (macOS) ou `curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh \| bash` (Linux) |
| cloudflared (optionnel — exposition publique) | `winget install Cloudflare.cloudflared` / `brew install cloudflared` / [Downloads](https://github.com/cloudflare/cloudflared/releases/latest) |

Vérifications :
```bash
docker --version
kubectl version --client
k3d version
```

### Étape 2 — Cloner le dépôt

```bash
git clone https://github.com/Zouitni-Yassine/IAC-Terraform-Automatisation.git
cd IAC-Terraform-Automatisation/tp
```

### Étape 3 — Lancer le déploiement complet

```bash
bash scripts/local-up.sh
```

Ce script enchaîne automatiquement :
1. `docker compose up -d --build` — construit les images PHP/MySQL/PostgreSQL et démarre le stack (Traefik + prod + dev)
2. `k3d cluster create tp-k8s --servers 1 --agents 2 --port "8081:80@loadbalancer"` — crée un cluster Kubernetes 3 nœuds
3. Récupère le `kubeconfig` et l'écrit dans `~/.kube/config-tp-k8s`
4. Importe l'image PHP locale dans le cluster k3d
5. Exécute `gen-k8s-secrets.sh` pour générer des mots de passe aléatoires
6. Applique les manifests `kubernetes/prod/` et `kubernetes/dev/` via kustomize

Durée : ~5 à 10 minutes selon la connexion (pull des images).

### Étape 4 — Vérifier que tout fonctionne

```bash
# Docker compose
docker compose -f docker/docker-compose.yml ps
# Attendu : 5 conteneurs Up (traefik, db-prod, db-dev, php-prod, php-dev)

# Kubernetes
export KUBECONFIG=~/.kube/config-tp-k8s
kubectl get pods -A
# Attendu : 3 nodes Ready, pods mysql/postgres/php Running dans gp-prod et gp-dev
```

### Étape 5 — Accéder aux URLs locales

Ajouter ces lignes au fichier `hosts` du poste :
- Windows : `C:\Windows\System32\drivers\etc\hosts` (en administrateur)
- macOS / Linux : `/etc/hosts` (avec sudo)

```
127.0.0.1 prod.gestion-produits.local dev.gestion-produits.local
127.0.0.1 prod-k8s.gestion-produits.local dev-k8s.gestion-produits.local
```

Puis ouvrir dans un navigateur :
- http://prod.gestion-produits.local/ — Docker prod (MySQL)
- http://dev.gestion-produits.local/ — Docker dev (PostgreSQL)
- http://prod-k8s.gestion-produits.local:8081/ — Kubernetes prod (MySQL)
- http://dev-k8s.gestion-produits.local:8081/ — Kubernetes dev (PostgreSQL)

Login : `admin` / `password`.

Alternative en ligne de commande (sans modifier le fichier hosts) :
```bash
curl -H 'Host: prod.gestion-produits.local'     http://localhost/
curl -H 'Host: dev.gestion-produits.local'      http://localhost/
curl -H 'Host: prod-k8s.gestion-produits.local' http://localhost:8081/
curl -H 'Host: dev-k8s.gestion-produits.local'  http://localhost:8081/
```

### Étape 6 (optionnelle) — Exposer publiquement via Cloudflare Tunnel

```bash
bash scripts/start-tunnels.sh
```

Le script lance 4 tunnels Cloudflare Quick (anonymes, gratuits, sans inscription) et affiche 4 URLs publiques `https://*.trycloudflare.com` — une par environnement, avec le bon `Host` header pré-configuré. Ces URLs restent valides tant que le terminal du script reste ouvert. `Ctrl+C` pour arrêter.

### Étape 7 — Nettoyer

```bash
bash scripts/local-down.sh
```

Supprime le cluster k3d et arrête/supprime le stack Docker.

---

## Déploiement cloud (OCI)

### Setup OCI

1. Créer un compte sur https://www.oracle.com/cloud/free/
2. Choisir le home region
3. Générer une clé API et la déclarer dans **My profile → API keys** :
   ```bash
   mkdir -p ~/.oci
   openssl genrsa -out ~/.oci/oci_api_key.pem 2048
   chmod 600 ~/.oci/oci_api_key.pem
   openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem
   ```
4. Récupérer les OCID Tenancy + User + le Fingerprint

### Infra Docker

```bash
cd tp/terraform/docker-infra
cp terraform.tfvars.example terraform.tfvars
# renseigner les OCID / fingerprint / chemin de clé
terraform init
terraform apply
```

Provisionne : VCN `10.10.0.0/16` + Internet Gateway + route + Security List (22, 80, 443) + subnet public + instance `VM.Standard.A1.Flex` Ubuntu 22.04 ARM. Le cloud-init installe Docker, clone le dépôt et lance `docker compose up -d`.

### Infra Kubernetes

```bash
cd tp/terraform/k8s-infra
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

Provisionne : VCN `10.20.0.0/16` + 1 instance k3s-server + 2 instances k3s-agent. Cloud-init installe k3s + Longhorn automatiquement. Le token de cluster est généré par `random_password` et partagé entre les nœuds via `templatefile`.

Récupération du kubeconfig :
```bash
ssh ubuntu@<IP_SERVER> sudo cat /etc/rancher/k3s/k3s.yaml \
  | sed "s|127.0.0.1|<IP_SERVER>|" > kubeconfig
export KUBECONFIG=$PWD/kubeconfig
```

Déploiement de l'application :
```bash
bash tp/scripts/build-and-push-php.sh    # publication de l'image PHP sur GHCR
bash tp/scripts/deploy-k8s.sh            # apply des manifests prod + dev
```

---

## Mise à jour de l'application

Le processus de mise à jour est automatisé :

```bash
# 1. Modification du code dans tp/docker/php/www/
# 2. Rebuild + push de l'image
bash tp/scripts/build-and-push-php.sh

# 3a. Rollout Docker (VM ou local)
cd tp/docker && docker compose up -d --build

# 3b. Rollout Kubernetes (zero-downtime grâce aux replicas + readinessProbe)
kubectl -n gp-prod rollout restart deployment/php
kubectl -n gp-dev  rollout restart deployment/php
```

La version dev (PostgreSQL) est déployée à côté de la prod (MySQL). Le passage de l'une à l'autre se fait par une simple variable d'environnement `DB_TYPE` (mysql / pgsql) lue par `connect.php`.

---

## URLs

| Environnement | Infra | URL locale (hosts file) | URL publique |
|---|---|---|---|
| Prod (MySQL) | Docker | http://prod.gestion-produits.local/ | https://satisfaction-blessed-span-pens.trycloudflare.com |
| Dev (PostgreSQL) | Docker | http://dev.gestion-produits.local/ | https://indicators-falls-ticket-magnet.trycloudflare.com |
| Prod (MySQL) | Kubernetes | http://prod-k8s.gestion-produits.local:8081/ | https://honor-railway-burlington-facilitate.trycloudflare.com |
| Dev (PostgreSQL) | Kubernetes | http://dev-k8s.gestion-produits.local:8081/ | https://conclude-lesson-enhancement-fog.trycloudflare.com |

Credentials de l'application : `admin` / `password`

> Les URLs publiques sont fournies par des Cloudflare Quick Tunnels (anonymes, gratuits). Elles sont valides tant que le tunnel correspondant tourne. Pour les régénérer : `bash scripts/start-tunnels.sh`.

---

## Points notables

| Aspect | Implémentation |
|---|---|
| Ports par défaut (80/443) | Les URLs publiques sont en `https://...trycloudflare.com` → port 443 standard. Côté local, le stack Docker écoute sur :80 et le cluster k3d sur :8081 (le port :80 ne peut être bind qu'une fois sur le même host). |
| Stockage partagé K8s | **Cloud OCI** : Longhorn v1.7.2 installé via cloud-init sur le k3s-server. **Local k3d** : `local-path` — les 3 nœuds k3d étant des conteneurs sur le même host Docker, le filesystem est partagé de fait. Le `local-up.sh` substitue `storageClassName: longhorn` → `local-path` à l'apply. |
| Replicas PHP K8s | Manifest = `replicas: 2`. Scaled à 1 pour la démonstration (sessions PHP locales au pod, pas de backend Redis). Une stack production-ready inclurait un Redis pour le partage de session. |
| Conteneurisation multi-environnement | Image PHP unique déployée quatre fois avec des variables d'environnement différentes — même artefact en prod et en dev, sur Docker et sur Kubernetes. |
| Automatisation | Quatre scripts shell pilotent l'ensemble : `local-up.sh`, `start-tunnels.sh`, `gen-k8s-secrets.sh`, `local-down.sh`. Pour le cloud : `terraform apply` une fois par dossier. |

---

## Limitations connues (code upstream)

Le code source de `gestion-produits` contient des vulnérabilités héritées non corrigées car hors du périmètre du TP (qui porte sur l'IaC et la conteneurisation) :

- `validation.php` n'invoque pas `secu()` → ajout/suppression de produits accessibles sans session (Broken Access Control)
- Upload de fichiers sans validation MIME/extension stricte (Arbitrary File Upload → RCE potentielle)
- Sortie HTML sans `htmlspecialchars()` autour des valeurs base de données (XSS stocké/reflété)
- Hash de mot de passe SHA-256 simple au lieu de `password_hash()` bcrypt/argon2id

Corrections appliquées côté infrastructure et conteneurisation :

- Traefik dashboard (port 8080) bindé sur `127.0.0.1` uniquement — accès via tunnel SSH `ssh -L 8080:localhost:8080 ubuntu@<IP>`
- `ini_set('display_errors', '1')` retiré de `auth.php` (pas de stack trace en production)
- Secrets Kubernetes générés à la volée par `scripts/gen-k8s-secrets.sh` (`openssl rand -base64 32`) plutôt que versionnés en clair

---

## Couverture des exigences du sujet

| Exigence | Implémentation | Référence |
|---|---|---|
| Conteneurisation de l'application pour Docker | Image PHP custom (php:8.3-apache + pdo_mysql + pdo_pgsql), images MySQL et PostgreSQL avec init data, `docker-compose.yml` complet | [`docker/`](docker/) |
| Déploiement infrastructure avec Terraform | Code Terraform complet pour les deux infras (provider OCI ARM Always Free) | [`terraform/docker-infra/`](terraform/docker-infra/), [`terraform/k8s-infra/`](terraform/k8s-infra/) |
| Infrastructure Docker avec reverse proxy frontal | Traefik v3.1 en frontal avec file provider, routes vers prod et dev | [`docker/docker-compose.yml`](docker/docker-compose.yml), [`docker/traefik/dynamic.yml`](docker/traefik/dynamic.yml) |
| Cluster Kubernetes 3 nœuds | k3s 1 server + 2 agents (Terraform OCI) / k3d 1 server + 2 agents (local) | [`terraform/k8s-infra/main.tf`](terraform/k8s-infra/main.tf), [`scripts/local-up.sh`](scripts/local-up.sh) |
| Stockage partagé K8s | Longhorn v1.7.2 installé via cloud-init sur OCI ; local-path sur k3d (single-host) | [`terraform/k8s-infra/cloud-init/k3s-server.yaml`](terraform/k8s-infra/cloud-init/k3s-server.yaml) |
| Déploiement de l'application sur Docker (prod) | Stack Docker Compose Traefik + PHP + MySQL avec healthchecks, volumes persistants | [`docker/docker-compose.yml`](docker/docker-compose.yml) |
| Déploiement de l'application sur Kubernetes | Manifests Deployment + Service + Ingress + Secret + PVC pour prod et dev, gérés par kustomize | [`kubernetes/`](kubernetes/) |
| Accès via URLs sur ports HTTP/HTTPS par défaut | Les URLs publiques sont en `https://*.trycloudflare.com` → port 443 standard | Tableau URLs ci-dessus |
| Résolution de nom locale | Documentée (entrées `hosts` ou DNS local) | Section "Déploiement local" |
| Mise à jour de l'application (version dev PostgreSQL) | Schéma SQL converti, Dockerfile PostgreSQL, manifests K8s dev, URL `dev.*` et `dev-k8s.*` distinctes, process de rollout documenté | [`docker/postgres/`](docker/postgres/), [`kubernetes/dev/`](kubernetes/dev/) |
| Automatisation maximale | Scripts shell + Terraform : 1 commande déploie tout (`local-up.sh` ou `terraform apply`) | [`scripts/`](scripts/) |
| Dépôt git avec descriptif Markdown + instructions | Ce dépôt avec ce README + CHECKLIST détaillée | [`README.md`](README.md), [`CHECKLIST.md`](CHECKLIST.md) |

---

## Auteur

Yassine Zouitni — yassine.zouitni@linctra.com
Dépôt : https://github.com/Zouitni-Yassine/IAC-Terraform-Automatisation
