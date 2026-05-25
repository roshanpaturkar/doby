#!/usr/bin/env bash
# backup-state.sh — one-way backup of Doby's IDENTITY to a private git repo.
#
# Mirrors the "what makes this Doby this Doby" subset of data/ into a separate
# working tree and pushes it. One-way (host → repo): these files are
# Doby-authored / rarely hand-edited, so a mirror is safe and crash-recovery is
# the goal. The VAULT is NOT handled here — it's bidirectional, see
# sync-vault.sh.
#
# SECURITY: secrets are NEVER mirrored. .env, auth.json, auth.lock (OAuth +
# provider tokens) stay on the box. On restore you re-OAuth via `doby` → /model.
#
# Mirrored set:  SOUL.md  config.yaml  memories/(no *.lock)  skins/
#   skills/ is NOT mirrored by default — it's Hermes' bundled catalog (rebuilt
#   from the image) and your custom skills already live in the repo's skills/.
#   Set DOBY_BACKUP_SKILLS=1 if you hand-author runtime skills under data/skills.
#
# Config (env vars):
#   DOBY_DATA_DIR    Doby's data/ dir.   default: ./data relative to this repo
#   DOBY_STATE_REPO  Working tree (a git clone of your private doby-state repo).
#                    default: $HOME/doby-state
#   DOBY_STATE_BRANCH default: main
#   DOBY_BACKUP_SKILLS  1 = also mirror data/skills/. default: 0
#
# Designed for cron (every ~15 min is plenty).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="${DOBY_DATA_DIR:-${REPO_DIR}/data}"
STATE="${DOBY_STATE_REPO:-$HOME/doby-state}"
BRANCH="${DOBY_STATE_BRANCH:-main}"

log() { printf '%s backup-state: %s\n' "$(date -u +%FT%TZ)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

[ -d "$DATA" ]        || die "data dir not found: $DATA"
[ -d "$STATE/.git" ] || die "state repo not initialized at $STATE (run backup-init.sh first)"

# --- concurrency lock ---
LOCK="${TMPDIR:-/tmp}/doby-backup-state.lock"
mkdir "$LOCK" 2>/dev/null || { log "another run in progress; skipping"; exit 0; }
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

# Mirror dirs (rsync --delete keeps repo == source; exclude lock files).
mirror_dir() {
  local src="$1" dst="$2"
  [ -d "$src" ] || return 0
  mkdir -p "$dst"
  rsync -a --delete --exclude='*.lock' "$src/" "$dst/"
}
mirror_file() {
  local src="$1" dst="$2"
  [ -f "$src" ] && cp -p "$src" "$dst" || true
}

mirror_dir  "$DATA/memories" "$STATE/memories"
mirror_dir  "$DATA/skins"    "$STATE/skins"
mirror_file "$DATA/SOUL.md"     "$STATE/SOUL.md"
mirror_file "$DATA/config.yaml" "$STATE/config.yaml"
[ "${DOBY_BACKUP_SKILLS:-0}" = "1" ] && mirror_dir "$DATA/skills" "$STATE/skills"

cd "$STATE"
git add -A
if git diff --cached --quiet; then
  log "no changes"
  exit 0
fi
git commit -q -m "backup $(date -u +%Y%m%dT%H%M%SZ) ($(hostname -s 2>/dev/null || hostname))"
git push -q origin "HEAD:${BRANCH}" || die "push failed (network/auth?)"
log "backed up ok"
