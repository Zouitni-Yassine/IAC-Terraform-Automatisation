# TP noté – IaC Terraform + Conteneurisation avancée

> **Auteur** : Yassine Zouitni
> **Module** : M1 DEV
> **Deadline** : dimanche 31 mai 2026 à minuit
> **Livrable** : dépôt git à envoyer à anthony@avalone-fr.com
> **App à déployer** : https://gl.avalone-fr.com/anthony/gestion-produits (PHP + MySQL/MariaDB → PostgreSQL pour dev)

---

## Décisions prises

- [x] **Infra cible** : Oracle Cloud Infrastructure Always Free Tier (4 ARM Ampere A1, 24 GB RAM, 200 GB)
  - *Choix initial Proxmox abandonné — cluster `pve.avalone-fr.com` injoignable le jour du rendu (502 Bad Gateway), proxmox-form refuse l'auth.*
- [x] **Reverse proxy** : Traefik v3.1 (intégration Docker labels + Ingress k3s natif)
- [x] **Distribution Kubernetes** : k3s v1.30.5 (server + 2 agents)
- [x] **Stockage partagé K8s** : Longhorn v1.7.2
- [x] **Résolution de nom locale** : entrées `hosts` (Windows/Linux)
  - `prod.gestion-produits.local` → IP VM Docker
  - `dev.gestion-produits.local` → IP VM Docker
  - `prod-k8s.gestion-produits.local` → IP k3s-server (Ingress)
  - `dev-k8s.gestion-produits.local` → IP k3s-server (Ingress)

---

## 1. Conteneurisation de l'application (3 pts)

- [x] Cloner le repo `gestion-produits` → `tp/src-app/`
- [x] Analyser la structure (PHP PDO MySQL, dump SQL, hash SHA2)
- [x] Modifier `connect.php` pour utiliser variables d'env (DB_TYPE/HOST/PORT/USER/PASSWORD/NAME)
- [x] Modifier `auth.php` pour hasher en PHP (compat MySQL + PostgreSQL)
- [x] Écrire `Dockerfile` PHP (php:8.3-apache + PDO mysql/pgsql)
- [x] Écrire `Dockerfile` MySQL (mysql:8.4 + dump SQL en init)
- [x] Écrire `Dockerfile` PostgreSQL (postgres:16-alpine + SQL converti)
- [x] Écrire `docker-compose.prod.yml` (test local, juste prod)
- [x] Écrire `docker-compose.yml` (Traefik + prod + dev, déploiement complet)
- [x] Tester localement : `docker compose up` → login admin/password OK, 5 produits affichés
- [x] Script `build-and-push-php.sh` pour pousser l'image multi-arch (amd64 + arm64) sur GHCR

## 2. Infra Docker (Terraform OCI) — 7 pts

- [x] `provider.tf` (oracle/oci ~> 6.0)
- [x] `variables.tf` (tenancy/user/fingerprint/key/region/compartment/ssh_key)
- [x] `main.tf` :
  - [x] VCN `10.10.0.0/16` + DNS label
  - [x] Internet Gateway + route table publique
  - [x] Security list (ingress 22, 80, 443, 8080)
  - [x] Subnet public `10.10.1.0/24`
  - [x] Instance `VM.Standard.A1.Flex` (1 OCPU, 6 GB RAM, 50 GB) Ubuntu 22.04 ARM
- [x] `cloud-init/docker-vm.yaml` :
  - [x] Install Docker via get.docker.com
  - [x] UFW (22, 80, 443, 8080)
  - [x] Clone du repo Github
  - [x] Génération `.env` aléatoire (openssl rand)
  - [x] `docker compose up -d` du stack complet (Traefik + prod + dev)
- [x] `outputs.tf` (public_ip, ssh_command, traefik_dashboard, hosts_entries)
- [ ] `terraform apply` réussi → en attente du compte OCI utilisateur

## 3. Infra Kubernetes (Terraform OCI) — 13 pts

