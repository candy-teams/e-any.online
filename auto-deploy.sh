#!/usr/bin/env bash
set -euo pipefail
LOG=/var/log/portal-deploy.log
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log() { echo "[$(date -Is)] $*" | tee -a "$LOG"; }
cd /data/stacks/e-any-portal
[ -f .env ] && set -a && . ./.env && set +a
BRANCH=main
git fetch origin "$BRANCH" --quiet 2>>"$LOG" || { log "fetch FAILED"; exit 1; }
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$BRANCH")
if [ "$LOCAL" = "$REMOTE" ]; then
  log "up-to-date ($LOCAL)"
  exit 0
fi
git pull --ff-only origin "$BRANCH" 2>>"$LOG" || { log "pull FAILED"; exit 1; }
sudo -n docker compose up -d e_any_portal >>"$LOG" 2>&1 || {
  sudo -n /usr/local/bin/docker compose -f /data/stacks/e-any-portal/docker-compose.yml up -d e-any-portal >>"$LOG" 2>&1
}
log "deployed $LOCAL -> $REMOTE"
