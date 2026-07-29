#!/usr/bin/env bash
# Usage: scripts/release-check/integration.sh
# Runs integration_test/ excluding the e2e/ subfolder (those run via Patrol).
# Exits 3 on failure per spec §5.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

STEP="integration"
START=$(rc_now_ms)

LOG="$RELEASE_CHECK_DIR/integration.log"

# Enumerate integration tests that are NOT under e2e/. E2E tests use Patrol,
# not the plain integration_test harness — running them here would fail.
# macOS bash 3.2 has no mapfile; use while-read instead.
FILES=()
while IFS= read -r line; do
  FILES+=("$line")
done < <(find integration_test -type f -name '*_test.dart' -not -path 'integration_test/e2e/*' | sort)

if [ "${#FILES[@]}" -eq 0 ]; then
  DUR=$(( $(rc_now_ms) - START ))
  rc_banner_skip "$STEP" "no non-e2e integration tests"
  rc_log_event "$STEP" "skip" "$DUR" "no files"
  exit 0
fi

# Integration tests run on a real runtime (Rust FFI needs a device).
# When multiple devices are attached, flutter exits non-zero with a hint —
# we pick the first one explicitly via HOODIK_INTEGRATION_DEVICE (defaults
# to the first simulator/emulator flutter lists).
DEVICE="${HOODIK_INTEGRATION_DEVICE:-}"
if [ -z "$DEVICE" ]; then
  DEVICE="$(
    flutter devices --machine 2>/dev/null \
      | python3 -c 'import json,sys
d=json.load(sys.stdin)
for x in d:
    if x.get("emulator") or "simulator" in (x.get("platformType") or "").lower():
        print(x["id"]); break' 2>/dev/null || true
  )"
fi

FLUTTER_ARGS=(test --reporter expanded)
if [ -n "$DEVICE" ]; then
  FLUTTER_ARGS+=(-d "$DEVICE")
else
  # No device available. On CI runners that lack a simulator/emulator
  # (e.g. ubuntu-latest in ci.yml's fast path), allow opting out rather
  # than failing the whole release-check over a missing boot-up step.
  # HOODIK_SKIP_INTEGRATION_WITHOUT_DEVICE=1 turns this into a skip.
  if [ "${HOODIK_SKIP_INTEGRATION_WITHOUT_DEVICE:-0}" = "1" ]; then
    DUR=$(( $(rc_now_ms) - START ))
    rc_banner_skip "$STEP" "no device and HOODIK_SKIP_INTEGRATION_WITHOUT_DEVICE=1"
    rc_log_event "$STEP" "skip" "$DUR" "no device on CI runner"
    exit 0
  fi
fi

if flutter "${FLUTTER_ARGS[@]}" "${FILES[@]}" >"$LOG" 2>&1; then
  DUR=$(( $(rc_now_ms) - START ))
  SUMMARY="$(grep -E 'All tests passed|[0-9]+ passed|[0-9]+ failed' "$LOG" | tail -1 || true)"
  rc_banner_ok "$STEP" "$DUR" "$SUMMARY"
  rc_log_event "$STEP" "ok" "$DUR" "$SUMMARY"
  exit 0
fi

DUR=$(( $(rc_now_ms) - START ))
rc_banner_fail "$STEP" "$DUR" "see $LOG"
tail -60 "$LOG" >&2 || true
rc_log_event "$STEP" "fail" "$DUR" "see $LOG"
exit "$RC_EXIT_INTEGRATION"
