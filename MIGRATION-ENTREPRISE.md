# Migration Stack Paperclip pour Entreprise

## Changements par rapport à la stack personnelle

### 1. Infrastructure cible

**Serveur dédié existant:**
- Dokploy (déploiement)
- Gitea (déjà installé)
- Playwright (déjà installé)

**À ajouter:**
- Paperclip (orchestration agents)
- PostgreSQL (pour Paperclip)
- Redis (pour Paperclip)
- Mem0 (mémoire agents)
- Chroma (embeddings)

### 2. Workflow modifié

#### AVANT (stack perso):
```
Agent → branche → PR → CTO review → CTO MERGE AUTO → main
```

#### APRÈS (entreprise):
```
Agent → branche → PR → Preview Dokploy → CTO review → HUMAIN MERGE → main
                           ↓
                    URL preview commentée sur PR
```

### 3. Changements de comportement des agents

| Agent | Avant | Après |
|-------|-------|-------|
| **CTO** | Review + Approve + **MERGE** | Review + Approve + **Notifier dev humain** + Trigger preview |
| **DevOps** | Dockerfile + CI | Dockerfile + CI + **Déploiement preview Dokploy** |
| **Lead Frontend/Backend** | Branche + PR | **Inchangé** ✓ |
| **CEO** | Orchestration | **Inchangé** ✓ |

## Modifications techniques requises

### A. Prompts agents à modifier

#### 1. `agents/prompts/cto.txt`

**SUPPRIMER** (lignes 54-58):
```bash
#### Merger une PR approuvée
curl -s -X POST "http://gitea:3000/api/v1/repos/stack-pirates/REPO/pulls/PR_NUMBER/merge" \
  -H "Authorization: token $GITEA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"Do": "squash", "merge_message_field": "[IDENTIFIER] titre"}'
```

**REMPLACER PAR**:
```bash
#### Approuver une PR et déclencher preview
# 1. Approuver la PR
curl -s -X POST "http://gitea:3000/api/v1/repos/stack-pirates/REPO/pulls/PR_NUMBER/reviews" \
  -H "Authorization: token $GITEA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"body": "✅ Code review passed. Ready for human merge.", "event": "APPROVED"}'

# 2. Déclencher le déploiement preview sur Dokploy
curl -s -X POST "$DOKPLOY_WEBHOOK_URL/preview-deploy" \
  -H "Content-Type: application/json" \
  -H "X-Dokploy-Token: $DOKPLOY_API_TOKEN" \
  -d '{
    "repo": "REPO_NAME",
    "branch": "BRANCH_NAME",
    "pr_number": PR_NUMBER
  }'

# 3. Commenter sur la PR que c'est prêt pour merge
curl -s -X POST "http://gitea:3000/api/v1/repos/stack-pirates/REPO/issues/PR_NUMBER/comments" \
  -H "Authorization: token $GITEA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"body": "✅ **Review passed** - Ready for human merge\n\n⏳ Preview deployment in progress...\nURL will be posted below once ready."}'

# 4. Notifier CEO + dev humain
curl -s -X POST "$PAPERCLIP_API_URL/api/issues/$PAPERCLIP_TASK_ID/comments" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"body": "@CEO PR approved. Preview deploying. Waiting for human merge."}'
```

**Modifier le workflow (ligne 66-72)**:
```
1. Recevoir la notification @CTO (via commentaire Paperclip)
2. Aller lire la PR sur Gitea (diff, fichiers)
3. Reviewer le code (qualité, conventions, bugs, sécurité)
4. Si OK → APPROVE + TRIGGER PREVIEW DOKPLOY + commenter "Approved, ready for human merge"
5. Si pas OK → REQUEST_CHANGES + commenter les problèmes + wake le dev
6. Notifier @CEO sur la tâche parent que la PR est approuvée et en attente de merge humain
```

#### 2. `agents/prompts/devops.txt`

**AJOUTER après l'étape 4** (après création de PR):

```bash
### Etape 4.5 : Déclencher le déploiement preview sur Dokploy
PR_NUMBER=$(curl -s "http://gitea:3000/api/v1/repos/stack-pirates/REPO/pulls?state=open&head=BRANCH" \
  -H "Authorization: token $GITEA_API_TOKEN" | jq -r '.[0].number')

# Déclencher Dokploy preview
PREVIEW_RESPONSE=$(curl -s -X POST "$DOKPLOY_WEBHOOK_URL/preview-deploy" \
  -H "Content-Type: application/json" \
  -H "X-Dokploy-Token: $DOKPLOY_API_TOKEN" \
  -d '{
    "repo": "REPO_NAME",
    "branch": "'$BRANCH_NAME'",
    "pr_number": '$PR_NUMBER'
  }')

# Extraire l'URL de preview
PREVIEW_URL=$(echo "$PREVIEW_RESPONSE" | jq -r '.preview_url')

# Commenter sur la PR avec l'URL de preview
curl -s -X POST "http://gitea:3000/api/v1/repos/stack-pirates/REPO/issues/$PR_NUMBER/comments" \
  -H "Authorization: token $GITEA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"body": "🚀 **Preview deployment ready**\n\n📍 URL: '$PREVIEW_URL'\n\n✅ You can now review the changes before merging."}'
```

### B. Script webhook Dokploy

Créer `scripts/dokploy-preview-webhook.sh`:

