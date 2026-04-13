# Guide de déploiement - Serveur dédié entreprise

## Prérequis serveur

Votre serveur dédié a déjà:
- ✅ Dokploy (déploiement)
- ✅ Gitea (git + PRs)
- ✅ Playwright (automation navigateur)

À installer:
- Paperclip (orchestration agents)
- PostgreSQL (base de données)
- Redis (cache/queues)
- Mem0 (mémoire agents)
- Chroma (embeddings vectoriels)

## Étape 1 : Configuration initiale

### 1.1 Cloner le repo sur le serveur

```bash
ssh votre-serveur
cd /opt  # ou votre dossier d'apps
git clone <votre-repo-stack-paperclip>
cd Stack-paperclip
```

### 1.2 Configurer les variables d'environnement

```bash
cp .env.example .env
nano .env
```

Remplir **toutes** les variables:

```bash
# PostgreSQL
POSTGRES_ADMIN_USER=admin
POSTGRES_ADMIN_PASSWORD=$(openssl rand -hex 32)

# Redis
REDIS_PASSWORD=$(openssl rand -hex 32)

# Gitea (déjà installé - récupérer les valeurs existantes)
GITEA_SECRET_KEY=<depuis votre Gitea existant>
GITEA_INTERNAL_TOKEN=<depuis votre Gitea existant>
GITEA_API_TOKEN=<créer dans Gitea UI > Settings > Applications>

# Paperclip
PAPERCLIP_ADMIN_EMAIL=admin@votre-entreprise.com
PAPERCLIP_ADMIN_PASSWORD=$(openssl rand -base64 16)
PAPERCLIP_AUTH_SECRET=$(openssl rand -hex 32)
PAPERCLIP_AGENT_JWT_SECRET=$(openssl rand -hex 32)

# Dokploy (nouveau)
DOKPLOY_API_URL=https://dokploy.votre-domaine.com
DOKPLOY_API_TOKEN=<générer dans Dokploy UI>
DOKPLOY_WEBHOOK_URL=https://webhook.votre-domaine.com
DOKPLOY_DOMAIN=votre-domaine.com

# Claude API (si Mem0 utilise Anthropic)
ANTHROPIC_API_KEY=sk-ant-...
```

**Sauvegarder les secrets** dans un gestionnaire de mots de passe!

### 1.3 Adapter le docker-compose pour serveur distant

Si Gitea et Dokploy tournent déjà sur le serveur (hors Docker), modifier `docker/docker-compose.yml`:

```yaml
# Commenter ou supprimer le service Gitea (déjà installé)
# gitea:
#   ...

# Modifier les URLs dans paperclip environment:
environment:
  GITEA_URL: https://gitea.votre-domaine.com  # URL publique, pas http://gitea:3000
  DOKPLOY_API_URL: https://dokploy.votre-domaine.com
```

Si Gitea tourne en Docker mais **pas dans ce compose**, utiliser un réseau externe:

```yaml
networks:
  stack-network:
    external: true
    name: gitea-network  # Le réseau de votre Gitea existant
```

## Étape 2 : Lancer les services

```bash
# Démarrer tous les services
docker compose -f docker/docker-compose.yml up -d

# Vérifier les logs
docker compose -f docker/docker-compose.yml logs -f

# Attendre que tout soit UP (surtout Mem0 qui prend ~2 min)
docker ps
```

Vérifier la santé des services:

```bash
# PostgreSQL
docker exec postgres pg_isready -U admin

# Redis
docker exec redis redis-cli -a "$REDIS_PASSWORD" ping

# Mem0
curl http://localhost:8050/health

# Chroma
curl http://localhost:8000/api/v1/heartbeat

# Paperclip
curl http://localhost:3100/api/health
```

## Étape 3 : Bootstrap Paperclip

```bash
# Initialiser Paperclip (admin + onboard)
./scripts/bootstrap-paperclip.sh
```

Sortie attendue:
```
[OK] Config créée
[OK] Admin créé
[OK] Bootstrap terminé !

  Paperclip → http://localhost:3100
  Email     : admin@votre-entreprise.com
  Password  : <votre mot de passe>
```

### 3.1 Vérifier l'accès Paperclip UI

```bash
# Créer un tunnel SSH temporaire (si pas de reverse proxy)
ssh -L 3100:localhost:3100 votre-serveur

# Ouvrir http://localhost:3100 dans votre navigateur
```

Login avec les credentials `.env`.

## Étape 4 : Configurer Dokploy

### 4.1 Générer le token API Dokploy

1. Aller sur `https://dokploy.votre-domaine.com`
2. Settings > API Tokens > Create New Token
3. Copier le token dans `.env` : `DOKPLOY_API_TOKEN=...`

