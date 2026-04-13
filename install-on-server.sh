#!/bin/bash
# ============================================================
# INSTALLATION AUTOMATIQUE SUR SERVEUR ENTREPRISE
# ============================================================
# Usage depuis votre machine locale:
#   ./install-on-server.sh
#
# Ou directement sur le serveur:
#   curl -sSL https://raw.githubusercontent.com/VOTRE-USER/Stack-Paperclip-Enterprise/main/install-on-server.sh | bash
# ============================================================

set -euo pipefail

# Configuration serveur
SERVER_USER="${SERVER_USER:-admin1}"
SERVER_HOST="${SERVER_HOST:-192.168.94.96}"
SERVER_PORT="${SERVER_PORT:-55184}"
INSTALL_DIR="${INSTALL_DIR:-/opt/paperclip-stack}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${BLUE}[→]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║   PAPERCLIP STACK - INSTALLATION ENTREPRISE        ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Détecter si on est déjà sur le serveur ou en local
if [ -f "/etc/hostname" ] && grep -q "$(hostname)" <<< "$SERVER_HOST"; then
  ON_SERVER=true
  info "Exécution directe sur le serveur"
else
  ON_SERVER=false
  info "Exécution depuis machine locale - connexion SSH"
fi

# ── Fonction pour exécuter sur serveur ──────────────────────
run_on_server() {
  if [ "$ON_SERVER" = true ]; then
    eval "$1"
  else
    ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "$1"
  fi
}

# ── Étape 1 : Vérifier prérequis serveur ────────────────────
info "Vérification des prérequis..."

