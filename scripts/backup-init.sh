#!/usr/bin/env bash
# backup-init.sh — ONE-TIME setup of the two private backup repos.
#
# Run this ONCE, on the machine that holds the AUTHORITATIVE data (normally the
# VPS). It seeds both repos from the current data/, then ongoing sync is handled
# by cron (sync-vault.sh + backup-state.sh). Other machines (your laptop) join
# by CLONING — not by re-running this.
#
#   DOBY_VAULT_URL=git@github.com:USER/doby-vault.git \
#   DOBY_STATE_URL=git@github.com:USER/doby-state.git \
#   scripts/backup-init.sh
#
# Refuses to overwrite a remote that already has commits — if doby-vault already
# has content, this box should CLONE it instead (see docs/BACKUP.md).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="${DOBY_DATA_DIR:-${REPO_DIR}/data}"
VAULT="${DOBY_VAULT_DIR:-${DATA}/Documents/Obsidian Vault}"
STATE="${DOBY_STATE_REPO:-$HOME/doby-state}"
VAULT_URL="${DOBY_VAULT_URL:?set DOBY_VAULT_URL=git@github.com:USER/doby-vault.git}"
STATE_URL="${DOBY_STATE_URL:?set DOBY_STATE_URL=git@github.com:USER/doby-state.git}"

c_g=$'\033[32m'; c_y=$'\033[33m'; c_r=$'\033[31m'; c_d=$'\033[2m'; c_x=$'\033[0m'
ok()   { printf "  ${c_g}✓${c_x} %s\n" "$*"; }
say()  { printf "  %s\n" "$*"; }
die()  { printf "  ${c_r}✗${c_x} %s\n" "$*" >&2; exit 1; }

remote_has_commits() { [ -n "$(git ls-remote --heads "$1" 2>/dev/null)" ]; }

printf "${c_g}🧦 Doby backup init${c_x}\n\n"

# ---------------------------------------------------------------------------
# 1. Vault repo (bidirectional) — git init in place, seed, push.
# ---------------------------------------------------------------------------
say "Vault repo → $VAULT_URL"
[ -d "$VAULT" ] || die "vault dir not found: $VAULT"

if remote_has_commits "$VAULT_URL"; then
  die "doby-vault already has commits. This box should CLONE it, not seed it:
        rm -rf \"$VAULT\" && git clone $VAULT_URL \"$VAULT\"
      (back up the local copy first if it holds notes you want.)"
fi

cd "$VAULT"
top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ "$top" != "$(pwd -P)" ]; then
  git init -q -b main
  ok "git init (was tracked by a parent repo / untracked)"
fi

cat > .gitignore <<'EOF'
# Obsidian per-device UI state — churns across machines, causes false conflicts.
.obsidian/workspace
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/cache
.obsidian/.DS_Store
# Doby lock files / OS junk
*.lock
.DS_Store
.trash/
EOF

git remote remove origin 2>/dev/null || true
git remote add origin "$VAULT_URL"
git add -A
git diff --cached --quiet || git commit -q -m "seed vault $(date -u +%FT%TZ)"
git push -q -u origin main
ok "vault seeded + pushed"

# ---------------------------------------------------------------------------
# 2. State repo (one-way backup) — init working tree, populate, push.
# ---------------------------------------------------------------------------
echo
say "State repo → $STATE_URL  (working tree: $STATE)"

if remote_has_commits "$STATE_URL"; then
  die "doby-state already has commits. To restore onto a fresh box use restore-state.sh."
fi

mkdir -p "$STATE"
cd "$STATE"
[ -d .git ] || git init -q -b main

cat > .gitignore <<'EOF'
*.lock
.DS_Store
EOF

git remote remove origin 2>/dev/null || true
git remote add origin "$STATE_URL"

# Populate via the same mirror the cron job uses.
DOBY_DATA_DIR="$DATA" DOBY_STATE_REPO="$STATE" "$REPO_DIR/scripts/backup-state.sh" || true

git add -A
git diff --cached --quiet || git commit -q -m "seed state $(date -u +%FT%TZ)"
git push -q -u origin main
ok "state seeded + pushed"

cat <<EOF

${c_g}🧦 Both repos seeded.${c_x}

  Ongoing sync — add to this box's crontab (${c_d}crontab -e${c_x}):
    ${c_d}*/3 * * * * DOBY_DATA_DIR=$DATA $REPO_DIR/scripts/sync-vault.sh   >> ~/doby-sync.log  2>&1${c_x}
    ${c_d}*/15 * * * * DOBY_DATA_DIR=$DATA DOBY_STATE_REPO=$STATE $REPO_DIR/scripts/backup-state.sh >> ~/doby-backup.log 2>&1${c_x}

  Edit the vault from your laptop:
    1. ${c_d}git clone $VAULT_URL ~/DobyVault${c_x}
    2. Open ~/DobyVault in Obsidian, install the ${c_d}obsidian-git${c_x} plugin
       (auto pull+commit+push every 1–2 min). See docs/BACKUP.md.

EOF
