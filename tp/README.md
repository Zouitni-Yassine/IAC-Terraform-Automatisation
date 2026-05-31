# TP noté – IaC Terraform + Conteneurisation avancée

**Auteur** : Yassine Zouitni — M1 DEV EPSI
**Module** : IaC – Terraform / Conteneurisation avancée
**Date** : mai 2026
**Application déployée** : [gestion-produits](https://gl.avalone-fr.com/anthony/gestion-produits) (PHP + MySQL/MariaDB → PostgreSQL pour la version dev)

---

## Objectif

Déployer l'application `gestion-produits` (PHP + base de données) sur deux infrastructures distinctes, **toutes les deux provisionnées par Terraform** :

1. **Infra Docker** — 1 VM avec Traefik en reverse proxy frontal
2. **Infra Kubernetes (k3s)** — cluster 3 nœuds avec Longhorn pour le stockage partagé

Et une **version dev** utilisant PostgreSQL (au lieu de MySQL) déployée sur les deux infras.

L'infrastructure cible est **Oracle Cloud Infrastructure (OCI) Always Free Tier** (4 vCPU ARM Ampere A1, 24 GB RAM, 200 GB stockage — gratuit à vie).

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
   │  INFRA DOCKER (1 VM ARM) │         │  INFRA KUBERNETES (3 VMs ARM)  │
   │  ──────────────────────  │         │  ─────────────────────────     │
   │  Ubuntu 22.04            │         │  k3s v1.30.5                   │
   │  Docker + Compose        │         │  + Traefik Ingress             │
   │                          │         │  + Longhorn (storage)          │
   │  ┌──────┐                │         │                                │
   │  │Traefik│ :80           │         │  ┌─ namespace gp-prod ─┐       │
   │  └──┬───┘                │         │  │ Deployment php × 2 │       │
   │     ├──→ php-prod ──→ mysql        │  │ Deployment mysql   │       │
   │     │   (prod.*)         │         │  │ PVC longhorn 5Gi   │       │
   │     └──→ php-dev  ──→ postgres     │  │ Ingress prod-k8s.* │       │
   │         (dev.*)          │         │  └────────────────────┘       │
   │                          │         │                                │
   │                          │         │  ┌─ namespace gp-dev ─┐        │
   │                          │         │  │ Deployment php × 2 │       │
   │                          │         │  │ Deployment postgres│       │
   │                          │         │  │ PVC longhorn 5Gi   │       │
   │                          │         │  │ Ingress dev-k8s.*  │       │
   │                          │         │  └────────────────────┘       │
   └──────────────────────────┘         └────────────────────────────────┘
```

---

## Structure du dépôt

```
tp/
├── README.md                # Ce fichier
├── CHECKLIST.md             # Suivi des tâches
├── src-app/                 # Clone du dépôt original gestion-produits (read-only ref)
├── docker/                  # Conteneurisation
│   ├── docker-compose.yml         # Stack complète prod + dev (avec Traefik)
│   ├── docker-compose.prod.yml    # Juste prod, pour test local
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
│   ├── docker-infra/        # 1 VM OCI ARM avec Docker
│   │   ├── provider.tf
│   │   ├── main.tf          # VCN, IGW, route, security list, instance
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars.example
│   │   └── cloud-init/docker-vm.yaml
│   └── k8s-infra/           # 3 VMs OCI ARM avec k3s
│       ├── provider.tf
│       ├── main.tf          # VCN, security list, 1 server + N agents
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars.example
│       └── cloud-init/
│           ├── k3s-server.yaml   # cloud-init server (k3s + Longhorn)
│           └── k3s-agent.yaml    # cloud-init agents
├── kubernetes/
│   ├── prod/                # MySQL backend
│   │   ├── namespace.yaml
│   │   ├── secret.yaml
│   │   ├── mysql-pvc.yaml
│   │   ├── mysql-deployment.yaml
│   │   ├── php-deployment.yaml
│   │   ├── ingress.yaml
│   │   └── kustomization.yaml
│   └── dev/                 # PostgreSQL backend
│       ├── namespace.yaml
│       ├── secret.yaml
│       ├── postgres-pvc.yaml
│       ├── postgres-deployment.yaml
│       ├── php-deployment.yaml
│       ├── ingress.yaml
│       └── kustomization.yaml
└── scripts/
    ├── build-and-push-php.sh    # Build + push de l'image PHP sur GHCR (multi-arch)
    └── deploy-k8s.sh            # Apply prod + dev sur le cluster
```

---

## Modifications apportées à l'application

Le code original utilisait :
- **Credentials hardcodés** dans [`connect.php`](docker/php/www/connect.php) (host=`db`, user=`root`, password=`root`)
- **`SHA2()`** côté SQL pour le hash du mot de passe dans [`auth.php`](docker/php/www/auth.php) — fonction spécifique à MySQL

Pour permettre le déploiement avec MySQL **et** PostgreSQL :

| Fichier | Modification |
|---|---|
| `connect.php` | Lecture des credentials depuis variables d'env (`DB_TYPE`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`). Le type de DSN PDO change selon `DB_TYPE` (mysql ou pgsql). |
| `auth.php` | Hash SHA-256 calculé **en PHP** (`hash('sha256', $password)`) au lieu de `SHA2()` côté SQL. Identique en MySQL et PostgreSQL. |