PREREQS_CHECK=$(run_on_server "
  command -v docker >/dev/null 2>&1 && echo 'docker_ok' || echo 'docker_missing'
  command -v git >/dev/null 2>&1 && echo 'git_ok' || echo 'git_missing'
  command -v curl >/dev/null 2>&1 && echo 'curl_ok' || echo 'curl_missing'
")

if echo "$PREREQS_CHECK" | grep -q "missing"; then
  fail "Prérequis manquants sur le serveur:\n$PREREQS_CHECK\n\nInstaller: apt install docker.io git curl"
fi

log "Prérequis OK (Docker, Git, Curl)"

# ── Étape 2 : Vérifier/Installer Docker Compose ─────────────
info "Vérification Docker Compose..."

run_on_server "
  if ! docker compose version >/dev/null 2>&1; then
    echo 'Installation Docker Compose...'
    sudo apt update
    sudo apt install -y docker-compose-plugin
  fi
"

log "Docker Compose OK"

# ── Étape 3 : Créer le dossier d'installation ───────────────
info "Création du dossier d'installation: $INSTALL_DIR"

run_on_server "
  # Si le dossier existe, demander confirmation pour le supprimer
  if [ -d '$INSTALL_DIR' ]; then
    echo '⚠️  Le dossier $INSTALL_DIR existe déjà.'
    echo 'Voulez-vous le SUPPRIMER et réinstaller ? (y/N)'
    read -r CONFIRM
    if [ \"\$CONFIRM\" = 'y' ] || [ \"\$CONFIRM\" = 'Y' ]; then
      echo 'Arrêt des services existants...'
      cd '$INSTALL_DIR' && docker compose -f docker/docker-compose.yml down 2>/dev/null || true
      echo 'Suppression de $INSTALL_DIR...'
      sudo rm -rf '$INSTALL_DIR'
    else
      echo 'Installation annulée.'
      exit 1
    fi
  fi

  # Créer le dossier
  sudo mkdir -p '$INSTALL_DIR'
  sudo chown \$USER:\$USER '$INSTALL_DIR'
"

log "Dossier créé: $INSTALL_DIR"

# ── Étape 4 : Cloner le repo ────────────────────────────────
info "Clonage du repository GitHub..."

GITHUB_REPO="${GITHUB_REPO:-https://github.com/monkeyDkz/paperclip-deviprop.git}"

run_on_server "
  cd '$INSTALL_DIR'
  git clone '$GITHUB_REPO' .
  git checkout main
"

log "Repository cloné"

# ── Étape 5 : Configurer .env ───────────────────────────────
info "Configuration des variables d'environnement..."

warn "⚠️  Vous devez maintenant configurer le fichier .env"
warn "    Connexion au serveur pour éditer .env..."

if [ "$ON_SERVER" = false ]; then
  echo ""
  echo "Ouvrir un terminal SSH et exécuter:"
  echo ""
  echo "  ssh -p $SERVER_PORT $SERVER_USER@$SERVER_HOST"
  echo "  cd $INSTALL_DIR"
  echo "  cp .env.example .env"
  echo "  nano .env"
  echo ""
  echo "Remplir TOUS les secrets (voir DEPLOIEMENT-SERVEUR.md)"
  echo ""
  echo "Appuyer sur Entrée quand c'est fait..."
  read -r
else
  echo ""
  echo "Copie de .env.example → .env"
  cd "$INSTALL_DIR"
  cp .env.example .env

  echo ""
  echo "Éditer le fichier .env maintenant:"
  echo "  nano .env"
  echo ""
  echo "Remplir TOUS les secrets puis sauvegarder (Ctrl+X)"
  echo ""
  read -p "Appuyer sur Entrée pour ouvrir l'éditeur..."
  nano .env
fi

log ".env configuré"

# ── Étape 6 : Adapter docker-compose si Gitea externe ──────
info "Configuration Docker Compose pour Gitea existant..."

run_on_server "
  cd '$INSTALL_DIR'

  # Vérifier si Gitea tourne déjà
  if docker ps | grep -q gitea || curl -s http://localhost:3000 >/dev/null 2>&1; then
    echo 'Gitea détecté - configuration pour Gitea externe'

    # Commenter le service gitea dans docker-compose.yml
    sed -i '/^  gitea:/,/^  [a-z]/s/^/# /' docker/docker-compose.yml || true

    # Modifier GITEA_URL pour pointer vers localhost
    sed -i 's|GITEA_URL: http://gitea:3000|GITEA_URL: http://host.docker.internal:3000|' docker/docker-compose.yml

    echo 'Docker Compose adapté pour Gitea externe'
  else
    echo 'Gitea non détecté - utilisation du Gitea dans Docker Compose'
  fi
"

log "Docker Compose configuré"

# ── Étape 7 : Démarrer les services ─────────────────────────
info "Démarrage des services Docker..."

run_on_server "
  cd '$INSTALL_DIR'
  docker compose -f docker/docker-compose.yml up -d
"

log "Services démarrés"

# ── Étape 8 : Attendre que tout soit prêt ───────────────────
info "Attente du démarrage complet (peut prendre 2-3 minutes)..."

run_on_server "
  cd '$INSTALL_DIR'

  echo 'Attente PostgreSQL...'
  timeout 60 bash -c 'until docker exec postgres pg_isready -U admin 2>/dev/null; do sleep 2; done'

  echo 'Attente Redis...'
  timeout 60 bash -c 'until docker exec redis redis-cli ping 2>/dev/null | grep -q PONG; do sleep 2; done'

  echo 'Attente Mem0 (peut prendre 2 min)...'
  timeout 180 bash -c 'until curl -sf http://localhost:8050/health >/dev/null 2>&1; do sleep 5; done'

  echo 'Attente Paperclip...'
  timeout 60 bash -c 'until curl -sf http://localhost:3100 >/dev/null 2>&1; do sleep 3; done'
"

log "Tous les services sont UP"

# ── Étape 9 : Bootstrap Paperclip ───────────────────────────
info "Bootstrap Paperclip..."

run_on_server "
  cd '$INSTALL_DIR'
  chmod +x scripts/bootstrap-paperclip.sh
  ./scripts/bootstrap-paperclip.sh
"

log "Paperclip initialisé"

# ── Étape 10 : Injection des agents ─────────────────────────
info "Injection des agents et prompts..."

run_on_server "
  cd '$INSTALL_DIR'
  chmod +x scripts/inject-agents.sh
  ./scripts/inject-agents.sh
"

log "Agents injectés (16 agents)"

# ── Étape 11 : Configuration Dokploy ────────────────────────
info "Configuration Dokploy..."

warn "⚠️  Génération du token Dokploy requise"
echo ""
echo "1. Ouvrir Dokploy: https://dokploy.votre-domaine.com"
echo "2. Settings > API Tokens > Create New Token"
echo "3. Copier le token"
echo ""

if [ "$ON_SERVER" = false ]; then
  echo "4. SSH sur le serveur:"
  echo "   ssh -p $SERVER_PORT $SERVER_USER@$SERVER_HOST"
  echo "   cd $INSTALL_DIR"
  echo "   nano .env"
  echo "   # Ajouter: DOKPLOY_API_TOKEN=votre_token"
  echo ""
else
  echo "4. Ajouter le token dans .env:"
  read -p "Token Dokploy: " DOKPLOY_TOKEN
  if [ -n "$DOKPLOY_TOKEN" ]; then
    cd "$INSTALL_DIR"
    echo "DOKPLOY_API_TOKEN=$DOKPLOY_TOKEN" >> .env
    log "Token Dokploy ajouté"
  fi
fi

# ── Étape 12 : Rendre les scripts exécutables ───────────────
run_on_server "
  cd '$INSTALL_DIR'
  chmod +x scripts/*.sh
"

log "Scripts configurés"

# ── INSTALLATION TERMINÉE ────────────────────────────────────
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║            INSTALLATION TERMINÉE ✓                 ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
log "Stack installée dans: $INSTALL_DIR"
log "Services accessibles:"
echo ""
echo "  📦 Paperclip    → http://$SERVER_HOST:3100"
echo "  🗄️  PostgreSQL  → $SERVER_HOST:5432"
echo "  🧠 Mem0         → http://$SERVER_HOST:8050"
echo "  🔍 Chroma       → http://$SERVER_HOST:8000"
echo ""
echo "Credentials Paperclip (voir .env):"
run_on_server "grep PAPERCLIP_ADMIN_EMAIL '$INSTALL_DIR/.env'"
echo ""
echo "──────────────────────────────────────────────────────"
echo "Prochaines étapes:"
echo ""
echo "1. Créer un tunnel SSH pour accéder à Paperclip:"
echo "   ssh -p $SERVER_PORT -L 3100:localhost:3100 $SERVER_USER@$SERVER_HOST"
echo "   Puis ouvrir: http://localhost:3100"
echo ""
echo "2. Tester le workflow preview:"
echo "   ssh -p $SERVER_PORT $SERVER_USER@$SERVER_HOST"
echo "   cd $INSTALL_DIR"
echo "   ./scripts/agent-control.sh wake ceo"
echo ""
echo "3. Configurer les webhooks Gitea (voir DEPLOIEMENT-SERVEUR.md)"
echo ""
echo "Documentation complète:"
echo "  - DEPLOIEMENT-SERVEUR.md"
echo "  - MIGRATION-ENTREPRISE.md"
echo "  - CLAUDE.md"
echo ""