- [x] `provider.tf` (oci + random)
- [x] `variables.tf` (mêmes + agent_count)
- [x] `main.tf` :
  - [x] VCN `10.20.0.0/16` + DNS label
  - [x] Internet Gateway + route table publique
  - [x] Security list (22, 80, 443, 6443, trafic interne `10.20.0.0/16`)
  - [x] Subnet public `10.20.1.0/24`
  - [x] `random_password.k3s_token` (48 chars, partagé server+agents)
  - [x] 1 instance `k3s-server` (1 OCPU, 6 GB, Ubuntu ARM)
  - [x] N instances `k3s-agents` (count = var.agent_count, default 2)
  - [x] Dépendance explicite agents → server (pour l'IP)
- [x] `cloud-init/k3s-server.yaml` :
  - [x] Install k3s server avec token + tls-san (IP publique)
  - [x] Prérequis Longhorn (open-iscsi, nfs-common)
  - [x] kubeconfig copié dans `/home/ubuntu/.kube/config`
  - [x] Apply Longhorn v1.7.2 (auto, après que le nœud soit Ready)
- [x] `cloud-init/k3s-agent.yaml` :
  - [x] Install k3s agent avec K3S_URL + K3S_TOKEN
  - [x] Attente que l'API server soit reachable avant install
- [x] `outputs.tf` (server_public_ip, kubeconfig_fetch_command, hosts_entries)
- [ ] `terraform apply` réussi → en attente du compte OCI utilisateur
- [ ] `kubectl get nodes` montre 3 Ready
- [ ] `kubectl get storageclass` montre `longhorn`

## 4. Déploiement de l'app sur Docker (prod + dev) — 6 pts

- [x] `docker-compose.yml` avec Traefik + 4 services (php-prod, db-prod MySQL, php-dev, db-dev PostgreSQL)
- [x] Labels Traefik routent `prod.gestion-produits.local` → php-prod, `dev.gestion-produits.local` → php-dev
- [x] PVC equivalent : volumes nommés Docker pour persistance MySQL/PostgreSQL/uploads
- [x] Healthchecks (mysqladmin ping, pg_isready) → PHP attend que la BDD soit ready (`depends_on.condition: service_healthy`)
- [x] `.env.example` versionné, `.env` généré aléatoirement par cloud-init
- [ ] Déploiement effectif via Terraform apply → en attente OCI

## 5. Déploiement de l'app sur Kubernetes (prod) — 7 pts

- [x] `kubernetes/prod/namespace.yaml` (gp-prod)
- [x] `kubernetes/prod/secret.yaml` (MYSQL_* creds, type Opaque, stringData)
- [x] `kubernetes/prod/mysql-pvc.yaml` (5 Gi, storageClassName longhorn)
- [x] `kubernetes/prod/mysql-deployment.yaml` (mysql:8.4 + Service ClusterIP + readinessProbe)
- [x] `kubernetes/prod/php-deployment.yaml` (PHP custom image GHCR, 2 replicas, PVC uploads, envFrom secret + DB_HOST = mysql.gp-prod.svc, readinessProbe HTTP)
- [x] `kubernetes/prod/ingress.yaml` (ingressClassName traefik, host prod-k8s.gestion-produits.local)
- [x] `kubernetes/prod/kustomization.yaml` (configMapGenerator pour SQL init depuis docker/mysql/init/)
- [ ] `kubectl apply -k tp/kubernetes/prod` réussi
- [ ] Accès navigateur OK

## 6. Mise à jour de l'app (version dev avec PostgreSQL) — 4 pts

- [x] Conversion du dump MySQL → PostgreSQL : `tp/docker/postgres/init/01-gestion_produits.sql`
  - SERIAL au lieu de AUTO_INCREMENT, suppression ENGINE/CHARSET MySQL, FK CASCADE, setval sur sequences
- [x] `Dockerfile` PostgreSQL (postgres:16-alpine + init script)
- [x] Service `db-dev` dans docker-compose.yml
- [x] Service `php-dev` (même image PHP, juste `DB_TYPE=pgsql`, `DB_HOST=db-dev`)
- [x] Manifests K8s `kubernetes/dev/` (namespace gp-dev, secret POSTGRES_*, PVC, Deployment, Service, Ingress dev-k8s.*)
- [x] `kubernetes/dev/kustomization.yaml`
- [x] Process de MàJ documenté : `git pull` + `docker compose up -d` (Docker) ou `kubectl rollout restart` (K8s)
- [ ] Déploiement effectif → en attente OCI

## 7. Livrables

- [x] Dépôt git propre avec terraform/, docker/, kubernetes/, scripts/
- [x] `README.md` racine complet (architecture, instructions, URLs)
- [x] `CHECKLIST.md` (ce fichier) montrant l'avancement
- [ ] Push final sur GitHub
- [ ] Envoi du dépôt à **anthony@avalone-fr.com**

---

## Critères d'évaluation (rappel barème)

| Partie | Critère | Points | Statut code |
|---|---|---|---|
| **IaC – Terraform (20 pts)** | Déploiement infra Docker | 7 | ✅ code prêt |
|  | Déploiement infra Kubernetes | 13 | ✅ code prêt |
| **Conteneurisation (20 pts)** | Conteneurisation de l'application | 3 | ✅ testé localement |
|  | Déploiement Docker en prod | 6 | ✅ compose prêt |
|  | Déploiement Kubernetes | 7 | ✅ manifests prêts |
|  | Mise à jour de l'application | 4 | ✅ version dev PostgreSQL prête |
