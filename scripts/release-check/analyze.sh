#!/usr/bin/env bash
# Usage: scripts/release-check/analyze.sh
# Runs `flutter analyze --fatal-infos --fatal-warnings`.
# Exits 1 on any issue per spec §5.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

STEP="analyze"
START=$(rc_now_ms)

LOG="$RELEASE_CHECK_DIR/analyze.log"

if flutter analyze --fatal-infos --fatal-warnings >"$LOG" 2>&1; then
  DUR=$(( $(rc_now_ms) - START ))
  rc_banner_ok "$STEP" "$DUR" "0 issues"
  rc_log_event "$STEP" "ok" "$DUR" "0 issues"
  exit 0
fi

DUR=$(( $(rc_now_ms) - START ))
rc_banner_fail "$STEP" "$DUR" "see $LOG"
tail -40 "$LOG" >&2 || true
rc_log_event "$STEP" "fail" "$DUR" "see $LOG"
exit "$RC_EXIT_ANALYSIS"
