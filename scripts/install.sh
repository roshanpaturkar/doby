#!/usr/bin/env bash
# Doby installer — one-time setup for a new machine.
#
# What it does:
#   1. Sanity-checks Docker is installed and running.
#   2. Initializes ./data/ from ./templates/ (only if data/ is empty —
#      safe to re-run; your edits are never clobbered).
#   3. Builds the Doby image (pulls Hermes at the version pinned in
#      HERMES_VERSION). Slow on first build (~5–10 min), cached after.
#   4. Installs the `doby` wrapper to ~/.local/bin/doby with this repo's
#      path baked in.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${REPO_DIR}/data"
TEMPLATES_DIR="${REPO_DIR}/templates"
SKILLS_DIR="${REPO_DIR}/skills"
HERMES_REF="$(cat "${REPO_DIR}/HERMES_VERSION" | tr -d '[:space:]')"

c_grn=$'\033[32m'; c_ylw=$'\033[33m'; c_red=$'\033[31m'; c_dim=$'\033[2m'; c_rst=$'\033[0m'

say()  { printf "  %s\n" "$*"; }
ok()   { printf "  %s✓%s %s\n" "$c_grn" "$c_rst" "$*"; }
warn() { printf "  %s!%s %s\n" "$c_ylw" "$c_rst" "$*"; }
die()  { printf "  %s✗%s %s\n" "$c_red" "$c_rst" "$*" >&2; exit 1; }

printf "%s🧦 Doby installer%s\n\n" "$c_grn" "$c_rst"

# --- 1. Docker check ---
say "Checking Docker..."
command -v docker >/dev/null 2>&1 || die "docker not found in PATH. Install Docker Desktop or equivalent first."
docker info >/dev/null 2>&1 || die "Docker daemon not running. Start it and try again."
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 not found (you need 'docker compose', not 'docker-compose')."
ok "Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'OK')"

# --- 2. Seed data/ from templates/ (idempotent) ---
say "Setting up data directory..."
mkdir -p "$DATA_DIR"
if [ -z "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
  cp -R "$TEMPLATES_DIR"/. "$DATA_DIR"/
  if [ -f "$DATA_DIR/.env.example" ] && [ ! -f "$DATA_DIR/.env" ]; then
    cp "$DATA_DIR/.env.example" "$DATA_DIR/.env"
  fi
  mkdir -p "$DATA_DIR/skills"
  cp -R "$SKILLS_DIR"/. "$DATA_DIR/skills"/
  ok "Initialized $DATA_DIR from templates"
else
  ok "data/ already initialized — leaving it alone (your edits stay)"
fi

# --- 3. Build the image ---
say "Building Doby image (Hermes pinned at $HERMES_REF, ~5–10 min on first build)..."
(
  cd "$REPO_DIR"
  HERMES_UID="$(id -u)" HERMES_GID="$(id -g)" HERMES_REF="$HERMES_REF" \
    docker compose build
)
ok "Image built"

# --- 4. Install the wrapper at ~/.local/bin/doby ---
say "Installing the doby wrapper..."
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
sed "s|__DOBY_DIR__|$REPO_DIR|" "$REPO_DIR/bin/doby" > "$BIN_DIR/doby"
chmod +x "$BIN_DIR/doby"
ok "Installed: $BIN_DIR/doby"

# PATH sanity
case ":$PATH:" in
  *":$BIN_DIR:"*) ok "~/.local/bin is on PATH" ;;
  *)
    warn "~/.local/bin is NOT on PATH yet."
    say "  Add this to your shell rc (~/.zshrc or ~/.bashrc):"
    say "    ${c_dim}export PATH=\"\$HOME/.local/bin:\$PATH\"${c_rst}"
    say "  Then: ${c_dim}source ~/.zshrc${c_rst}  (or open a new terminal)"
    ;;
esac

cat <<EOF

${c_grn}🧦 Doby is ready, sir!${c_rst}

  Next steps:
    1. Pick a provider in ${c_dim}data/config.yaml${c_rst} and ${c_dim}data/.env${c_rst}
       (commented examples for Copilot, OpenRouter, Gemini, Anthropic).
    2. Run: ${c_dim}doby${c_rst}
    3. Inside Doby: ${c_dim}/model${c_rst} to authenticate (for OAuth providers).

  Customize:
    • Persona  — ${c_dim}data/SOUL.md${c_rst}   (live-reloaded each turn)
    • Branding — ${c_dim}data/skins/doby.yaml${c_rst}
    • Skills   — ${c_dim}data/skills/${c_rst}

  Use Doby from Telegram / Discord / Slack / WhatsApp / Google Chat / ... :
    1. ${c_dim}doby gateway setup${c_rst}   — interactive wizard, pick a platform, paste your bot token
    2. ${c_dim}doby gateway on${c_rst}      — start the bot (background, survives reboots)
    3. ${c_dim}doby gateway status${c_rst}  — is it running?  ${c_dim}doby gateway logs${c_rst} to tail
    4. ${c_dim}doby gateway off${c_rst}     — stop it when you don't want the bot up

  Docs:
    • ${c_dim}docs/PROVIDERS.md${c_rst} — picking and configuring providers
    • ${c_dim}docs/PERSONAS.md${c_rst}  — forking Doby into your own elf
    • ${c_dim}docs/TROUBLESHOOTING.md${c_rst}

EOF
