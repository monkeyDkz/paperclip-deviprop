# Installation sur serveur Deviprop (192.168.94.96)

## État actuel du serveur

Services déjà installés et en cours d'exécution:
- ✅ **PostgreSQL** (deviprop-postgres) sur port 5432
- ✅ **Redis** (deviprop-redis) sur port 6379
- ✅ **Dokploy** sur port 3000
- ✅ **Gitea** sur port 3001
- ✅ **Playwright** (qolinxplaywright)
- ✅ **Traefik** (reverse proxy)

## Stratégie d'installation

**Réutiliser les services existants** au lieu de les recréer:

1. **PostgreSQL** → Créer une database `paperclip_db` dans le PostgreSQL existant
2. **Redis** → Utiliser le Redis existant
3. **Gitea** → Utiliser celui sur port 3001
4. **Dokploy** → Utiliser celui qui tourne
5. **Nouveaux services** → Installer uniquement:
   - Paperclip (port 3100)
   - Mem0 (port 8050)
   - Chroma (port 8000)

## Installation pas à pas

### 1. Se connecter au serveur

```bash
ssh -p 55184 admin1@192.168.94.96
```

### 2. Créer le dossier d'installation

```bash
sudo mkdir -p /opt/paperclip-stack
sudo chown admin1:admin1 /opt/paperclip-stack
cd /opt/paperclip-stack
```

### 3. Cloner le repo

```bash
git clone https://github.com/monkeyDkz/paperclip-deviprop.git .
```

### 4. Préparer la base de données PostgreSQL

```bash
# Se connecter au PostgreSQL existant
docker exec -it deviprop-postgres psql -U admin

# Dans psql, créer la database pour Paperclip
CREATE DATABASE paperclip_db;
GRANT ALL PRIVILEGES ON DATABASE paperclip_db TO admin;
\q
```

### 5. Configurer .env

```bash
# Copier le template serveur
cp .env.server.example .env

# Éditer avec les vrais credentials
nano .env
```

Remplir avec:

```bash
# PostgreSQL existant
POSTGRES_ADMIN_USER=admin
POSTGRES_ADMIN_PASSWORD=<password du PostgreSQL existant>

# Gitea (créer token dans UI Gitea sur http://192.168.94.96:3001)
GITEA_API_TOKEN=<créer dans Gitea > Settings > Applications>

# Paperclip
PAPERCLIP_ADMIN_EMAIL=admin@deviprop.com
PAPERCLIP_ADMIN_PASSWORD=<choisir un fort>
PAPERCLIP_AUTH_SECRET=$(openssl rand -hex 32)
PAPERCLIP_AGENT_JWT_SECRET=$(openssl rand -hex 32)
PAPERCLIP_PUBLIC_URL=http://192.168.94.96:3100
PAPERCLIP_ALLOWED_HOSTNAMES=192.168.94.96,localhost

# Dokploy (créer token dans UI Dokploy sur http://192.168.94.96:3000)
DOKPLOY_API_URL=http://host.docker.internal:3000
DOKPLOY_API_TOKEN=<générer dans Dokploy UI>
DOKPLOY_WEBHOOK_URL=http://192.168.94.96:3000
DOKPLOY_DOMAIN=deviprop.com

# Claude API
ANTHROPIC_API_KEY=sk-ant-...
```

### 6. Démarrer les services (uniquement les nouveaux)

```bash
# Utiliser le docker-compose adapté pour serveur
docker compose -f docker/docker-compose.server.yml up -d
```

### 7. Vérifier que tout démarre

```bash
# Voir les logs
docker compose -f docker/docker-compose.server.yml logs -f

# Attendre que Mem0 soit healthy (peut prendre 2-3 min)
docker ps
```

Vous devriez voir:
- `paperclip-chroma` (Up)
- `paperclip-mem0` (Up healthy)
- `paperclip` (Up)

### 8. Bootstrap Paperclip

```bash
chmod +x scripts/*.sh
./scripts/bootstrap-paperclip.sh
```

### 9. Injecter les agents

```bash
./scripts/inject-agents.sh
```

Devrait afficher:
```
[OK] CEO → model=claude-opus-4-6 mem0=ceo (7207 chars)
[OK] CTO → model=claude-opus-4-6 mem0=cto (5508 chars)
...
[OK] Injection terminée — 16 agents configurés
```

### 10. Accéder à Paperclip UI

Depuis votre machine Windows:

```bash
# Créer un tunnel SSH
ssh -p 55184 -L 3100:localhost:3100 admin1@192.168.94.96

# Ou utiliser le script
cd C:\Users\kays\Desktop\paperclip\Stack-paperclip
./connect-server.sh tunnel
```

Puis ouvrir: **http://localhost:3100**

Login:
- Email: `admin@deviprop.com` (celui dans .env)
- Password: celui que vous avez mis dans .env

## Tester le workflow

### 1. Créer un projet test dans Paperclip UI

