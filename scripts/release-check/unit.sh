#!/usr/bin/env bash
# Usage: scripts/release-check/unit.sh
# Runs unit + widget tests with coverage. Archives lcov.
# Exits 2 on test failure per spec §5.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

STEP="unit+widget"
START=$(rc_now_ms)

LOG="$RELEASE_CHECK_DIR/unit.log"

if flutter test test/core/ test/features/ --coverage --reporter expanded >"$LOG" 2>&1; then
  if [ -f coverage/lcov.info ]; then
    cp coverage/lcov.info "$RELEASE_CHECK_DIR/coverage.lcov"
  fi
  DUR=$(( $(rc_now_ms) - START ))
  # Extract "All tests passed!" summary line when present.
  SUMMARY="$(grep -E 'All tests passed|[0-9]+ passed|[0-9]+ failed' "$LOG" | tail -1 || true)"
  rc_banner_ok "$STEP" "$DUR" "$SUMMARY"
  rc_log_event "$STEP" "ok" "$DUR" "$SUMMARY"
  exit 0
fi

DUR=$(( $(rc_now_ms) - START ))
rc_banner_fail "$STEP" "$DUR" "see $LOG"
tail -60 "$LOG" >&2 || true
rc_log_event "$STEP" "fail" "$DUR" "see $LOG"
exit "$RC_EXIT_UNIT"