---

## Prérequis

- **Terraform** ≥ 1.5 (ou OpenTofu)
- **Docker Desktop** sur le poste (pour build + test local + push images)
- **kubectl** ≥ 1.28
- **Compte Oracle Cloud Free Tier** : https://www.oracle.com/cloud/free/
- **Compte GitHub** avec un Personal Access Token (write:packages) pour push sur GHCR
- **SSH key** : `~/.ssh/id_ed25519` + `.pub`

---

## 1. Conteneurisation de l'application

### Test local (sans Terraform)

```bash
cd tp/docker
cp .env.example .env
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml ps
```

Pour tester l'app :
```bash
docker exec docker-php-1 curl -s -c /tmp/c -X POST \
  -d "US_login=admin&US_password=password" http://localhost/auth.php -L
docker exec docker-php-1 curl -s -b /tmp/c http://localhost/home.php | grep '<td>'
```

✅ Résultat attendu : login HTTP 302 → home.php affiche les 5 produits.

### Build + push des images custom (GHCR)

```bash
export GHCR_USER=zouitni-yassine
export GHCR_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxx  # PAT avec write:packages
bash tp/scripts/build-and-push-php.sh
```

Puis sur https://github.com/zouitni-yassine?tab=packages → **gestion-produits-php** → Package settings → **Change visibility → Public** (sinon K8s ne peut pas pull).

---

## 2. Setup Oracle Cloud (compte + API key)

### 2.1 Création du compte

1. https://www.oracle.com/cloud/free/ → Start for free
2. Email + CB (vérification uniquement, **aucun débit**)
3. **Home region** : `eu-frankfurt-1` (recommandé en Europe)
4. Attendre l'email d'activation (5-30 min)

### 2.2 Génération de la clé API

Dans la console OCI, en haut à droite **profil → My profile → API keys → Add API key** :

```bash
# Générer une paire de clés localement
mkdir -p ~/.oci
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
chmod 600 ~/.oci/oci_api_key.pem
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem
```

Coller le contenu de `oci_api_key_public.pem` dans la console OCI → on récupère le **fingerprint**.

### 2.3 Collecter les OCID

Console OCI → profil → **Tenancy** → OCID
Console OCI → profil → **User Settings** → OCID

---

## 3. Déploiement de l'infra Docker (Terraform OCI) — 7 pts

```bash
cd tp/terraform/docker-infra
cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars avec tes OCID / fingerprint / chemin de clé
terraform init
terraform plan
terraform apply
```

Terraform crée :
- Un **VCN** `10.10.0.0/16`
- Un **Internet Gateway** + route table publique
- Une **Security List** ouvrant 22, 80, 443, 8080 depuis Internet
- Un **subnet public** `10.10.1.0/24`
- Une **instance ARM Ampere A1 Flex** (1 OCPU, 6 GB RAM, 50 GB disque) avec Ubuntu 22.04
- Un **cloud-init** qui installe Docker, clone ce dépôt, génère un `.env` aléatoire et lance `docker compose up -d`

### Outputs

```
docker_vm_public_ip  = "X.X.X.X"
ssh_command          = "ssh ubuntu@X.X.X.X"
traefik_dashboard    = "http://X.X.X.X:8080"
hosts_entries        = "X.X.X.X prod.gestion-produits.local dev.gestion-produits.local"
```

### Vérification

```bash
# Ajouter à C:\Windows\System32\drivers\etc\hosts (en admin)
# OU /etc/hosts (Linux/Mac)
X.X.X.X prod.gestion-produits.local dev.gestion-produits.local

# Tester
curl -I http://prod.gestion-produits.local/
curl -I http://dev.gestion-produits.local/
```

Ouvrir dans le navigateur :
- http://prod.gestion-produits.local → login `admin / password` → liste des produits (MySQL)
- http://dev.gestion-produits.local → login `admin / password` → mêmes produits (PostgreSQL)
- http://X.X.X.X:8080 → dashboard Traefik

---

## 4. Déploiement de l'infra Kubernetes (Terraform OCI) — 13 pts

