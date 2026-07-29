#!/usr/bin/env bash
# Usage: scripts/release-check/docker-hoodik-down.sh
# Stops and removes the ephemeral hoodik container started by docker-hoodik-up.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

STEP="docker-hoodik-down"
START=$(rc_now_ms)

COMPOSE_FILE="$SCRIPT_DIR/docker-compose.e2e.yml"

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "[release-check] $STEP skipped — no docker compose available" >&2
  exit 0
fi

"${COMPOSE[@]}" -f "$COMPOSE_FILE" down --remove-orphans -v >/dev/null 2>&1 || true

DUR=$(( $(rc_now_ms) - START ))
rc_banner_ok "$STEP" "$DUR" ""
rc_log_event "$STEP" "ok" "$DUR" ""
