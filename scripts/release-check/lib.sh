#!/usr/bin/env bash
# Shared helpers for release-check step scripts.
# Sourced by every preflight.sh / format.sh / etc. — do not run directly.

set -euo pipefail

: "${RELEASE_CHECK_DIR:=.release-check}"
: "${RELEASE_CHECK_LOG:=$RELEASE_CHECK_DIR/last-run.json}"

mkdir -p "$RELEASE_CHECK_DIR"

rc_log_event() {
  # $1 step name, $2 status (ok|fail|skip|warn), $3 duration_ms, $4 message (optional)
  local step="$1" status="$2" duration_ms="$3" message="${4:-}"
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  # Escape double quotes in message to keep JSON valid. Message is machine-readable,
  # human detail goes to stdout above.
  local escaped_message
  escaped_message="${message//\\/\\\\}"
  escaped_message="${escaped_message//\"/\\\"}"
  printf '{"ts":"%s","step":"%s","status":"%s","duration_ms":%s,"message":"%s"}\n' \
    "$ts" "$step" "$status" "$duration_ms" "$escaped_message" >> "$RELEASE_CHECK_LOG"
}

rc_now_ms() {
  # macOS date doesn't support %N; fall back to python for millisecond precision.
  python3 -c 'import time; print(int(time.time() * 1000))'
}

rc_banner_ok() {
  local step="$1" duration_ms="$2" extra="${3:-}"
  local secs=$((duration_ms / 1000))
  printf '[release-check] %-28s ok (%ds) %s\n' "$step" "$secs" "$extra"
}

rc_banner_fail() {
  local step="$1" duration_ms="$2" extra="${3:-}"
  local secs=$((duration_ms / 1000))
  printf '[release-check] %-28s FAIL (%ds) %s\n' "$step" "$secs" "$extra" >&2
}

rc_banner_skip() {
  local step="$1" extra="${2:-}"
  printf '[release-check] %-28s skip %s\n' "$step" "$extra"
}

rc_banner_warn() {
  local step="$1" extra="${2:-}"
  printf '[release-check] %-28s warn %s\n' "$step" "$extra"
}

# Exit codes per spec §5.
RC_EXIT_ANALYSIS=1
RC_EXIT_UNIT=2
RC_EXIT_INTEGRATION=3
RC_EXIT_E2E=4
RC_EXIT_BUILD=5
RC_EXIT_INVARIANTS=6
RC_EXIT_PREFLIGHT=7
