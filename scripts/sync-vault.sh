#!/usr/bin/env bash
# sync-vault.sh — bidirectional git sync for Doby's Obsidian vault.
#
# Both sides (VPS Doby + you in Obsidian) treat the central repo as the single
# source of truth: snapshot local edits → rebase onto remote → publish. On a
# real conflict it NEVER clobbers — it parks the divergent work on a
# backup/conflict-<ts> branch and exits non-zero for you to resolve by hand.
#
# Designed for cron (every 2–3 min). Safe to run concurrently — a mkdir lock
# skips overlapping runs (flock isn't on macOS; this is portable).
#
# Config (env vars, with defaults):
#   DOBY_VAULT_DIR    Path to the vault working tree (must be a git clone of
#                     your private doby-vault repo).
#                     default: ./data/Documents/Obsidian Vault relative to repo
#   DOBY_VAULT_BRANCH default: main
#
# Exit codes: 0 = synced, 2 = conflict parked (needs manual merge), 1 = error.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT="${DOBY_VAULT_DIR:-${REPO_DIR}/data/Documents/Obsidian Vault}"
BRANCH="${DOBY_VAULT_BRANCH:-main}"

log() { printf '%s sync-vault: %s\n' "$(date -u +%FT%TZ)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

if [ ! -d "$VAULT" ]; then
  mkdir -p "$VAULT"
  log "vault dir was missing — created it: $VAULT"
fi
cd "$VAULT"

# Confirm THIS dir is the repo root (not a parent repo bleeding through).
top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ "$top" = "$(pwd -P)" ] || die "$VAULT is not its own git repo (toplevel=$top). Run backup-init.sh first."
git remote get-url origin >/dev/null 2>&1 || die "no 'origin' remote in $VAULT"

# Fallback git identity (local-only, set only if none resolvable) so cron
# commits never fail with "Author identity unknown" on a bare box.
git config user.email >/dev/null 2>&1 || git config user.email "doby@$(hostname -s 2>/dev/null || hostname).local"
git config user.name  >/dev/null 2>&1 || git config user.name "Doby"

# --- concurrency lock (atomic mkdir; stale-safe after 30 min) ---
LOCK="${TMPDIR:-/tmp}/doby-sync-vault.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +30 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null || true
    mkdir "$LOCK" 2>/dev/null || { log "another run holds the lock; skipping"; exit 0; }
  else
    log "another run in progress; skipping"; exit 0
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

ts="$(date -u +%Y%m%dT%H%M%SZ)"
host="$(hostname -s 2>/dev/null || hostname)"

# 1. Snapshot whatever changed locally (Doby's notes, or yours).
git add -A
if ! git diff --cached --quiet; then
  git commit -q -m "sync ${ts} (${host})"
  log "committed local changes"
fi

# 2. Integrate remote edits onto our snapshot.
git fetch -q origin "$BRANCH" || die "fetch failed (network/auth?)"
if ! git rebase -q "origin/${BRANCH}"; then
  git rebase --abort 2>/dev/null || true
  # Park divergent local work so nothing is lost, leave main untouched.
  git push -q origin "HEAD:backup/conflict-${ts}" || true
  die "CONFLICT — local work parked on origin branch backup/conflict-${ts}. Merge it by hand into ${BRANCH}."
fi

# 3. Publish.
git push -q origin "HEAD:${BRANCH}" || die "push failed (network/auth?)"
log "synced ok"
