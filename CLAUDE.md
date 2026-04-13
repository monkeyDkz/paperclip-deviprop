# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Paperclip Stack is a multi-agent AI orchestration system where a CEO agent receives missions and autonomously coordinates 17 specialized agents to deliver complete projects. Built on Paperclip + Claude API + Gitea, with full Git workflow, PR reviews, and quality gates.

## Essential Commands

### Start/Stop Stack

```bash
# Start all services
docker compose -f docker/docker-compose.yml up -d

# Stop all services
docker compose -f docker/docker-compose.yml down

# View logs
docker compose -f docker/docker-compose.yml logs -f [service-name]
```

### Bootstrap System

```bash
# 1. Setup environment variables
cp .env.example .env
# Edit .env with required secrets (see .env.example comments)

# 2. Bootstrap Paperclip
./scripts/bootstrap-paperclip.sh

# 3. Inject agents (loads prompts + assigns models)
./scripts/inject-agents.sh
```

### Agent Operations

```bash
# Wake an agent manually
./scripts/agent-control.sh wake [agent-slug]

# Check agent status
./scripts/agent-control.sh status [agent-slug]

# Run orchestrator (sequential agent waking)
./scripts/agent-orchestrator.sh wake ceo
```

## Architecture

### Multi-Agent Hierarchy

```
CEO (Opus) ─ orchestrates phases, delegates to specialists
├── CTO (Opus) ─ architecture, PR review + merge
├── CPO (Haiku) ─ product specs
├── CFO (Sonnet) ─ budget tracking
├── Designer (Haiku) ─ design system
├── Lead Frontend (Sonnet) ─ UI implementation
├── Lead Backend (Sonnet) ─ API implementation
├── DevOps (Sonnet) ─ Docker, CI/CD, deployment
├── Security (Haiku) ─ security audits
├── QA (Haiku) ─ testing, Lighthouse
├── SEO (Haiku) ─ meta tags, structured data
├── Content Writer (Haiku) ─ copywriting
├── Growth Lead (Sonnet) ─ marketing strategy
├── Data Analyst (Sonnet) ─ analytics
├── Sales (Haiku) ─ sales automation
├── Researcher (Sonnet) ─ research & knowledge management
└── Scraper (Haiku) ─ web scraping
```

### Model Assignments

- **Opus 4.6**: CEO, CTO (strategy & deep reasoning)
- **Sonnet 4.6**: Lead Backend, Lead Frontend, DevOps, CFO, Researcher, Data Analyst, Growth Lead (code, coordination, analysis)
- **Haiku 4.5**: CPO, Security, QA, Designer, SEO, Content Writer, Sales, Scraper (execution, structured tasks)

### Service Ports

| Service | Port | Purpose |
|---------|------|---------|
| Paperclip | 3100 | Agent orchestration UI + API |
| Gitea | 3000 | Git hosting + Pull Requests |
| PostgreSQL | 5432 | Shared database |
| Redis | 6379 | Cache + queues |
| Mem0 | 8050 | Agent persistent memory |
| Chroma | 8000 | Vector embeddings |
| Playwright | 3333 | Browser automation API |
| Firecrawl Playwright | 3000 (internal) | Web scraping service |

## Agent Communication Protocol

Agents follow strict communication rules defined in `agents/playbooks/23-agent-communication-protocol.md`:

### 4 Communication Channels

1. **Paperclip Issues** - Formal task delegation (checkout, release, comments)
2. **Mem0 Memories** - Persistent knowledge sharing (decisions, conventions, learnings)
3. **SiYuan Docs** - Structured long-term documentation (specs, guidelines, reports)
4. **n8n Webhooks** - Event-driven notifications (deploy, alerts, CRM updates)

### Memory Visibility Matrix