1. Ouvrir http://localhost:3100
2. Projects > Create Project
3. Name: "Test Preview Workflow"
4. Repository: créer un repo vide dans Gitea (http://192.168.94.96:3001)

### 2. Créer une mission

1. Issues > Create Issue
2. Title: "Test: Créer page about"
3. Description: "Créer une page About basique HTML pour tester le workflow"
4. Assignee: **CEO**
5. Create

### 3. Wake le CEO

```bash
ssh -p 55184 admin1@192.168.94.96
cd /opt/paperclip-stack
./scripts/agent-control.sh wake ceo
```

### 4. Suivre l'exécution

```bash
# Status
./scripts/agent-control.sh status ceo

# Logs
docker logs -f paperclip
```

### 5. Vérifier le workflow complet

Le workflow devrait être:
1. ✅ CEO lit la mission
2. ✅ CEO crée des sous-tâches
3. ✅ CEO wake Lead Frontend
4. ✅ Lead Frontend code la page
5. ✅ Lead Frontend crée PR sur Gitea
6. ✅ DevOps déclenche preview Dokploy
7. ✅ Preview URL commentée sur PR
8. ✅ CTO review + approve (SANS merger)
9. ✅ **Vous mergez manuellement** sur Gitea après avoir vérifié la preview
10. ✅ Preview cleanup automatique

## Configuration Dokploy webhook

Pour que le script de preview puisse créer des services sur Dokploy:

### 1. Générer token API Dokploy

1. Ouvrir http://192.168.94.96:3000
2. Settings > API Tokens
3. Create New Token
4. Copier le token
5. Ajouter dans `/opt/paperclip-stack/.env`:
   ```
   DOKPLOY_API_TOKEN=votre_token
   ```

### 2. Redémarrer Paperclip

```bash
cd /opt/paperclip-stack
docker compose -f docker/docker-compose.server.yml restart paperclip
```

### 3. Tester le webhook preview

```bash
cd /opt/paperclip-stack

export DOKPLOY_API_URL="http://host.docker.internal:3000"
export DOKPLOY_API_TOKEN="votre_token"
export DOKPLOY_DOMAIN="deviprop.com"

./scripts/dokploy-preview-webhook.sh test-repo feature/test-branch 1
```

Devrait retourner:
```json
{
  "preview_url": "https://pr-1-test-repo.deviprop.com",
  "service_id": "...",
  "deployment_id": "..."
}
```

## Commandes utiles

```bash
# Voir tous les services Paperclip
docker compose -f docker/docker-compose.server.yml ps

# Logs Paperclip
docker logs -f paperclip

# Logs Mem0
docker logs -f paperclip-mem0

# Redémarrer Paperclip
docker compose -f docker/docker-compose.server.yml restart paperclip

# Arrêter tous les services Paperclip
docker compose -f docker/docker-compose.server.yml down

# Démarrer
docker compose -f docker/docker-compose.server.yml up -d

# Wake un agent
cd /opt/paperclip-stack
./scripts/agent-control.sh wake ceo

# Status d'un agent
./scripts/agent-control.sh status ceo

# Lister les previews actifs sur Dokploy
curl -X GET "http://localhost:3000/api/application?labels.type=preview" \
  -H "Authorization: Bearer $DOKPLOY_API_TOKEN"
```

## Troubleshooting

### Paperclip ne démarre pas

```bash
# Vérifier les logs
docker logs paperclip

# Vérifier la connexion PostgreSQL
docker exec paperclip pg_isready -h deviprop-postgres -U admin
```

### Mem0 ne démarre pas

```bash
# Mem0 prend 2-3 minutes au premier démarrage
docker logs paperclip-mem0

# Vérifier que Chroma est UP
curl http://localhost:8000/api/v1/heartbeat
```

### Preview deployment échoue

```bash
# Vérifier le token Dokploy
grep DOKPLOY_API_TOKEN /opt/paperclip-stack/.env

# Tester manuellement
./scripts/dokploy-preview-webhook.sh test-repo feature/test 1
```

### Can't connect to PostgreSQL

```bash
# Vérifier que le PostgreSQL existant tourne
docker ps | grep deviprop-postgres

# Vérifier la database paperclip_db existe
docker exec -it deviprop-postgres psql -U admin -c "\l"
```

## Nettoyage (si besoin de réinstaller)

```bash
# Arrêter les services Paperclip
cd /opt/paperclip-stack
docker compose -f docker/docker-compose.server.yml down -v

# Supprimer le dossier
cd /opt
sudo rm -rf paperclip-stack

# La database PostgreSQL et Redis existants ne seront PAS touchés
```

## Résumé de l'architecture

```
┌─────────────────────────────────────────────────────────┐
│              Serveur Deviprop (192.168.94.96)            │
│                                                          │
│  Services EXISTANTS (réutilisés):                        │
│  ┌──────────────┐  ┌──────────┐  ┌──────────┐         │
│  │ PostgreSQL   │  │  Redis   │  │  Gitea   │         │
│  │   :5432      │  │  :6379   │  │  :3001   │         │
│  └──────┬───────┘  └────┬─────┘  └────┬─────┘         │
│         │               │             │                 │
│  ┌──────┴───────────────┴─────────────┴─────┐          │
│  │         Réseau dokploy-network            │          │
│  └──────┬────────────────────────────────────┘          │
│         │                                                │
│  Services NOUVEAUX (installés):                         │
│  ┌──────┴────────────────────────────────────┐          │
│  │          Paperclip :3100                   │          │
│  │  ┌──────┐  ┌──────┐  ┌──────┐            │          │
│  │  │ CEO  │→│ CTO  │→│ Devs │            │          │
│  │  └──────┘  └──────┘  └──────┘            │          │
│  └──────┬────────────────────────────────────┘          │
│         │                                                │
│  ┌──────┴─────┐  ┌──────────┐                          │
│  │  Mem0      │  │  Chroma  │                          │
│  │  :8050     │  │  :8000   │                          │
│  └────────────┘  └──────────┘                          │
│                                                          │
│  Dokploy :3000 (existant - gère les previews)           │
└─────────────────────────────────────────────────────────┘
```

Workflow:
```
Agent → Branche → PR Gitea → Preview Dokploy → CTO Review → Humain Merge
```

---

**Prêt pour l'installation !** 🚀

Suivre les étapes ci-dessus dans l'ordre.
