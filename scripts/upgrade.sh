#!/usr/bin/env bash
# Upgrade the pinned Hermes version and rebuild.
#
# Usage:
#   scripts/upgrade.sh              # show current pin + latest upstream release
#   scripts/upgrade.sh v0.15.0      # set pin to v0.15.0 and rebuild
#   scripts/upgrade.sh latest       # auto-detect latest release from GitHub

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="${REPO_DIR}/HERMES_VERSION"
CURRENT="$(tr -d '[:space:]' < "$VERSION_FILE")"

if [ $# -eq 0 ]; then
  echo "Current pinned Hermes ref: ${CURRENT}"
  echo
  echo "Fetching latest release from GitHub..."
  latest=$(curl -fsSL https://api.github.com/repos/NousResearch/hermes-agent/releases/latest 2>/dev/null \
    | grep -m1 '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
  if [ -n "$latest" ]; then
    echo "Latest upstream:           ${latest}"
    [ "$latest" != "$CURRENT" ] && echo "(out of date — run: scripts/upgrade.sh $latest)"
  else
    echo "(could not fetch — check your connection)"
  fi
  exit 0
fi

target="$1"
if [ "$target" = "latest" ]; then
  target=$(curl -fsSL https://api.github.com/repos/NousResearch/hermes-agent/releases/latest \
    | grep -m1 '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
  [ -z "$target" ] && { echo "Could not resolve 'latest'."; exit 1; }
  echo "Resolved latest → ${target}"
fi

if [ "$target" = "$CURRENT" ]; then
  echo "Already on ${target}. Nothing to do."
  exit 0
fi

echo "Upgrading: ${CURRENT} → ${target}"
echo "$target" > "$VERSION_FILE"

cd "$REPO_DIR"
HERMES_UID=$(id -u) HERMES_GID=$(id -g) HERMES_REF="$target" \
  docker compose build

echo
echo "✓ Built doby on Hermes ${target}."
echo "  Apply with: docker compose up -d --force-recreate"
echo "  Or just: doby  (auto-uses the new image)"