```bash
#!/bin/bash
# Webhook handler pour déployer les previews sur Dokploy
# Reçoit: repo, branch, pr_number
# Retourne: preview_url

set -euo pipefail

REPO="$1"
BRANCH="$2"
PR_NUMBER="$3"

# Nom du service preview (unique par PR)
SERVICE_NAME="${REPO}-pr-${PR_NUMBER}"
PREVIEW_SUBDOMAIN="pr-${PR_NUMBER}-${REPO}"

# Créer/Mettre à jour le service sur Dokploy
curl -X POST "$DOKPLOY_API_URL/api/services" \
  -H "Authorization: Bearer $DOKPLOY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "'$SERVICE_NAME'",
    "type": "git",
    "repository": "git@gitea:3000/stack-pirates/'$REPO'.git",
    "branch": "'$BRANCH'",
    "subdomain": "'$PREVIEW_SUBDOMAIN'",
    "autoUpdate": true,
    "labels": {
      "pr": "'$PR_NUMBER'",
      "repo": "'$REPO'",
      "type": "preview"
    }
  }'

# Déployer
curl -X POST "$DOKPLOY_API_URL/api/services/$SERVICE_NAME/deploy" \
  -H "Authorization: Bearer $DOKPLOY_API_TOKEN"

# Retourner l'URL
echo "{\"preview_url\": \"https://$PREVIEW_SUBDOMAIN.votre-domaine.com\"}"
```

### C. Variables d'environnement à ajouter

Dans `.env` du serveur:

```bash
# ── DOKPLOY ────────────────────────────────────────
DOKPLOY_API_URL=https://dokploy.votre-domaine.com
DOKPLOY_API_TOKEN=  # Généré dans Dokploy UI
DOKPLOY_WEBHOOK_URL=https://webhook.votre-domaine.com
```

### D. Docker Compose serveur

Modifier `docker/docker-compose.yml` pour pointer vers le serveur:

```yaml
paperclip:
  # ... config existante ...
  environment:
    # Ajouter:
    DOKPLOY_API_URL: ${DOKPLOY_API_URL}
    DOKPLOY_API_TOKEN: ${DOKPLOY_API_TOKEN}
    DOKPLOY_WEBHOOK_URL: ${DOKPLOY_WEBHOOK_URL}
```

## Workflow complet après migration

### 1. Agent reçoit une tâche

```
CEO wake Lead Frontend → "Créer page contact"
```

### 2. Lead Frontend code

```bash
git checkout -b feature/STA-42-contact-page
# ... code ...
git push
# Crée PR #123
```

### 3. DevOps déclenche preview

```bash
# Automatique après création PR
Preview URL: https://pr-123-myapp.votre-domaine.com
# Commenté sur PR Gitea
```

### 4. CTO review

```bash
# Lit le diff
# Teste la preview URL
# Si OK: APPROVE + commenter "Ready for human merge"
# Si pas OK: REQUEST_CHANGES
```

### 5. Dev humain merge

```bash
# Dev humain va sur Gitea
# Vérifie la preview
# Clique "Merge" si satisfait
```

### 6. Cleanup auto

```bash
# Webhook Gitea sur merge:
curl -X DELETE "$DOKPLOY_API_URL/api/services/myapp-pr-123"
# Supprime le service preview
```

## Checklist de migration

- [ ] Installer Paperclip sur serveur dédié
- [ ] Configurer PostgreSQL + Redis + Mem0 + Chroma
- [ ] Modifier `agents/prompts/cto.txt` (supprimer merge auto)
- [ ] Modifier `agents/prompts/devops.txt` (ajouter preview deploy)
- [ ] Créer `scripts/dokploy-preview-webhook.sh`
- [ ] Ajouter variables DOKPLOY_* dans `.env`
- [ ] Tester workflow complet:
  - [ ] Agent crée PR
  - [ ] Preview se déploie
  - [ ] URL commentée sur PR
  - [ ] CTO approve (sans merge)
  - [ ] Dev humain merge
  - [ ] Preview cleanup auto
- [ ] Documenter pour l'équipe
- [ ] Former les devs au nouveau workflow

## Avantages du nouveau workflow

✅ **Contrôle humain** - Merge toujours validé par un dev
✅ **Preview instantané** - Voir les changements avant merge
✅ **Pas de régression** - Review code + preview visuel
✅ **Cleanup auto** - Pas de services preview orphelins
✅ **Même hiérarchie** - CEO + agents inchangés
✅ **Audit trail** - Tout tracé dans Gitea + Paperclip

## Architecture finale

```
┌─────────────────────────────────────────────────┐
│           Serveur dédié entreprise               │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │  Gitea    │  │ Dokploy  │  │Playwright│      │
│  │  :3000   │  │  :3000   │  │  :3333   │      │
│  └────┬─────┘  └────┬─────┘  └──────────┘      │
│       │             │                            │
│  ┌────┴─────────────┴────┐                      │
│  │     Paperclip          │                      │
│  │  ┌──────┐  ┌──────┐   │                      │
│  │  │ CEO  │→│ CTO  │   │                      │
│  │  └──────┘  └──┬───┘   │                      │
│  │              ↓         │                      │
│  │         ┌──────┐       │                      │
│  │         │ Devs │       │                      │
│  │         └──────┘       │                      │
│  │                        │                      │
│  │  PostgreSQL + Redis    │                      │
│  │  Mem0 + Chroma         │                      │
│  └────────────────────────┘                      │
│                                                  │
│  Workflow:                                       │
│  Agent → PR → Preview Dokploy → CTO approve →   │
│  DEV HUMAIN MERGE                                │
└─────────────────────────────────────────────────┘
```