```bash
cd tp/terraform/k8s-infra
cp terraform.tfvars.example terraform.tfvars
# Mêmes OCID/credentials que pour docker-infra
terraform init
terraform plan
terraform apply
```

Terraform crée :
- Un **VCN** `10.20.0.0/16` + IGW + route + security list (22, 80, 443, 6443, trafic interne libre)
- **1 instance k3s-server** (1 OCPU, 6 GB RAM) avec cloud-init qui installe k3s server + Longhorn
- **2 instances k3s-agent** (1 OCPU, 6 GB RAM chacune) qui rejoignent le cluster avec le même token (généré par `random_password`)

### Récupération du kubeconfig

```bash
# La commande exacte est dans l'output Terraform
ssh ubuntu@<IP_SERVER> sudo cat /etc/rancher/k3s/k3s.yaml \
  | sed "s|127.0.0.1|<IP_SERVER>|" > kubeconfig
export KUBECONFIG=$PWD/kubeconfig

kubectl get nodes
# Attendu : 3 nodes Ready (server + 2 agents)

kubectl get pods -n longhorn-system
# Attendu : pods longhorn-manager, csi-*, instance-manager-* Running

kubectl get storageclass
# Attendu : longhorn (default)
```

---

## 5. Déploiement de l'app sur Kubernetes — 7 pts (prod) + 4 pts (dev)

```bash
# (Si pas déjà fait) push de l'image PHP sur GHCR
bash tp/scripts/build-and-push-php.sh

# Apply prod + dev
bash tp/scripts/deploy-k8s.sh
```

Le script utilise `kustomize` (intégré à kubectl) pour générer les ConfigMaps des init SQL à partir des fichiers locaux, puis applique :

**Namespace `gp-prod`** :
- Secret `gp-prod-db` (MYSQL_* env vars)
- PVC `mysql-data` (5 Gi Longhorn)
- Deployment `mysql` (1 replica, strategy Recreate)
- Deployment `php` (2 replicas, image PHP custom)
- PVC `php-uploads` (2 Gi Longhorn)
- Service `mysql` + `php` (ClusterIP)
- Ingress `gp-prod` → host `prod-k8s.gestion-produits.local`

**Namespace `gp-dev`** :
- Mêmes ressources avec PostgreSQL + Ingress sur `dev-k8s.gestion-produits.local`

### Accès via le navigateur

Récupérer l'IP publique du **k3s-server** (qui sert le Traefik Ingress) :
```bash
terraform -chdir=tp/terraform/k8s-infra output k3s_server_public_ip
```

Ajouter à `hosts` :
```
<IP_SERVER> prod-k8s.gestion-produits.local dev-k8s.gestion-produits.local
```

Tester :
- http://prod-k8s.gestion-produits.local → app sur MySQL
- http://dev-k8s.gestion-produits.local → app sur PostgreSQL

---

## 6. Mise à jour de l'application

Le processus de MàJ est automatisé :

```bash
# 1. Modifier le code dans tp/docker/php/www/
# 2. Rebuild + push de l'image
bash tp/scripts/build-and-push-php.sh

# 3a. Rollout sur Docker (depuis la VM Docker, via SSH)
ssh ubuntu@<IP_DOCKER_VM> "cd /opt/app/Terraform/tp/docker && git pull && docker compose pull && docker compose up -d"

# 3b. Rollout sur Kubernetes
kubectl -n gp-prod rollout restart deployment/php
kubectl -n gp-dev  rollout restart deployment/php
```

Avec K8s, le rollout est **zero-downtime** grâce aux 2 replicas et au `readinessProbe` qui attend que le pod soit OK avant de basculer le trafic.

---

## URLs finales

| Environnement | Infra | URL |
|---|---|---|
| Prod (MySQL) | Docker | http://prod.gestion-produits.local |
| Dev (PostgreSQL) | Docker | http://dev.gestion-produits.local |
| Prod (MySQL) | Kubernetes | http://prod-k8s.gestion-produits.local |
| Dev (PostgreSQL) | Kubernetes | http://dev-k8s.gestion-produits.local |

**Credentials de l'app** : `admin` / `password`

---

## Tests

| Test | Statut |
|---|---|
| Build des images Docker | ✅ |
| Lancement local du stack prod (MySQL) | ✅ — login admin/password OK, 5 produits visibles |
| Validation docker-compose.yml (Traefik + prod + dev) | ✅ |
| Validation des manifests K8s (kustomize build) | ⏳ déploiement en cours |
| Déploiement Terraform Docker sur OCI | ⏳ en attente du compte OCI |
| Déploiement Terraform K8s sur OCI | ⏳ en attente du compte OCI |

---

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
Dépôt : https://github.com/Zouitni-Yassine/Terraform
