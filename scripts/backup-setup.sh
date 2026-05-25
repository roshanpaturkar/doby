#!/usr/bin/env bash
# backup-setup.sh — interactive, one-shot setup of Doby's git backup + sync.
#
# Run this ONCE on the box that owns the data (the VPS), AFTER you've added the
# two deploy keys on GitHub. It does everything else automatically:
#   • finds your data/ and the Obsidian vault dir (whatever it's named)
#   • verifies SSH to both repos before touching anything
#   • seeds doby-vault (bidirectional) and doby-state (backup)
#   • installs the cron jobs (idempotent)
#
# Safe to re-run — it detects an already-seeded repo and just syncs instead.
#
# Prerequisites (see docs/BACKUP.md):
#   1. Two empty private repos: doby-vault, doby-state
#   2. A deploy key (write) per repo + ~/.ssh/config aliases github-vault /
#      github-state.   Test: ssh -T git@github-vault

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

c_g=$'\033[32m'; c_y=$'\033[33m'; c_r=$'\033[31m'; c_b=$'\033[1m'; c_d=$'\033[2m'; c_x=$'\033[0m'
ok()   { printf "  ${c_g}✓${c_x} %s\n" "$*"; }
info() { printf "  ${c_d}%s${c_x}\n" "$*"; }
warn() { printf "  ${c_y}!${c_x} %s\n" "$*"; }
die()  { printf "  ${c_r}✗${c_x} %s\n" "$*" >&2; exit 1; }
hr()   { printf "\n${c_b}%s${c_x}\n" "$*"; }
ts()   { date -u +%Y%m%dT%H%M%SZ; }

ask() { # ask "prompt" "default" -> echoes answer
  local p="$1" d="${2:-}" a
  if [ -n "$d" ]; then read -r -p "  ${c_y}?${c_x} ${p} [${d}]: " a; echo "${a:-$d}"
  else read -r -p "  ${c_y}?${c_x} ${p}: " a; echo "$a"; fi
}
confirm() { local a; read -r -p "  ${c_y}?${c_x} $1 [y/N] " a; [[ "${a:-}" =~ ^[Yy]$ ]]; }

remote_has_commits() { [ -n "$(git ls-remote --heads "$1" 2>/dev/null)" ]; }

ssh_ok() { # ssh_ok host -> 0 if GitHub auth works
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T "$1" 2>&1 \
    | grep -qi "successfully authenticated"
}

printf "${c_g}${c_b}🧦 Doby backup setup${c_x}\n"
info "checkout: $REPO_DIR"

# ---------------------------------------------------------------------------
hr "1. Paths"
# ---------------------------------------------------------------------------
DATA="$(ask "Doby data dir" "${REPO_DIR}/data")"
[ -d "$DATA" ] || die "data dir not found: $DATA"
DATA="$(cd "$DATA" && pwd -P)"
ok "data: $DATA"

# Find the Documents dir (case-insensitive), then the vault dir inside it.
DOCS="$(find "$DATA" -maxdepth 1 -type d -iname documents 2>/dev/null | head -1)"
[ -n "$DOCS" ] || DOCS="$DATA/Documents"
VAULT="$(find "$DOCS" -maxdepth 1 -mindepth 1 -type d -iname '*bsidian*' 2>/dev/null | head -1)"
[ -n "$VAULT" ] || VAULT="$(find "$DOCS" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)"

if [ -z "$VAULT" ]; then
  warn "no vault folder found under $DOCS (Doby hasn't taken a note yet)"
  name="$(ask "vault folder name to create" "Obsidian Vault")"
  VAULT="$DOCS/$name"
  mkdir -p "$VAULT"
  ok "created empty vault: $VAULT"
else
  VAULT="$(cd "$VAULT" && pwd -P)"
  ok "vault: $VAULT"
fi

# ---------------------------------------------------------------------------
hr "2. Repo URLs"
# ---------------------------------------------------------------------------
info "Default form uses the SSH aliases from docs/BACKUP.md (github-vault / github-state)."
GH="$(ask "GitHub user/org" "$(git config --get user.name >/dev/null 2>&1; echo roshanpaturkar)")"
VAULT_URL="$(ask "doby-vault URL" "git@github-vault:${GH}/doby-vault.git")"
STATE_URL="$(ask "doby-state URL" "git@github-state:${GH}/doby-state.git")"

