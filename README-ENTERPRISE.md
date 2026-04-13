# Stack Paperclip - Enterprise Edition

Multi-agent AI orchestration system for enterprise workflows with Dokploy preview deployments, human-validated merges, and autonomous project delivery.

## 🎯 Enterprise Edition vs Personal Stack

| Feature | Personal Stack | Enterprise Edition |
|---------|---------------|-------------------|
| **PR Merge** | CTO auto-merge | ❌ Human approval required |
| **Preview Deploys** | None | ✅ Automatic Dokploy preview per PR |
| **Validation** | CTO decides | ✅ CTO reviews + Human validates preview + merges |
| **Cleanup** | Manual | ✅ Automatic preview cleanup on merge |
| **Target** | Local dev (Mac) | Dedicated server |

## 🚀 Quick Start

### Prerequisites

Your dedicated server must have:
- ✅ Docker & Docker Compose
- ✅ Git
- ✅ Dokploy (already installed)
- ✅ Gitea (already installed)
- ✅ Playwright (already installed)

### Installation

From your local machine:

```bash
# 1. Clone this repo
git clone https://github.com/YOUR-USERNAME/Stack-Paperclip-Enterprise.git
cd Stack-Paperclip-Enterprise

# 2. Make install script executable
chmod +x install-on-server.sh connect-server.sh

# 3. Install on server (interactive)
./install-on-server.sh
```

The installer will:
1. ✅ Connect to your server via SSH
2. ✅ Install everything in `/opt/paperclip-stack`
3. ✅ Configure environment variables
4. ✅ Start all services
5. ✅ Bootstrap Paperclip
6. ✅ Inject 16 agents with prompts

### Access Paperclip UI

```bash
# Create SSH tunnel
./connect-server.sh tunnel

# Open in browser
http://localhost:3100

# Login with credentials from .env
```

## 📋 Workflow

### 1. Human creates mission

In Paperclip UI:
- Create issue
- Assign to CEO
- Provide description

### 2. CEO orchestrates

CEO agent:
- Reads mission
- Decomposes into tasks
- Assigns to specialized agents
- Tracks progress

### 3. Agents work

Lead Frontend/Backend:
- Clone repo
- Create feature branch
- Code the feature
- Push + create PR on Gitea

### 4. DevOps deploys preview

Automatically on PR creation:
- Triggers Dokploy webhook
- Deploys branch as preview
- Comments preview URL on PR

### 5. CTO reviews

CTO agent:
- Reads PR diff
- Checks preview URL
- Approves (WITHOUT merging)
- Comments "Ready for human merge"

### 6. Human validates & merges

Developer:
- Opens PR on Gitea
- Clicks preview URL
- Validates changes visually
- Clicks "Merge" if satisfied

### 7. Auto cleanup

On merge:
- Gitea webhook triggered
- Preview service deleted from Dokploy
- No orphan services

## 🛠️ Common Commands

```bash
# Connect to server
./connect-server.sh

# Create tunnel for Paperclip UI
./connect-server.sh tunnel

# View logs
./connect-server.sh logs

# Restart services
./connect-server.sh restart

# Stop services
./connect-server.sh stop

# Start services
./connect-server.sh start

# Check service status
./connect-server.sh status

# Update from GitHub
./connect-server.sh update
```

## 📁 Project Structure

```
Stack-Paperclip-Enterprise/
├── agents/
│   ├── prompts/              # Agent prompts (modified for enterprise)
│   │   ├── cto.txt           # Reviews but NO merge
│   │   ├── devops.txt        # Triggers Dokploy preview
│   │   └── ...
│   ├── playbooks/            # Agent role documentation
│   └── agents.json           # Agent manifest
├── docker/
│   └── docker-compose.yml    # Full stack definition
├── scripts/
│   ├── install-on-server.sh  # Auto-installer
│   ├── connect-server.sh     # SSH helper
│   ├── bootstrap-paperclip.sh
│   ├── inject-agents.sh
│   ├── dokploy-preview-webhook.sh
│   └── dokploy-preview-cleanup.sh
├── .env.example              # Environment template
├── CLAUDE.md                 # For Claude Code AI assistant
├── MIGRATION-ENTREPRISE.md   # Migration guide
├── DEPLOIEMENT-SERVEUR.md    # Detailed deployment guide
└── README-ENTERPRISE.md      # This file
```

## 🔧 Configuration

All configuration is in `.env`:

```bash
# PostgreSQL
POSTGRES_ADMIN_USER=admin
POSTGRES_ADMIN_PASSWORD=<generate>

# Redis
REDIS_PASSWORD=<generate>

# Gitea (use existing values)
GITEA_SECRET_KEY=<from existing Gitea>
GITEA_INTERNAL_TOKEN=<from existing Gitea>
GITEA_API_TOKEN=<create in Gitea UI>

# Paperclip
PAPERCLIP_ADMIN_EMAIL=admin@company.com
PAPERCLIP_ADMIN_PASSWORD=<strong password>
PAPERCLIP_AUTH_SECRET=<generate>
PAPERCLIP_AGENT_JWT_SECRET=<generate>

# Dokploy (NEW)
DOKPLOY_API_URL=https://dokploy.company.com
DOKPLOY_API_TOKEN=<generate in Dokploy UI>
DOKPLOY_WEBHOOK_URL=https://webhook.company.com
DOKPLOY_DOMAIN=company.com

# Claude API
ANTHROPIC_API_KEY=sk-ant-...
```

