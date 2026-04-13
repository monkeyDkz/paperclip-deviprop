# Création du repo GitHub "Stack-Paperclip-Enterprise"

Guide pour créer un nouveau repository GitHub pour la version entreprise de votre stack.

## Étape 1 : Préparer les fichiers

### 1.1 Nettoyer les fichiers inutiles pour l'entreprise

Supprimer les fichiers spécifiques à votre stack personnelle:

```bash
cd Stack-paperclip

# Supprimer les anciens playbooks/prompts legacy (si pas utilisés)
rm -rf agents/prompts-legacy/  # Optionnel

# Supprimer le repo cloné Paperclip (si présent)
rm -rf paperclip-repo/

# Supprimer vos configs Claude personnelles
rm -rf .claude/
rm -rf opencode-personal/

# Supprimer les données Docker (ne pas versionner)
rm -rf postgres_data/ redis_data/ gitea_data/ chroma_data/ mem0_data/ paperclip_data/

# Supprimer les logs et backups
rm -rf logs/ backups/ *.log

# Supprimer votre .env (ne JAMAIS commit les secrets!)
rm .env
```

### 1.2 Vérifier que .gitignore est bien configuré

```bash
cat .gitignore

# Doit contenir au minimum:
# .env
# .env.local
# *.secret
# .claude/
# paperclip-repo/
# etc.
```

### 1.3 Renommer README principal

```bash
# Garder le README existant comme référence
mv README.md README-ORIGINAL.md

# Utiliser le README Enterprise comme principal
cp README-ENTERPRISE.md README.md
```

## Étape 2 : Créer le repository GitHub

### 2.1 Via l'interface GitHub

1. Aller sur https://github.com/new
2. Repository name: **Stack-Paperclip-Enterprise**
3. Description: "Multi-agent AI orchestration system for enterprise with Dokploy preview deployments and human-validated merges"
4. Visibility: **Private** (recommandé pour entreprise)
5. ❌ **NE PAS** initialiser avec README/gitignore/license (on a déjà)
6. Cliquer "Create repository"

### 2.2 Via GitHub CLI (optionnel)

```bash
# Installer gh si pas déjà fait
brew install gh  # macOS
# ou apt install gh  # Linux

# Login
gh auth login

# Créer le repo
gh repo create Stack-Paperclip-Enterprise \
  --private \
  --description "Multi-agent AI orchestration for enterprise" \
  --source=. \
  --remote=origin \
  --push
```

## Étape 3 : Initialiser Git et pousser

### 3.1 Si vous n'avez pas encore initialisé Git

```bash
cd Stack-paperclip

# Initialiser Git
git init

# Ajouter tous les fichiers (sauf ceux dans .gitignore)
git add .

# Premier commit
git commit -m "Initial commit: Stack Paperclip Enterprise Edition

- Modified CTO prompt: no auto-merge, human validation required
- Modified DevOps prompt: automatic Dokploy preview deployment
- Added dokploy-preview-webhook.sh and cleanup scripts
- Added enterprise deployment guides
- 16 agents with Claude API (Opus, Sonnet, Haiku)
- Full workflow: Agent → PR → Preview → CTO Review → Human Merge"

# Ajouter le remote GitHub
git remote add origin https://github.com/VOTRE-USERNAME/Stack-Paperclip-Enterprise.git

# Pousser sur GitHub
git branch -M main
git push -u origin main
```

### 3.2 Si vous avez déjà un repo Git local

```bash
cd Stack-paperclip

# Vérifier qu'on est pas lié à l'ancien repo
git remote -v

# Si c'est lié à votre stack perso, supprimer le remote
git remote remove origin

# Ajouter le nouveau remote
git remote add origin https://github.com/VOTRE-USERNAME/Stack-Paperclip-Enterprise.git

# Pousser
git push -u origin main
```

## Étape 4 : Configurer le repository GitHub

### 4.1 Ajouter des secrets GitHub (pour CI/CD futur)

Settings > Secrets and variables > Actions > New repository secret:

- `SERVER_HOST` = 192.168.94.96
- `SERVER_PORT` = 55184
- `SERVER_USER` = admin1
- `DOKPLOY_API_TOKEN` = (votre token)
- `PAPERCLIP_ADMIN_PASSWORD` = (votre password)

### 4.2 Protéger la branche main

Settings > Branches > Add branch protection rule:

- Branch name pattern: `main`
- ✅ Require pull request reviews before merging
- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging
- ✅ Do not allow bypassing the above settings

### 4.3 Ajouter des topics

Settings > Topics (en haut):

- `ai-agents`
- `multi-agent`
- `paperclip`
- `claude-ai`
- `dokploy`
- `gitea`
- `devops`
- `enterprise`

## Étape 5 : Créer des releases

### 5.1 Première release

```bash
# Créer un tag
git tag -a v1.0.0 -m "Version 1.0.0 - Enterprise Edition

Features:
- Dokploy preview deployments
- Human-validated merges (no auto-merge)
- 16 specialized agents
- CEO orchestration
- Automatic cleanup
"

# Pousser le tag
git push origin v1.0.0
```

### 5.2 Via GitHub UI