Each agent reads memories from specific `user_id` namespaces:
- CEO reads: `cto`, `cpo`, `cfo`, `monitoring`, `analytics`, `crm`
- CTO reads: `ceo`, `lead-backend`, `lead-frontend`, `devops`, `security`, `qa`, `monitoring`, `deployments`, `git-events`
- Lead Backend reads: `cto`, `lead-frontend`, `qa`, `monitoring`, `git-events`
- Lead Frontend reads: `cto`, `lead-backend`, `designer`, `qa`, `monitoring`, `git-events`

See full matrix in `agents/playbooks/23-agent-communication-protocol.md`.

### 5-Step Delegation Protocol

1. **Search Context** - Query Mem0 for existing knowledge
2. **Create Task** - Paperclip issue with context + acceptance criteria
3. **Checkout** - Assignee loads context memories
4. **Execute & Deliver** - Work + save learnings to Mem0
5. **Validate** - Requester reviews against acceptance criteria

## Project File Structure

```
paperclip-stack/
├── docker/
│   ├── docker-compose.yml      # Full stack definition
│   └── init-admin.sh           # Paperclip admin bootstrap
├── configs/
│   ├── mem0/                   # Memory service config
│   │   ├── config.yaml
│   │   └── Dockerfile
│   └── postgres/               # DB initialization
│       └── init-db.sh
├── agents/
│   ├── agents.json             # Agent manifest (name, model, prompt file)
│   ├── prompts/                # Live agent prompts (v3)
│   │   ├── ceo.txt
│   │   ├── cto.txt
│   │   └── ...
│   └── playbooks/              # Agent role documentation
│       ├── 01-ceo.md
│       ├── 02-cto.md
│       ├── 23-agent-communication-protocol.md
│       ├── 24-workflow-execution-framework.md
│       └── ...
├── scripts/
│   ├── bootstrap-paperclip.sh  # Full system setup
│   ├── inject-agents.sh        # Load prompts + assign models
│   ├── agent-orchestrator.sh   # Sequential agent waking daemon
│   ├── agent-control.sh        # Manual agent operations
│   └── ...
├── tools/
│   ├── refresh-claude-credentials  # OAuth token refresh
│   ├── com.stack.claude-refresh.plist  # LaunchAgent (macOS)
│   └── playwright-api.js       # Playwright HTTP API
├── .env.example                # Environment template
└── BILAN-ET-PLAN.md           # Current status + improvement plan
```

## Key Workflows

### Standard Mission Pipeline

```
Mission → CEO
  ├── Phase 1: CTO (repo setup) + CPO (specs) + Designer (design system)
  ├── Phase 2: Content Writer + SEO
  ├── Phase 3: Lead Frontend (branch → PR) + Lead Backend (branch → PR)
  │             └── CTO reviews + merges PRs
  ├── Phase 4: QA + Security + DevOps
  └── Phase 5: CEO validation + close
```

### Git Workflow Rules

- All agents work on branches (never commit to main)
- Each agent creates PRs for their work
- CTO reviews and merges all PRs
- Agents notify @CEO on parent task when done

### Rate Limit Management

All agents share one Claude subscription. CEO orchestrates to avoid rate limits:
- Wakes max 2 agents at a time
- Waits for completion before waking next
- Agents set status to `in_progress` (not blocked) on rate limit

## Development Practices

### When Modifying Agent Prompts

1. Edit the prompt file in `agents/prompts/[agent-slug].txt`
2. Update corresponding playbook in `agents/playbooks/` if needed
3. Update `prompt_length` in `agents/agents.json`
4. Re-inject using `./scripts/inject-agents.sh`

### When Adding a New Agent

1. Create prompt file in `agents/prompts/`
2. Create playbook in `agents/playbooks/`
3. Add entry to `agents/agents.json` with name, slug, model, prompt_file
4. Update `scripts/inject-agents.sh` to inject the new agent
5. Update communication matrix in `agents/playbooks/23-agent-communication-protocol.md`

### Environment Variables