## 📖 Documentation

- **[DEPLOIEMENT-SERVEUR.md](DEPLOIEMENT-SERVEUR.md)** - Complete deployment guide
- **[MIGRATION-ENTREPRISE.md](MIGRATION-ENTREPRISE.md)** - Migration from personal stack
- **[CLAUDE.md](CLAUDE.md)** - Architecture & commands for Claude Code AI
- **[agents/playbooks/](agents/playbooks/)** - Detailed agent roles & protocols

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│           Dedicated Enterprise Server            │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │  Gitea    │  │ Dokploy  │  │Playwright│      │
│  │  :3000   │  │ (preview)│  │  :3333   │      │
│  └────┬─────┘  └────┬─────┘  └──────────┘      │
│       │             │                            │
│  ┌────┴─────────────┴────┐                      │
│  │     Paperclip          │                      │
│  │  ┌──────┐  ┌──────┐   │                      │
│  │  │ CEO  │→│ CTO  │   │  16 Specialized      │
│  │  └──────┘  └──┬───┘   │  Agents              │
│  │              ↓         │  (Opus, Sonnet,      │
│  │         ┌──────┐       │   Haiku)             │
│  │         │ Devs │       │                      │
│  │         └──────┘       │                      │
│  │                        │                      │
│  │  PostgreSQL + Redis    │                      │
│  │  Mem0 + Chroma         │                      │
│  └────────────────────────┘                      │
│                                                  │
│  Workflow:                                       │
│  Agent → PR → Preview Deploy → CTO Review →     │
│  HUMAN MERGE                                     │
└─────────────────────────────────────────────────┘
```

## 🔐 Security

- All secrets in `.env` (not committed)
- JWT authentication for agents
- PostgreSQL with password
- Redis with password
- Dokploy API token
- Gitea API token

**Never commit `.env` to Git!**

## 🧪 Testing

Test the full workflow:

```bash
# 1. SSH to server
./connect-server.sh

# 2. Create test mission in Paperclip UI

# 3. Wake CEO
cd /opt/paperclip-stack
./scripts/agent-control.sh wake ceo

# 4. Monitor
./scripts/agent-control.sh status ceo

# Expected flow:
# CEO → creates tasks → wakes Lead Frontend
# Lead Frontend → codes → creates PR
# DevOps → deploys preview → comments URL
# CTO → reviews → approves (no merge)
# YOU → check preview → merge on Gitea
# Cleanup → preview deleted automatically
```

## 🆘 Troubleshooting

### Services won't start

```bash
./connect-server.sh
cd /opt/paperclip-stack
docker compose -f docker/docker-compose.yml logs
```

### Can't access Paperclip UI

```bash
# Check if tunnel is active
./connect-server.sh tunnel

# Or check directly on server
curl http://localhost:3100
```

### Preview deployment fails

```bash
# Check Dokploy token
grep DOKPLOY_API_TOKEN /opt/paperclip-stack/.env

# Test webhook manually
./scripts/dokploy-preview-webhook.sh test-repo feature/test 1
```

### CTO still tries to merge

```bash
# Re-inject agents
./connect-server.sh
cd /opt/paperclip-stack
./scripts/inject-agents.sh

# Check CTO prompt contains "Tu NE merges JAMAIS"
```

## 🔄 Updates

```bash
# Pull latest changes from GitHub
./connect-server.sh update

# Or manually:
./connect-server.sh
cd /opt/paperclip-stack
git pull
./scripts/inject-agents.sh
docker compose -f docker/docker-compose.yml restart paperclip
```

## 📊 Monitoring

```bash
# View all logs
./connect-server.sh logs

# View specific service
./connect-server.sh
docker logs -f paperclip

# Check service health
./connect-server.sh status

# Check active preview deployments
curl -X GET "$DOKPLOY_API_URL/api/application?labels.type=preview" \
  -H "Authorization: Bearer $DOKPLOY_API_TOKEN"
```

## 🤝 Contributing

This is an enterprise-specific fork. For personal use, see the original repo.

## 📄 License

[Your License]

## 🙏 Credits

Built on top of:
- [Paperclip](https://paperclip.ing) - Agent orchestration
- [Claude API](https://anthropic.com) - LLM models
- [Dokploy](https://dokploy.com) - Deployment platform
- [Gitea](https://gitea.io) - Git hosting

---

**Stack Paperclip Enterprise** - Autonomous multi-agent development with human oversight