1. Aller sur le repo GitHub
2. Releases > Create a new release
3. Tag version: `v1.0.0`
4. Title: "Enterprise Edition v1.0.0"
5. Description:
   ```markdown
   ## Stack Paperclip - Enterprise Edition v1.0.0

   First release of the enterprise edition with Dokploy preview deployments and human-validated merges.

   ### 🎯 Key Features

   - ✅ Automatic preview deployment on every PR
   - ✅ CTO review without auto-merge
   - ✅ Human validation required
   - ✅ Automatic preview cleanup on merge
   - ✅ 16 specialized AI agents
   - ✅ CEO autonomous orchestration

   ### 📦 What's Included

   - Modified agent prompts (CTO, DevOps)
   - Dokploy webhook scripts
   - Complete deployment guides
   - SSH helper scripts
   - Docker Compose stack

   ### 📖 Documentation

   - [Deployment Guide](DEPLOIEMENT-SERVEUR.md)
   - [Migration Guide](MIGRATION-ENTREPRISE.md)
   - [Architecture](CLAUDE.md)

   ### 🚀 Quick Start

   ```bash
   git clone https://github.com/YOUR-USERNAME/Stack-Paperclip-Enterprise.git
   cd Stack-Paperclip-Enterprise
   chmod +x install-on-server.sh
   ./install-on-server.sh
   ```
   ```
6. Publish release

## Étape 6 : Mettre à jour l'installation script

Modifier `install-on-server.sh` ligne 59 pour pointer vers votre repo:

```bash
# Avant
GITHUB_REPO="${GITHUB_REPO:-https://github.com/VOTRE-USER/Stack-Paperclip-Enterprise.git}"

# Après (remplacer VOTRE-USER)
GITHUB_REPO="${GITHUB_REPO:-https://github.com/votreusername/Stack-Paperclip-Enterprise.git}"
```

Commit et push:

```bash
git add install-on-server.sh
git commit -m "Update repo URL in install script"
git push
```

## Étape 7 : Tester l'installation depuis GitHub

Sur votre serveur ou une machine test:

```bash
# Télécharger et lancer l'installer directement depuis GitHub
curl -sSL https://raw.githubusercontent.com/VOTRE-USER/Stack-Paperclip-Enterprise/main/install-on-server.sh | bash

# Ou cloner puis installer
git clone https://github.com/VOTRE-USER/Stack-Paperclip-Enterprise.git
cd Stack-Paperclip-Enterprise
chmod +x install-on-server.sh connect-server.sh
./install-on-server.sh
```

## Étape 8 : Documentation README.md

Vérifier que le README principal est bien configuré:

```bash
cat README.md

# Doit contenir:
# - Badge du repo
# - Description claire
# - Quick start
# - Architecture diagram
# - Workflow explanation
# - Links to docs
```

Optionnel - Ajouter un badge au README:

```markdown
# Stack Paperclip - Enterprise Edition

[![GitHub release](https://img.shields.io/github/release/VOTRE-USER/Stack-Paperclip-Enterprise.svg)](https://github.com/VOTRE-USER/Stack-Paperclip-Enterprise/releases)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
```

## Étape 9 : Workflow de développement

### 9.1 Créer une branche pour les changements

```bash
# Créer une branche feature
git checkout -b feature/nom-de-la-feature

# Faire vos modifications
# ...

# Commit
git add .
git commit -m "feat: description du changement"

# Pousser
git push origin feature/nom-de-la-feature

# Créer une PR sur GitHub
gh pr create --title "Feature: ..." --body "Description..."
```

### 9.2 Conventional Commits

Utiliser les préfixes standard:

- `feat:` nouvelle fonctionnalité
- `fix:` correction de bug
- `docs:` documentation
- `chore:` tâches maintenance
- `refactor:` refactoring
- `test:` ajout/modification tests

## Étape 10 : Partager avec l'équipe

### 10.1 Ajouter des collaborateurs

Settings > Collaborators > Add people

### 10.2 Créer un wiki (optionnel)

Wiki > Create the first page:

- Installation guide
- FAQ
- Troubleshooting
- Best practices

### 10.3 Créer des Issues templates

Settings > Features > Issues > Set up templates:

**Bug Report:**
```markdown
**Description**
A clear description of the bug

**Steps to Reproduce**
1. Step 1
2. Step 2

**Expected Behavior**

**Actual Behavior**

**Environment**
- Server OS:
- Docker version:
- Stack version:
```

**Feature Request:**
```markdown
**Feature Description**

**Use Case**

**Proposed Solution**

**Alternatives Considered**
```

## Récapitulatif

Vous avez maintenant:

✅ Un repo GitHub `Stack-Paperclip-Enterprise` privé
✅ Tous les fichiers versionnés sauf secrets
✅ Un .gitignore propre
✅ Un README professionnel
✅ Une release v1.0.0
✅ Un script d'installation qui pointe vers GitHub
✅ Une branche main protégée
✅ Des templates d'issues

## Prochaines étapes

1. **Installer sur le serveur:**
   ```bash
   ssh -p 55184 admin1@192.168.94.96
   curl -sSL https://raw.githubusercontent.com/VOTRE-USER/Stack-Paperclip-Enterprise/main/install-on-server.sh | bash
   ```

2. **Tester le workflow complet**

3. **Documenter les spécificités de votre entreprise**

4. **Former l'équipe aux nouveaux workflows**

---

**Note:** Remplacer `VOTRE-USER` par votre vrai username GitHub dans tous les exemples.
