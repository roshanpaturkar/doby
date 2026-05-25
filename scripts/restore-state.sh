#!/usr/bin/env bash
# restore-state.sh — rebuild a Doby's identity onto a fresh box after a crash.
#
# Clones both backup repos and reassembles them into data/. Result: same
# persona, memories, notes, skins, skills. Secrets are NOT restored (they were
# never backed up) — after this, run `doby` → /model to re-OAuth, and Doby is
# the same elf.
#
#   DOBY_VAULT_URL=git@github.com:USER/doby-vault.git \
#   DOBY_STATE_URL=git@github.com:USER/doby-state.git \
#   scripts/restore-state.sh
#
# Safe by design:
#   • Never touches data/.env or data/auth.json (won't clobber existing creds).
#   • Refuses to overwrite a non-empty vault dir unless DOBY_RESTORE_FORCE=1.
#   • Identity files are copied in (no --delete), so other data/ contents stay.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="${DOBY_DATA_DIR:-${REPO_DIR}/data}"
VAULT="${DATA}/Documents/Obsidian Vault"
STATE_REPO="${DOBY_STATE_REPO:-$HOME/doby-state}"
VAULT_URL="${DOBY_VAULT_URL:?set DOBY_VAULT_URL=git@github.com:USER/doby-vault.git}"
STATE_URL="${DOBY_STATE_URL:?set DOBY_STATE_URL=git@github.com:USER/doby-state.git}"
FORCE="${DOBY_RESTORE_FORCE:-0}"

c_g=$'\033[32m'; c_y=$'\033[33m'; c_r=$'\033[31m'; c_d=$'\033[2m'; c_x=$'\033[0m'
ok()  { printf "  ${c_g}✓${c_x} %s\n" "$*"; }
warn(){ printf "  ${c_y}!${c_x} %s\n" "$*"; }
die() { printf "  ${c_r}✗${c_x} %s\n" "$*" >&2; exit 1; }

printf "${c_g}🧦 Doby restore${c_x}\n  Target data dir: ${c_d}%s${c_x}\n\n" "$DATA"

mkdir -p "$DATA"

# --- 1. Vault (bidirectional repo → live working tree) ---
if [ -d "$VAULT" ] && [ -n "$(ls -A "$VAULT" 2>/dev/null)" ]; then
  if [ "$FORCE" = "1" ]; then
    bak="${VAULT}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    mv "$VAULT" "$bak"; warn "existing vault moved aside → $bak"
  else
    die "vault already exists and is non-empty: $VAULT
      Move it aside, or re-run with DOBY_RESTORE_FORCE=1 to auto-back-it-up."
  fi
fi
mkdir -p "$(dirname "$VAULT")"
git clone -q "$VAULT_URL" "$VAULT"
ok "vault restored (clone of doby-vault — already wired for sync)"

# --- 2. State (one-way mirror → copy identity files in) ---
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone -q "$STATE_URL" "$tmp/state"

copy_in() {
  local src="$1" dst="$2"
  [ -e "$src" ] || return 0
  if [ -d "$src" ]; then
    mkdir -p "$dst"; rsync -a "$src/" "$dst/"
  else
    cp -p "$src" "$dst"
  fi
}
copy_in "$tmp/state/memories"    "$DATA/memories"
copy_in "$tmp/state/skins"       "$DATA/skins"
copy_in "$tmp/state/skills"      "$DATA/skills"
copy_in "$tmp/state/SOUL.md"     "$DATA/SOUL.md"
copy_in "$tmp/state/config.yaml" "$DATA/config.yaml"
ok "identity restored (SOUL, config, memories, skins, skills)"

cat <<EOF

${c_g}🧦 Doby reassembled.${c_x} Secrets were intentionally NOT restored.

  Finish on this box:
    1. ${c_d}cd $REPO_DIR && ./scripts/install.sh${c_x}   (build image if not already)
    2. ${c_d}doby${c_x}  → ${c_d}/model${c_x}  to re-OAuth your provider
    3. (optional) ${c_d}doby gateway setup${c_x} → ${c_d}doby gateway on${c_x} for messaging
    4. Re-add the sync cron lines (see docs/BACKUP.md)

EOF