### 4.2 Tester le script de preview

```bash
# Rendre exécutables les scripts
chmod +x scripts/dokploy-preview-webhook.sh
chmod +x scripts/dokploy-preview-cleanup.sh

# Test manuel
export DOKPLOY_API_URL="https://dokploy.votre-domaine.com"
export DOKPLOY_API_TOKEN="votre-token"
export DOKPLOY_DOMAIN="votre-domaine.com"
export GITEA_URL="https://gitea.votre-domaine.com"

./scripts/dokploy-preview-webhook.sh test-repo feature/test-branch 1
```

Sortie attendue:
```json
{
  "preview_url": "https://pr-1-test-repo.votre-domaine.com",
  "service_id": "abc123",
  "deployment_id": "def456"
}
```

### 4.3 Exposer le webhook (optionnel)

Si vous voulez que Gitea puisse appeler le webhook automatiquement lors de création de PR:

```bash
# Créer un serveur webhook simple avec Express
npm install -g webhook-server

# Ou utiliser n8n (recommandé)
# Créer un workflow n8n qui:
# 1. Écoute POST /preview-deploy
# 2. Valide le X-Dokploy-Token
# 3. Appelle scripts/dokploy-preview-webhook.sh
# 4. Retourne le preview_url
```

## Étape 5 : Injecter les agents

```bash
# Charger les prompts + assigner les modèles Claude
./scripts/inject-agents.sh
```

Sortie attendue:
```
── Opus 4.6 (stratégie) ──
[OK] CEO → model=claude-opus-4-6 mem0=ceo (7207 chars)
[OK] CTO → model=claude-opus-4-6 mem0=cto (5508 chars)

── Sonnet 4.6 (code + coordination) ──
[OK] Growth Lead → model=claude-sonnet-4-6 mem0=growth-lead (12569 chars)
[OK] Lead Backend → model=claude-sonnet-4-6 mem0=lead-backend (4059 chars)
[OK] Lead Frontend → model=claude-sonnet-4-6 mem0=lead-frontend (4485 chars)
[OK] DevOps → model=claude-sonnet-4-6 mem0=devops (4525 chars)
...
```

## Étape 6 : Tester le workflow complet

### 6.1 Créer un projet test dans Paperclip

Via l'UI Paperclip:
1. Projects > Create Project
2. Nom: "Test Preview Workflow"
3. Repository: créer un repo vide dans Gitea

### 6.2 Créer une mission pour le CEO

```bash
# Via API
curl -X POST "http://localhost:3100/api/issues" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test: Créer page about",
    "description": "Créer une page About basique pour tester le workflow preview deployment",
    "assignee": "ceo",
    "projectId": "<PROJECT_ID>"
  }'
```

Ou via l'UI:
1. Issues > Create Issue
2. Titre: "Test: Créer page about"
3. Assignee: CEO
4. Description détaillée

### 6.3 Wake le CEO

```bash
./scripts/agent-control.sh wake ceo
```

### 6.4 Suivre le workflow

Le CEO devrait:
1. ✅ Checkout la tâche
2. ✅ Lire la description
3. ✅ Créer une sous-tâche pour Lead Frontend
4. ✅ Wake Lead Frontend
5. ✅ Notifier @CEO sur le parent

Lead Frontend devrait:
1. ✅ Checkout sa sous-tâche
2. ✅ Cloner le repo
3. ✅ Créer une branche `feature/STA-X-about-page`
4. ✅ Coder la page
5. ✅ Commit + push
6. ✅ Créer une PR sur Gitea
7. ✅ Mettre la tâche en `in_review`
8. ✅ Notifier @CEO

DevOps (si appelé pour preview):
1. ✅ Déclencher `dokploy-preview-webhook.sh`
2. ✅ Commenter sur la PR avec l'URL de preview

CTO devrait:
1. ✅ Lire la PR
2. ✅ Vérifier la preview URL
3. ✅ Approuver (SANS merge)
4. ✅ Commenter "Ready for human merge"
5. ✅ Notifier @CEO

**Dev humain:**
1. ✅ Aller sur Gitea
2. ✅ Ouvrir la PR
3. ✅ Cliquer sur l'URL de preview
4. ✅ Vérifier visuellement
5. ✅ Cliquer "Merge" si OK

**Cleanup auto:**
1. ✅ Webhook Gitea (sur merge) appelle `dokploy-preview-cleanup.sh`
2. ✅ Service preview supprimé

## Étape 7 : Configuration webhooks Gitea (optionnel)

Pour automatiser le cleanup des previews après merge:

### 7.1 Dans Gitea

