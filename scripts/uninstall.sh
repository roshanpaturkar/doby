#!/usr/bin/env bash
# Doby uninstaller — cleanly remove Doby from your system.
#
# Usage:
#   scripts/uninstall.sh                # interactive — asks before each destructive step
#   scripts/uninstall.sh --yes          # answer yes to all (image + wrapper + data)
#   scripts/uninstall.sh --keep-data    # remove everything EXCEPT data/ (config, persona, OAuth)
#   scripts/uninstall.sh --help         # show this header
#
# What gets removed (interactively, in this order):
#   1. The running doby container       (always — no prompt)
#   2. The doby-agent:local Docker image (~3 GB)   [asks]
#   3. The ~/.local/bin/doby wrapper, ONLY if it points at THIS repo   [asks]
#   4. The local data/ directory (chat history, OAuth tokens, persona) [asks]
#
# What is NEVER touched by this script:
#   • The repo directory itself ($REPO_DIR) — remove manually if you want.
#   • OAuth grants on provider websites — see the link list at the end.
#   • Wrappers / containers / images belonging to OTHER Doby installs.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${REPO_DIR}/data"
COMPOSE_FILE="${REPO_DIR}/docker-compose.yml"
WRAPPER="$HOME/.local/bin/doby"
IMAGE="doby-agent:local"

ASSUME_YES=0
KEEP_DATA=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y)      ASSUME_YES=1 ;;
    --keep-data)   KEEP_DATA=1 ;;
    --help|-h)
      sed -n '2,/^$/p; /^$/q' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *)
      echo "Unknown arg: $arg (try --help)" >&2
      exit 1 ;;
  esac
done

c_grn=$'\033[32m'; c_ylw=$'\033[33m'; c_red=$'\033[31m'; c_dim=$'\033[2m'; c_rst=$'\033[0m'

say()  { printf "  %s\n" "$*"; }
ok()   { printf "  %s✓%s %s\n" "$c_grn" "$c_rst" "$*"; }
skip() { printf "  %s−%s %s\n" "$c_dim" "$c_rst" "$*"; }
warn() { printf "  %s!%s %s\n" "$c_ylw" "$c_rst" "$*"; }

confirm() {
  [ "$ASSUME_YES" = "1" ] && return 0
  local prompt="$1"
  read -r -p "  ${c_ylw}?${c_rst} ${prompt} [y/N] " r
  [[ "${r:-}" =~ ^[Yy]$ ]]
}

printf "%s🧦 Doby uninstaller%s\n" "$c_grn" "$c_rst"
printf "%s   Repo: %s%s\n\n" "$c_dim" "$REPO_DIR" "$c_rst"

# --- 1. Container ---
say "Stopping the doby container..."
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if [ -n "$(docker compose -f "$COMPOSE_FILE" ps -aq doby 2>/dev/null)" ] || \
     [ -n "$(docker compose -f "$COMPOSE_FILE" --profile gateway ps -aq doby-gateway 2>/dev/null)" ]; then
    # --profile gateway ensures the optional doby-gateway sidecar is also torn down.
    HERMES_UID="$(id -u)" HERMES_GID="$(id -g)" \
      docker compose -f "$COMPOSE_FILE" --profile gateway down --remove-orphans >/dev/null
    ok "Container(s) stopped + removed"
  else
    skip "No doby container found"
  fi
else
  warn "Docker not running — skipping container/image cleanup (manual: docker compose down && docker rmi $IMAGE)"
fi

# --- 2. Image ---
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    size=$(docker image inspect "$IMAGE" --format '{{.Size}}' 2>/dev/null | awk '{ printf "%.1f GB", $1/1024/1024/1024 }')
    if confirm "Remove image $IMAGE (~$size)?"; then
      docker rmi "$IMAGE" >/dev/null
      ok "Image removed"
    else
      skip "Image kept (delete later: docker rmi $IMAGE)"
    fi
  else
    skip "No $IMAGE image found"
  fi
fi

# --- 3. Wrapper (only if it points at THIS repo) ---
if [ -f "$WRAPPER" ]; then
  # Match both the legacy literal form (DOBY_DIR="<repo>") and the new
  # env-overridable form (DOBY_DIR="${DOBY_DIR:-<repo>}") that bin/doby uses.
  if grep -qF ":-${REPO_DIR}}" "$WRAPPER" 2>/dev/null || \
     grep -qF "DOBY_DIR=\"$REPO_DIR\"" "$WRAPPER" 2>/dev/null; then
    if confirm "Remove the doby wrapper at $WRAPPER?"; then
      rm -f "$WRAPPER"
      ok "Wrapper removed"
    else
      skip "Wrapper kept"
    fi
  else
    skip "Wrapper at $WRAPPER points to a different install — leaving alone"
  fi
else
  skip "No wrapper at $WRAPPER"
fi

# --- 4. Data dir ---
if [ "$KEEP_DATA" = "1" ]; then
  skip "Keeping $DATA_DIR (--keep-data)"
elif [ -d "$DATA_DIR" ]; then
  say "${DATA_DIR} contains:"
  say "  • config.yaml, SOUL.md, skins/, skills/   (your customization)"
  say "  • .env, auth.json                         (your API keys / OAuth tokens)"
  say "  • sessions/, memories/, MEMORY.md, USER.md (your chat history + Doby's notes)"
  if confirm "Remove $DATA_DIR entirely? (irreversible — you can also pass --keep-data to skip this)"; then
    rm -rf "$DATA_DIR"
    ok "data/ removed"
  else
    skip "data/ kept — re-install later won't make you re-OAuth"
  fi
else
  skip "No data/ directory found"
fi

# --- Footer ---
cat <<EOF

  ${c_ylw}OAuth grants on provider websites are NOT touched by this script.${c_rst}
  To fully sever account links, revoke them yourself:
    • GitHub Copilot:   https://github.com/settings/applications
    • Anthropic:        https://console.anthropic.com/settings/keys
    • Google:           https://myaccount.google.com/permissions
    • OpenAI:           https://platform.openai.com/account/api-keys

  The repo directory itself is left in place:
    ${c_dim}${REPO_DIR}${c_rst}
  Remove manually if you're sure: ${c_dim}rm -rf "${REPO_DIR}"${c_rst}

${c_grn}🧦 Doby has packed his bags, sir.${c_rst}

EOF
