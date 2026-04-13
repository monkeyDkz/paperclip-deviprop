# 🚀 Prochaines étapes - Installation sur serveur

Votre repo GitHub est prêt : **https://github.com/monkeyDkz/paperclip-deviprop**

## ✅ Ce qui a été fait

- ✅ Repo GitHub créé et configuré
- ✅ Tous les fichiers poussés
- ✅ Tag v1.0.0 créé
- ✅ URLs du repo mises à jour dans les scripts
- ✅ Documentation complète ajoutée

## 📋 Installation sur le serveur

### Méthode 1 : Installation automatique (Recommandée)

```bash
# 1. Se connecter au serveur
ssh -p 55184 admin1@192.168.94.96

# 2. Créer le dossier d'installation
sudo mkdir -p /opt/paperclip-stack
sudo chown admin1:admin1 /opt/paperclip-stack
cd /opt/paperclip-stack

# 3. Télécharger et lancer l'installateur
curl -sSL https://raw.githubusercontent.com/monkeyDkz/paperclip-deviprop/main/install-on-server.sh | bash

# Ou si vous préférez inspecter le script d'abord:
curl -o install.sh https://raw.githubusercontent.com/monkeyDkz/paperclip-deviprop/main/install-on-server.sh
chmod +x install.sh
./install.sh
```

L'installateur va:
1. ✅ Vérifier les prérequis (Docker, Git, Curl)
2. ✅ Cloner le repo GitHub
3. ✅ Vous demander de configurer `.env`
4. ✅ Démarrer tous les services Docker
5. ✅ Bootstrap Paperclip
6. ✅ Injecter les 16 agents

### Méthode 2 : Installation manuelle

```bash
# 1. SSH au serveur
ssh -p 55184 admin1@192.168.94.96

# 2. Cloner le repo
cd /opt
sudo mkdir -p paperclip-stack
sudo chown admin1:admin1 paperclip-stack
cd paperclip-stack
git clone https://github.com/monkeyDkz/paperclip-deviprop.git .

# 3. Configurer .env
cp .env.example .env
nano .env
# Remplir TOUS les secrets (voir ci-dessous)

# 4. Démarrer les services
docker compose -f docker/docker-compose.yml up -d

# 5. Attendre que tout démarre (2-3 min)
watch docker compose -f docker/docker-compose.yml ps

# 6. Bootstrap Paperclip
chmod +x scripts/*.sh
./scripts/bootstrap-paperclip.sh

# 7. Injecter les agents
./scripts/inject-agents.sh
```

## 🔐 Configuration .env OBLIGATOIRE

Avant de démarrer, remplir `.env` avec ces valeurs:

```bash
# PostgreSQL
POSTGRES_ADMIN_USER=admin
POSTGRES_ADMIN_PASSWORD=$(openssl rand -hex 32)

# Redis
REDIS_PASSWORD=$(openssl rand -hex 32)

# Gitea (utiliser votre Gitea existant)
GITEA_SECRET_KEY=<récupérer depuis votre Gitea existant>
GITEA_INTERNAL_TOKEN=<récupérer depuis votre Gitea existant>
GITEA_API_TOKEN=<créer dans Gitea UI > Settings > Applications > Generate New Token>

# Paperclip
PAPERCLIP_ADMIN_EMAIL=admin@deviprop.com
PAPERCLIP_ADMIN_PASSWORD=<choisir un mot de passe fort>
PAPERCLIP_AUTH_SECRET=$(openssl rand -hex 32)
PAPERCLIP_AGENT_JWT_SECRET=$(openssl rand -hex 32)

# Dokploy (NOUVEAU - important pour les previews)
DOKPLOY_API_URL=https://dokploy.deviprop.com  # Votre URL Dokploy
DOKPLOY_API_TOKEN=<générer dans Dokploy UI > Settings > API Tokens>
DOKPLOY_WEBHOOK_URL=https://webhook.deviprop.com
DOKPLOY_DOMAIN=deviprop.com  # Votre domaine

# Claude API
ANTHROPIC_API_KEY=sk-ant-...  # Votre clé API Anthropic
```

**IMPORTANT:** Sauvegarder ces secrets dans un gestionnaire de mots de passe !

## 🔧 Configurer Dokploy

### 1. Générer le token API

1. Ouvrir `https://dokploy.deviprop.com` (ou votre URL Dokploy)
2. Settings > API Tokens
3. Create New Token
4. Copier le token
5. Ajouter dans `.env`: `DOKPLOY_API_TOKEN=votre_token`

### 2. Tester le webhook preview

```bash
cd /opt/paperclip-stack

# Tester le script manuellement
export DOKPLOY_API_URL="https://dokploy.deviprop.com"
export DOKPLOY_API_TOKEN="votre_token"
export DOKPLOY_DOMAIN="deviprop.com"

./scripts/dokploy-preview-webhook.sh test-repo feature/test-branch 1

# Devrait retourner:
# {"preview_url": "https://pr-1-test-repo.deviprop.com", "service_id": "...", ...}
```

## 🌐 Accéder à Paperclip UI

### Option 1: Tunnel SSH (depuis votre machine Windows)