Pour chaque repo:
1. Settings > Webhooks > Add Webhook > Gitea
2. URL: `https://webhook.votre-domaine.com/preview-cleanup`
3. Method: POST
4. Trigger on: Pull Request > Closed/Merged
5. Active: ✅

### 7.2 Script webhook cleanup

Créer un endpoint qui reçoit les webhooks Gitea:

```javascript
// webhook-server.js
const express = require('express');
const { exec } = require('child_process');
const app = express();

app.use(express.json());

app.post('/preview-cleanup', (req, res) => {
  const { action, pull_request, repository } = req.body;

  if (action === 'closed' || action === 'merged') {
    const repo = repository.name;
    const prNumber = pull_request.number;

    exec(`./scripts/dokploy-preview-cleanup.sh ${repo} ${prNumber}`, (err, stdout) => {
      if (err) {
        console.error(`Cleanup error: ${err}`);
        return res.status(500).json({ error: err.message });
      }
      console.log(stdout);
      res.json({ status: 'cleaned', repo, pr: prNumber });
    });
  } else {
    res.json({ status: 'ignored', action });
  }
});

app.listen(3333, () => console.log('Webhook server on :3333'));
```

Démarrer:
```bash
node webhook-server.js &
```

## Étape 8 : Monitoring & Maintenance

### 8.1 Logs des agents

```bash
# Logs Paperclip (agents)
docker logs -f paperclip

# Logs Mem0
docker logs -f mem0

# Logs PostgreSQL
docker logs -f postgres
```

### 8.2 Vérifier les previews actifs

```bash
# Lister tous les services preview sur Dokploy
curl -X GET "$DOKPLOY_API_URL/api/application?labels.type=preview" \
  -H "Authorization: Bearer $DOKPLOY_API_TOKEN"
```

### 8.3 Cleanup manuel si nécessaire

```bash
# Si des previews sont orphelins (PR mergée mais service pas supprimé)
./scripts/dokploy-preview-cleanup.sh nom-repo 42
```

### 8.4 Sauvegardes

Sauvegarder régulièrement:
- **PostgreSQL**: `docker exec postgres pg_dump -U admin paperclip_db > backup.sql`
- **Mem0 data**: `docker cp mem0:/app/data ./backups/mem0-data`
- **Prompts agents**: `tar -czf agents-backup.tar.gz agents/prompts/`

## Résumé des changements vs stack perso

| Composant | Stack perso | Stack entreprise |
|-----------|-------------|------------------|
| **CTO merge** | Automatique | ❌ JAMAIS - humain seulement |
| **Preview deploy** | ❌ Pas de preview | ✅ Dokploy auto sur chaque PR |
| **Validation** | CTO merge direct | CTO approve + humain merge après preview |
| **Cleanup** | N/A | ✅ Auto via webhook Gitea |
| **Gitea** | Docker local | Serveur dédié (externe) |
| **Dokploy** | ❌ Pas installé | ✅ Intégré pour previews |

## Checklist finale

- [ ] Services Docker UP et healthy
- [ ] Paperclip bootstrap OK
- [ ] Agents injectés (16 agents)
- [ ] Dokploy token configuré
- [ ] Preview webhook testé manuellement
- [ ] Workflow test complet réussi:
  - [ ] CEO → tâche
  - [ ] Lead → code + PR
  - [ ] Preview déployé
  - [ ] CTO approve (sans merge)
  - [ ] Humain merge
  - [ ] Preview cleanup
- [ ] Webhooks Gitea configurés
- [ ] Backup plan en place
- [ ] Documentation partagée avec l'équipe

## Dépannage

### Preview ne se déploie pas

```bash
# Vérifier les variables d'env dans le container
docker exec paperclip env | grep DOKPLOY

# Tester le script manuellement
docker exec paperclip bash
./scripts/dokploy-preview-webhook.sh test-repo feature/test 1
```

### CTO essaie encore de merger

Vérifier que le prompt a été correctement injecté:

```bash
# Ré-injecter
./scripts/inject-agents.sh

# Vérifier dans Paperclip UI > Agents > CTO > Prompt Template
# Doit contenir "Tu NE merges JAMAIS les PRs"
```

### Mem0 ne démarre pas

```bash
# Vérifier Chroma d'abord
curl http://localhost:8000/api/v1/heartbeat

# Augmenter le timeout healthcheck dans docker-compose.yml si serveur lent
```

## Support

Pour toute question, voir:
- `MIGRATION-ENTREPRISE.md` - Plan détaillé de migration
- `CLAUDE.md` - Documentation technique complète
- `agents/playbooks/23-agent-communication-protocol.md` - Protocole communication agents
