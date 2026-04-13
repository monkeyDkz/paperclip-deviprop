#!/bin/bash
# ============================================================
# DOKPLOY PREVIEW DEPLOYMENT WEBHOOK
# Déploie automatiquement une branche PR sur Dokploy
# ============================================================
# Usage: ./dokploy-preview-webhook.sh <repo> <branch> <pr_number>
# Retourne: {"preview_url": "https://..."}
# ============================================================

set -euo pipefail

REPO="${1:?Missing repo name}"
BRANCH="${2:?Missing branch name}"
PR_NUMBER="${3:?Missing PR number}"

# Configuration
DOKPLOY_API_URL="${DOKPLOY_API_URL:?Set DOKPLOY_API_URL}"
DOKPLOY_API_TOKEN="${DOKPLOY_API_TOKEN:?Set DOKPLOY_API_TOKEN}"
DOKPLOY_DOMAIN="${DOKPLOY_DOMAIN:-votre-domaine.com}"
GITEA_URL="${GITEA_URL:-http://gitea:3000}"

# Nom du service preview (unique par PR)
SERVICE_NAME="${REPO}-pr-${PR_NUMBER}"
PREVIEW_SUBDOMAIN="pr-${PR_NUMBER}-${REPO}"
PREVIEW_URL="https://${PREVIEW_SUBDOMAIN}.${DOKPLOY_DOMAIN}"

log() { echo "[$(date +'%H:%M:%S')] $1" >&2; }

log "Deploying preview for $REPO (branch: $BRANCH, PR: #$PR_NUMBER)"

# ── Étape 1 : Vérifier si le service existe déjà ─────────────
EXISTING_SERVICE=$(curl -s -X GET "$DOKPLOY_API_URL/api/application?name=$SERVICE_NAME" \
  -H "Authorization: Bearer $DOKPLOY_API_TOKEN" \
  -H "Content-Type: application/json" || echo "{}")

SERVICE_ID=$(echo "$EXISTING_SERVICE" | jq -r '.id // empty')

if [ -z "$SERVICE_ID" ]; then
  log "Creating new preview service: $SERVICE_NAME"

  # ── Étape 2 : Créer le service sur Dokploy ─────────────────
  CREATE_RESPONSE=$(curl -s -X POST "$DOKPLOY_API_URL/api/application" \
    -H "Authorization: Bearer $DOKPLOY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "'"$SERVICE_NAME"'",
      "appName": "'"$SERVICE_NAME"'",
      "sourceType": "git",
      "repository": "'"${GITEA_URL}/${REPO}.git"'",
      "branch": "'"$BRANCH"'",
      "buildType": "docker",
      "dockerfile": "Dockerfile",
      "env": [],
      "domains": [
        {
          "host": "'"$PREVIEW_SUBDOMAIN"'",
          "domain": "'"$DOKPLOY_DOMAIN"'",
          "https": true
        }
      ],
      "labels": {
        "pr": "'"$PR_NUMBER"'",
        "repo": "'"$REPO"'",
        "type": "preview",
        "branch": "'"$BRANCH"'"
      }
    }')

  SERVICE_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')

  if [ -z "$SERVICE_ID" ] || [ "$SERVICE_ID" = "null" ]; then
    log "ERROR: Failed to create service"
    echo "{\"error\": \"Failed to create preview service\", \"details\": $CREATE_RESPONSE}"
    exit 1
  fi

  log "Service created: $SERVICE_ID"
else
  log "Updating existing preview service: $SERVICE_ID"

  # ── Étape 2b : Mettre à jour la branche si elle a changé ───
  curl -s -X PATCH "$DOKPLOY_API_URL/api/application/$SERVICE_ID" \
    -H "Authorization: Bearer $DOKPLOY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "branch": "'"$BRANCH"'"
    }' > /dev/null
fi

# ── Étape 3 : Déclencher le déploiement ─────────────────────
log "Triggering deployment for service $SERVICE_ID"

DEPLOY_RESPONSE=$(curl -s -X POST "$DOKPLOY_API_URL/api/application/$SERVICE_ID/deploy" \
  -H "Authorization: Bearer $DOKPLOY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')

DEPLOYMENT_ID=$(echo "$DEPLOY_RESPONSE" | jq -r '.deploymentId // empty')

if [ -z "$DEPLOYMENT_ID" ]; then
  log "WARNING: Deployment triggered but no deployment ID returned"
fi

# ── Étape 4 : Retourner l'URL de preview ────────────────────
log "Preview URL: $PREVIEW_URL"

echo "{\"preview_url\": \"$PREVIEW_URL\", \"service_id\": \"$SERVICE_ID\", \"deployment_id\": \"$DEPLOYMENT_ID\"}"