# ---------------------------------------------------------------------------
hr "3. SSH preflight"
# ---------------------------------------------------------------------------
vhost="$(printf '%s' "$VAULT_URL" | sed -E 's/^git@([^:]+):.*/\1/')"
shost="$(printf '%s' "$STATE_URL" | sed -E 's/^git@([^:]+):.*/\1/')"
ssh_ok "git@${vhost}" && ok "auth ok → ${vhost}" || die "SSH auth failed for git@${vhost}. Check the deploy key + ~/.ssh/config. Test: ssh -T git@${vhost}"
ssh_ok "git@${shost}" && ok "auth ok → ${shost}" || die "SSH auth failed for git@${shost}. Check the deploy key + ~/.ssh/config. Test: ssh -T git@${shost}"

# ---------------------------------------------------------------------------
hr "4. Seed doby-vault (bidirectional)"
# ---------------------------------------------------------------------------
cd "$VAULT"
top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ "$top" = "$(pwd -P)" ] || git init -q -b main
git remote remove origin 2>/dev/null || true
git remote add origin "$VAULT_URL"
cat > .gitignore <<'EOF'
.obsidian/workspace
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/cache
.obsidian/.DS_Store
*.lock
.DS_Store
.trash/
EOF

if remote_has_commits "$VAULT_URL"; then
  warn "doby-vault already has commits — syncing this box to it instead of seeding"
  git add -A; git commit -q -m "local edits $(ts)" 2>/dev/null || true
  git fetch -q origin main
  if ! git rebase -q origin/main; then
    git rebase --abort 2>/dev/null || true
    git push -q origin "HEAD:backup/conflict-$(ts)" || true
    die "vault diverged from remote. Local work parked on origin branch backup/conflict-*. Merge by hand, then re-run."
  fi
  git push -q origin HEAD:main
  ok "vault synced to existing remote"
else
  git add -A
  git diff --cached --quiet || git commit -q -m "seed vault $(ts)"
  git branch -M main
  git push -q -u origin main
  ok "vault seeded + pushed"
fi

# ---------------------------------------------------------------------------
hr "5. Seed doby-state (backup)"
# ---------------------------------------------------------------------------
STATE="$(ask "doby-state working tree" "$HOME/doby-state")"
mkdir -p "$STATE"; STATE="$(cd "$STATE" && pwd -P)"
cd "$STATE"
[ -d .git ] || git init -q -b main
git remote remove origin 2>/dev/null || true
git remote add origin "$STATE_URL"
printf '%s\n' '*.lock' '.DS_Store' > .gitignore

# Populate via the same mirror cron uses, then push.
DOBY_DATA_DIR="$DATA" DOBY_STATE_REPO="$STATE" "$REPO_DIR/scripts/backup-state.sh" \
  >/dev/null 2>&1 || true   # backup-state pushes; if remote empty it sets nothing upstream yet
git add -A
git diff --cached --quiet || git commit -q -m "seed state $(ts)"
git branch -M main
git push -q -u origin main 2>/dev/null || git push -q origin HEAD:main
ok "state seeded + pushed"

# ---------------------------------------------------------------------------
hr "6. Cron"
# ---------------------------------------------------------------------------
SYNC="$REPO_DIR/scripts/sync-vault.sh"
BKUP="$REPO_DIR/scripts/backup-state.sh"
MARK="# doby-backup"
LINE1="*/3 * * * * DOBY_VAULT_DIR=\"$VAULT\" $SYNC >> $HOME/doby-sync.log 2>&1 $MARK"
LINE2="*/15 * * * * DOBY_DATA_DIR=\"$DATA\" DOBY_STATE_REPO=\"$STATE\" $BKUP >> $HOME/doby-backup.log 2>&1 $MARK"

if confirm "Install/refresh the two cron jobs now?"; then
  tmp="$(mktemp)"
  crontab -l 2>/dev/null | grep -vF "$MARK" > "$tmp" || true
  printf '%s\n%s\n' "$LINE1" "$LINE2" >> "$tmp"
  crontab "$tmp"; rm -f "$tmp"
  ok "cron installed (vault every 3 min, state every 15 min)"
  info "logs: ~/doby-sync.log  ~/doby-backup.log"
else
  warn "skipped — add manually later:"
  printf '    %s\n    %s\n' "$LINE1" "$LINE2"
fi

# ---------------------------------------------------------------------------
cat <<EOF

${c_g}${c_b}🧦 Backup is live.${c_x}

  ${c_b}Vault${c_x} (bidirectional):   $VAULT_URL
  ${c_b}State${c_x} (backup):          $STATE_URL

  Edit notes from your laptop / phone:
    1. ${c_d}git clone $VAULT_URL ~/DobyVault${c_x}
    2. Open ~/DobyVault in Obsidian → install the ${c_d}obsidian-git${c_x} plugin
       (auto pull + commit + push every 1–2 min).

  Restore onto a fresh box later:  ${c_d}scripts/restore-state.sh${c_x}  (see docs/BACKUP.md)

EOF
