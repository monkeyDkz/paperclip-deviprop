#!/bin/bash
# ============================================================
# CONNEXION RAPIDE AU SERVEUR ENTREPRISE
# ============================================================
# Usage:
#   ./connect-server.sh              # SSH standard
#   ./connect-server.sh tunnel       # SSH avec tunnel Paperclip
#   ./connect-server.sh logs         # Voir les logs en temps réel
#   ./connect-server.sh restart      # Redémarrer les services
# ============================================================

SERVER_USER="admin1"
SERVER_HOST="192.168.94.96"
SERVER_PORT="55184"
INSTALL_DIR="/opt/paperclip-stack"

MODE="${1:-ssh}"

case "$MODE" in
  tunnel)
    echo "🔗 Création tunnel SSH pour Paperclip UI..."
    echo "   Paperclip sera accessible sur: http://localhost:3100"
    echo ""
    ssh -p "$SERVER_PORT" -L 3100:localhost:3100 "$SERVER_USER@$SERVER_HOST"
    ;;

  logs)
    echo "📋 Logs des services Paperclip..."
    ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "cd $INSTALL_DIR && docker compose -f docker/docker-compose.yml logs -f"
    ;;

  restart)
    echo "🔄 Redémarrage des services..."
    ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "cd $INSTALL_DIR && docker compose -f docker/docker-compose.yml restart"
    echo "✓ Services redémarrés"
    ;;

  stop)
    echo "⏸️  Arrêt des services..."
    ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "cd $INSTALL_DIR && docker compose -f docker/docker-compose.yml down"
    echo "✓ Services arrêtés"
    ;;

  start)
    echo "▶️  Démarrage des services..."
    ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "cd $INSTALL_DIR && docker compose -f docker/docker-compose.yml up -d"
    echo "✓ Services démarrés"
    ;;

  status)
    echo "📊 État des services..."
    ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "cd $INSTALL_DIR && docker compose -f docker/docker-compose.yml ps"
    ;;

  update)
    echo "⬆️  Mise à jour depuis GitHub..."
    ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "cd $INSTALL_DIR && git pull && ./scripts/inject-agents.sh"
    echo "✓ Mise à jour terminée"
    ;;

  ssh|*)
    echo "🖥️  Connexion SSH au serveur..."
    ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "cd $INSTALL_DIR && bash"
    ;;
esac
