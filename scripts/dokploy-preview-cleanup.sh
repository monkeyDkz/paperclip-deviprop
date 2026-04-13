#!/bin/bash
# ============================================================
# DOKPLOY PREVIEW CLEANUP
# Supprime le service preview après merge/close de la PR
# ============================================================
# Usage: ./dokploy-preview-cleanup.sh <repo> <pr_number>
# À appeler via webhook Gitea sur PR merge/close
# ============================================================

set -euo pipefail

REPO="${1:?Missing repo name}"
PR_NUMBER="${2:?Missing PR number}"

# Configuration
DOKPLOY_API_URL="${DOKPLOY_API_URL:?Set DOKPLOY_API_URL}"
DOKPLOY_API_TOKEN="${DOKPLOY_API_TOKEN:?Set DOKPLOY_API_TOKEN}"

SERVICE_NAME="${REPO}-pr-${PR_NUMBER}"

log() { echo "[$(date +'%H:%M:%S')] $1" >&2; }

log "Cleaning up preview service: $SERVICE_NAME"

# ── Étape 1 : Chercher le service ────────────────────────────
EXISTING_SERVICE=$(curl -s -X GET "$DOKPLOY_API_URL/api/application?name=$SERVICE_NAME" \
  -H "Authorization: Bearer $DOKPLOY_API_TOKEN" \
  -H "Content-Type: application/json" || echo "{}")

SERVICE_ID=$(echo "$EXISTING_SERVICE" | jq -r '.id // empty')

if [ -z "$SERVICE_ID" ]; then
  log "Service not found: $SERVICE_NAME (already deleted or never created)"
  echo "{\"status\": \"not_found\", \"service\": \"$SERVICE_NAME\"}"
  exit 0
fi

# ── Étape 2 : Supprimer le service ────────────────────────────
log "Deleting service ID: $SERVICE_ID"

DELETE_RESPONSE=$(curl -s -X DELETE "$DOKPLOY_API_URL/api/application/$SERVICE_ID" \
  -H "Authorization: Bearer $DOKPLOY_API_TOKEN" \
  -H "Content-Type: application/json")

log "Preview service deleted: $SERVICE_NAME"

echo "{\"status\": \"deleted\", \"service\": \"$SERVICE_NAME\", \"service_id\": \"$SERVICE_ID\"}"
