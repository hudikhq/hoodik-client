#!/usr/bin/env bash
# Usage: scripts/release-check/docker-hoodik-up.sh
# Boots an ephemeral hoodik server container (SQLite, plain HTTP, no mail)
# on localhost:5443 and waits for /api/liveness. Hermetic — no persistent
# volumes, no shared state between runs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

STEP="docker-hoodik-up"
START=$(rc_now_ms)

COMPOSE_FILE="$SCRIPT_DIR/docker-compose.e2e.yml"
HOODIK_URL="${HOODIK_E2E_URL:-http://127.0.0.1:5443}"

fail() {
  local msg="$1"
  local dur=$(( $(rc_now_ms) - START ))
  rc_banner_fail "$STEP" "$dur" "$msg"
  rc_log_event "$STEP" "fail" "$dur" "$msg"
  exit 1
}

command -v docker >/dev/null 2>&1 || fail "docker missing"

# `docker compose` (v2) and `docker-compose` (v1) differ in how they
# parse flags. Prefer v2 since it's bundled with Docker Desktop 20.10+.
if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  fail "neither 'docker compose' nor 'docker-compose' is available"
fi

# Pull latest image if missing, then boot. `-d` detaches; `--remove-orphans`
# wipes stale containers from an interrupted previous run.
"${COMPOSE[@]}" -f "$COMPOSE_FILE" up -d --remove-orphans >/dev/null 2>&1 \
  || fail "failed to start container — check 'docker compose logs'"

# Wait for readiness. liveness returns 200 once the HTTP server is accepting
# connections; early calls during migration setup can hang a few seconds.
for i in $(seq 1 60); do
  if curl -fsS --max-time 2 "$HOODIK_URL/api/liveness" >/dev/null 2>&1; then
    DUR=$(( $(rc_now_ms) - START ))
    rc_banner_ok "$STEP" "$DUR" "url=$HOODIK_URL (ready after ${i}s)"
    rc_log_event "$STEP" "ok" "$DUR" "ready after ${i}s"
    exit 0
  fi
  sleep 1
done

fail "hoodik server did not become ready at $HOODIK_URL within 60s"
