#!/bin/bash
# =========================================================
#  OSIRIS — Deploy Script
#  Push → SSH → Docker Rebuild → Live
#
#  This script DEPLOYS already-committed work. It never stages or commits for
#  you: a blanket `git add -A` in a deploy path is how untracked .env files,
#  keys and dumps end up pushed to a public repo. Commit deliberately first.
#
#  Required configuration (no hardcoded hosts — set these yourself):
#    DEPLOY_HOST     user@host of your server, e.g. deploy@osiris.example.com
#    DEPLOY_DIR      absolute path to the checkout on that server
#  Optional:
#    DEPLOY_BRANCH   branch to deploy (default: current branch)
#
#  Put them in .env.deploy (git-ignored) or export them in your shell:
#    DEPLOY_HOST=deploy@example.com DEPLOY_DIR=/srv/osiris bash deploy.sh
# =========================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

die() { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }

# --- Load optional local config (never committed) ---
if [ -f .env.deploy ]; then
  # shellcheck disable=SC1091
  set -a; . ./.env.deploy; set +a
fi

: "${DEPLOY_HOST:?DEPLOY_HOST is not set — see the header of this script}"
: "${DEPLOY_DIR:?DEPLOY_DIR is not set — see the header of this script}"

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
BRANCH="${DEPLOY_BRANCH:-$CURRENT_BRANCH}"

echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     OSIRIS DEPLOYMENT                    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo -e "  host:   ${DEPLOY_HOST}"
echo -e "  dir:    ${DEPLOY_DIR}"
echo -e "  branch: ${BRANCH}"
echo ""

# --- STEP 1: Refuse to deploy an unclean tree ---
echo -e "${YELLOW}[1/3] GIT — Verifying working tree...${NC}"

if [ -n "$(git status --porcelain)" ]; then
  echo -e "${RED}  Working tree is not clean:${NC}"
  git status --short
  die "Commit or stash your changes, then re-run. This script will not commit for you."
fi

if [ "$BRANCH" != "$CURRENT_BRANCH" ]; then
  die "On branch '$CURRENT_BRANCH' but deploying '$BRANCH'. Check out '$BRANCH' first."
fi

echo -e "${GREEN}  ✓ Clean tree on $BRANCH${NC}"
echo ""

# --- STEP 2: Push already-committed work ---
echo -e "${YELLOW}[2/3] GIT — Pushing $BRANCH...${NC}"
git push origin "$BRANCH"
echo -e "${GREEN}  ✓ Pushed to origin/$BRANCH${NC}"
echo ""

# --- STEP 3: Remote pull & rebuild ---
echo -e "${YELLOW}[3/3] SERVER — Pulling & rebuilding...${NC}"
ssh "$DEPLOY_HOST" "set -e && cd '$DEPLOY_DIR' && git fetch origin && git checkout '$BRANCH' && git reset --hard 'origin/$BRANCH' && docker compose down && docker compose up -d --build"
echo -e "${GREEN}  ✓ Rebuilt and running${NC}"
echo ""

echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     ✅ DEPLOYMENT COMPLETE               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