```bash
# Depuis Windows
cd C:\Users\kays\Desktop\paperclip\Stack-paperclip
./connect-server.sh tunnel

# Ou manuellement:
ssh -p 55184 -L 3100:localhost:3100 admin1@192.168.94.96

# Puis ouvrir dans le navigateur:
http://localhost:3100
```

### Option 2: Reverse Proxy (recommandé pour production)

Configurer nginx/Caddy sur le serveur pour exposer Paperclip:

```nginx
# nginx
server {
    listen 80;
    server_name paperclip.deviprop.com;

    location / {
        proxy_pass http://localhost:3100;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 🧪 Tester le workflow complet

```bash
# 1. Se connecter avec tunnel
./connect-server.sh tunnel

# 2. Ouvrir Paperclip UI
# http://localhost:3100

# 3. Créer un projet test
# Projects > Create Project
# - Name: "Test Preview Workflow"
# - Repository: créer un repo vide dans Gitea

# 4. Créer une mission pour le CEO
# Issues > Create Issue
# - Title: "Test: Créer page about"
# - Description: "Créer une page About basique pour tester le workflow"
# - Assignee: CEO

# 5. Wake le CEO
ssh -p 55184 admin1@192.168.94.96
cd /opt/paperclip-stack
./scripts/agent-control.sh wake ceo

# 6. Suivre les logs
./scripts/agent-control.sh status ceo
docker logs -f paperclip

# 7. Vérifier le workflow
# - CEO crée sous-tâches
# - Lead Frontend code + crée PR
# - DevOps déploie preview
# - Preview URL commentée sur PR
# - CTO review + approve (SANS merger)
# - Vous mergez manuellement sur Gitea
```

## 🔍 Commandes utiles

```bash
# Connexion SSH rapide
./connect-server.sh

# Tunnel Paperclip UI
./connect-server.sh tunnel

# Voir les logs en temps réel
./connect-server.sh logs

# Vérifier status des services
./connect-server.sh status

# Redémarrer les services
./connect-server.sh restart

# Arrêter les services
./connect-server.sh stop

# Démarrer les services
./connect-server.sh start

# Mettre à jour depuis GitHub
./connect-server.sh update
```

## 📊 Vérifier que tout fonctionne

```bash
# Sur le serveur
cd /opt/paperclip-stack

# PostgreSQL
docker exec postgres pg_isready -U admin

# Redis
docker exec redis redis-cli -a "$REDIS_PASSWORD" ping

# Mem0
curl http://localhost:8050/health

# Chroma
curl http://localhost:8000/api/v1/heartbeat

# Paperclip
curl http://localhost:3100

# Voir tous les services
docker compose -f docker/docker-compose.yml ps
```

Tous les services doivent être "Up" et "healthy".

## 🆘 En cas de problème

### Services ne démarrent pas

```bash
# Voir les logs
docker compose -f docker/docker-compose.yml logs

# Logs d'un service spécifique
docker logs paperclip
docker logs postgres
docker logs mem0
```

### Mem0 ne démarre pas

```bash
# Mem0 peut prendre 2-3 minutes au premier démarrage
# Vérifier les logs:
docker logs mem0

# Si timeout, augmenter le healthcheck timeout dans docker-compose.yml
```

### Preview deployment échoue

```bash
# Vérifier le token Dokploy
grep DOKPLOY_API_TOKEN /opt/paperclip-stack/.env

# Tester manuellement
./scripts/dokploy-preview-webhook.sh test-repo feature/test 1
```

## 📖 Documentation

Toute la documentation est dans le repo:

- **README-ENTERPRISE.md** - Vue d'ensemble
- **DEPLOIEMENT-SERVEUR.md** - Guide détaillé de déploiement
- **MIGRATION-ENTREPRISE.md** - Changements vs stack personnelle
- **CLAUDE.md** - Architecture complète
- **CREATION-REPO-GITHUB.md** - Guide création repo

## 🎯 Workflow entreprise

```
1. Humain crée mission → Paperclip UI
       ↓
2. CEO décompose → délègue aux agents
       ↓
3. Agent code → branche → PR Gitea
       ↓
4. DevOps → Preview Dokploy automatique
       ↓
5. Preview URL → commentée sur PR
       ↓
6. CTO review + approve (PAS de merge)
       ↓
7. HUMAIN vérifie preview → merge Gitea
       ↓
8. Cleanup auto du preview
```

## ✅ Checklist installation

- [ ] Serveur accessible via SSH
- [ ] Docker & Docker Compose installés
- [ ] Repo cloné dans `/opt/paperclip-stack`
- [ ] `.env` configuré avec TOUS les secrets
- [ ] Services Docker démarrés (all "Up")
- [ ] Paperclip bootstrap réussi
- [ ] 16 agents injectés
- [ ] Token Dokploy généré et configuré
- [ ] Preview webhook testé
- [ ] Accès Paperclip UI (tunnel ou reverse proxy)
- [ ] Workflow test réussi
- [ ] Documentation partagée avec l'équipe

---

**Repo GitHub:** https://github.com/monkeyDkz/paperclip-deviprop

**Support:** Voir la documentation dans le repo

🚀 Prêt pour l'installation sur le serveur !
