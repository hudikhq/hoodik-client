#!/usr/bin/env bash
# Usage: scripts/compat/bootstrap.sh
#
# Waits for the compat hoodik container to become healthy, then registers
# the deterministic compat test user. Exit 0 = ready for Patrol; any
# non-zero exit aborts the `just e2e-compat` recipe before the simulator
# boots.
#
# Environment (optional):
#   COMPAT_BASE_URL     http://127.0.0.1:5443 (must match docker-compose.compat.yml)
#   COMPAT_EMAIL        compat@hoodik.local
#   COMPAT_PASSWORD     compat-user-pass-1234
#   COMPAT_TIMEOUT_SEC  120

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BASE_URL="${COMPAT_BASE_URL:-http://127.0.0.1:5443}"
EMAIL="${COMPAT_EMAIL:-compat@hoodik.local}"
PASSWORD="${COMPAT_PASSWORD:-compat-user-pass-1234}"
TIMEOUT_SEC="${COMPAT_TIMEOUT_SEC:-120}"
VENV_DIR="$SCRIPT_DIR/.venv"

log() { printf '[compat-bootstrap] %s\n' "$*"; }
die() { printf '[compat-bootstrap] FAIL: %s\n' "$*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || die "python3 not found on PATH"
command -v curl >/dev/null 2>&1 || die "curl not found on PATH"

# One-time venv bootstrap. The `ascon` and `cryptography` pip packages are
# isolated here so the host Python install stays untouched — macOS 14+ blocks
# `pip3 install` against the system Python (PEP 668). A stale venv is cheap
# to rebuild; if the sentinel file is missing we always re-install.
SENTINEL="$VENV_DIR/.ready"
if [[ ! -f "$SENTINEL" ]]; then
  log "creating Python venv at $VENV_DIR"
  rm -rf "$VENV_DIR"
  python3 -m venv "$VENV_DIR" || die "python3 -m venv failed"
  "$VENV_DIR/bin/pip" install --quiet --upgrade pip >/dev/null
  "$VENV_DIR/bin/pip" install --quiet cryptography ascon requests \
    || die "pip install cryptography ascon requests failed"
  touch "$SENTINEL"
fi

# Poll /api/auth/self (POST) until we see a 401. Any 2xx/4xx proves the
# server booted past its migration phase; 000/5xx/connect-refused means
# still warming up. Times out per COMPAT_TIMEOUT_SEC.
log "waiting for $BASE_URL to become healthy (timeout ${TIMEOUT_SEC}s)"
deadline=$(( $(date +%s) + TIMEOUT_SEC ))
delay_ms=200
while :; do
  code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 \
    -X POST -H 'Content-Type: application/json' -d '{}' \
    "$BASE_URL/api/auth/self" 2>/dev/null || echo "000")
  if [[ "$code" == "401" || "$code" =~ ^2|^4 ]]; then
    log "server healthy (HTTP $code from /api/auth/self)"
    break
  fi
  if (( $(date +%s) >= deadline )); then
    die "server did not become healthy at $BASE_URL within ${TIMEOUT_SEC}s (last code: $code)"
  fi
  # Backoff: 200ms, 400ms, 800ms, ..., capped at 2s. Short probes early keep
  # the happy path fast (under 5s) while the cap keeps the loop cheap when
  # a slow migration runs against a cold SQLite file.
  python3 -c "import time; time.sleep(${delay_ms}/1000.0)"
  delay_ms=$(( delay_ms * 2 > 2000 ? 2000 : delay_ms * 2 ))
done

log "registering compat test user ($EMAIL)"
"$VENV_DIR/bin/python" "$SCRIPT_DIR/register_test_user.py" \
  --base-url "$BASE_URL" \
  --email "$EMAIL" \
  --password "$PASSWORD" \
  || die "register_test_user.py failed"

log "compat server ready at $BASE_URL"
