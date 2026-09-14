#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  Versioned backups of the server's config with restic.
#
#  Backs up CONFIG_ROOT (every container's config/database). Does NOT back
#  up media/downloads — those are large and re-downloadable.
#
#  Home Assistant is covered too: HAOS writes its full backups to the Samba
#  share at CONFIG_ROOT/ha-backups (see homeassistant-vm/README.md), so they
#  ride along in this same restic run.
#
#  Setup (once):
#    sudo apt-get install -y restic
#    cp scripts/backup.env.example scripts/backup.env   # then edit it
#    chmod 600 scripts/backup.env
#    export $(grep -v '^#' scripts/backup.env | xargs) && restic init
#
#  Run:            bash scripts/backup.sh
#  Automate:       see the systemd timer in docs/host-setup.md
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load repo location + password (RESTIC_REPOSITORY, RESTIC_PASSWORD, and any
# backend creds like B2/S3 keys). Keep this file chmod 600 — it has secrets.
ENV_FILE="${BACKUP_ENV:-$SCRIPT_DIR/backup.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
else
  echo "!! $ENV_FILE not found. Copy backup.env.example and fill it in." >&2
  exit 1
fi

# What to back up (defaults match .env's CONFIG_ROOT).
BACKUP_PATHS="${BACKUP_PATHS:-/srv/appdata}"

# Retention: keep this many recent snapshots, then thin out.
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-6}"

echo ">> Backing up: $BACKUP_PATHS"
restic backup $BACKUP_PATHS \
  --exclude-caches \
  --tag homeserver

echo ">> Pruning old snapshots ..."
restic forget \
  --keep-daily "$KEEP_DAILY" \
  --keep-weekly "$KEEP_WEEKLY" \
  --keep-monthly "$KEEP_MONTHLY" \
  --prune

echo ">> Verifying repository integrity ..."
restic check

echo ">> Done. Snapshots:"
restic snapshots --compact
