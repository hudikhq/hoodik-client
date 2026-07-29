#!/usr/bin/env bash
# Usage: scripts/compat/teardown.sh
#
# Stops and removes the compat hoodik container and its named volume.
# Idempotent — safe to re-run when nothing is running. Never fails the
# caller on "container not found".

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_FILE="$REPO_ROOT/docker-compose.compat.yml"

log() { printf '[compat-teardown] %s\n' "$*"; }

if ! command -v docker >/dev/null 2>&1; then
  log "docker not installed; nothing to tear down"
  exit 0
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  log "no 'docker compose' available; nothing to tear down"
  exit 0
fi

# compose requires HOODIK_SERVER_VERSION to parse the file even just to run
# `down`, but the value doesn't matter for teardown — any string parses.
export HOODIK_SERVER_VERSION="${HOODIK_SERVER_VERSION:-v0.0.0-teardown}"

log "docker compose down -v (removing volume hoodik-compat-data)"
"${COMPOSE[@]}" -f "$COMPOSE_FILE" down --remove-orphans -v >/dev/null 2>&1 || true

# Belt-and-braces: if the container was started outside compose (e.g. a
# previous interrupted run), `down` won't touch it. Nuke by name.
docker rm -f hoodik-compat >/dev/null 2>&1 || true
docker volume rm hoodik-compat_hoodik-compat-data >/dev/null 2>&1 || true

log "done"