Required secrets in `.env`:
- `POSTGRES_ADMIN_PASSWORD` - PostgreSQL admin password
- `REDIS_PASSWORD` - Redis authentication
- `GITEA_SECRET_KEY`, `GITEA_INTERNAL_TOKEN` - Gitea security
- `GITEA_API_TOKEN` - Generated in Gitea UI after bootstrap
- `PAPERCLIP_AUTH_SECRET`, `PAPERCLIP_AGENT_JWT_SECRET` - Paperclip security
- `PAPERCLIP_ADMIN_PASSWORD` - Admin login credentials
- `ANTHROPIC_API_KEY` - (Optional) If using Anthropic embeddings in Mem0

### Docker Networking

Services communicate via:
- Bridge network: `stack-network`
- Paperclip accesses host services: `host.docker.internal:port`
- Volume mounts: `~/.claude-config` mounted into Paperclip container

## Important Constraints

### Memory Protocol v2

All agents must follow metadata rules when writing to Mem0:
- **Required fields**: `type`, `project`, `state`, `confidence`
- **Lifecycle states**: `active` → `deprecated` → `archived`
- **Confidence levels**: `hypothesis` → `tested` → `validated`
- **Deduplication**: Use `deduplicate: true` (server-side cosine > 0.92)

See `agents/playbooks/13-memory-protocol.md` for full specification.

### Anti-Patterns to Avoid

1. **Direct agent-to-agent communication** - Always use Paperclip issues
2. **Memory pollution** - Only save decisions, learnings, conventions (not intermediate state)
3. **Silent failures** - Always save a learning when a task fails
4. **Premature escalation** - Try at least one solution before escalating
5. **Task duplication** - Search Mem0 + Paperclip issues before creating new tasks

### SLAs & Timeouts

- Simple task: < 2 heartbeat cycles
- Complex task: < 5 heartbeat cycles
- Security incident: Immediate escalation
- Task > 24h inactive: Automatic CEO notification

## Known Issues & Current Status

See `BILAN-ET-PLAN.md` for:
- What works: Infrastructure stable, CEO delegation works, tool calling functional
- What doesn't work: SiYuan integration not yet end-to-end tested, occasional issue duplication
- Improvement sprints: Stabilization, robustness, scaling, optimization

## API Endpoints

### Paperclip (port 3100)

```bash
# Login
POST /api/auth/sign-in/email
Body: {"email": "...", "password": "..."}

# List agents
GET /api/companies/{companyId}/agents

# Wake agent
POST /api/agents/{agentId}/wake

# Create issue
POST /api/issues
Body: {"title": "...", "description": "...", "assignee": "..."}
```

### Mem0 (port 8050)

```bash
# Add memory
POST /memories
Body: {"text": "...", "user_id": "...", "metadata": {...}}

# Search memories
POST /memories/search
Body: {"query": "...", "user_id": "...", "limit": 10}

# Multi-agent search
POST /search/multi
Body: {"query": "...", "user_ids": ["ceo", "cto"], "limit": 10}
```

See `agents/playbooks/12-memory-api-reference.md` for complete API reference.

## Troubleshooting

### Paperclip container not starting

```bash
# Check logs
docker logs paperclip

# Verify PostgreSQL is ready
docker exec postgres pg_isready -U admin

# Re-run bootstrap
./scripts/bootstrap-paperclip.sh
```

### Agent stuck in "running" status

```bash
# Reset agent status
./scripts/agent-control.sh reset [agent-slug]
```

### Mem0 connection issues

```bash
# Check Mem0 health
curl http://localhost:8050/health

# Check Chroma dependency
docker logs chroma
```

## Claude Code Skills Integration

Designer uses:
- `/ui-ux-pro-max` - Design system foundation
- `/frontend-design` - Creative direction
- `/design-taste-frontend` - Anti-generic audit

Lead Frontend uses:
- `/frontend-design` - Page implementation
- `/redesign-existing-projects` - 20-point audit before PR

See `README.md` for full skill catalog.
