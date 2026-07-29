#!/usr/bin/env bash
# Usage: scripts/release-check/build.sh
# Release-mode builds for iOS (no-codesign), Android APK, macOS. Fail-fast.
# Exits 5 on build failure per spec §5.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

run_build() {
  local label="$1"
  shift
  local log="$RELEASE_CHECK_DIR/build-${label}.log"
  local t0
  t0=$(rc_now_ms)
  if "$@" >"$log" 2>&1; then
    local dur=$(( $(rc_now_ms) - t0 ))
    rc_banner_ok "build $label" "$dur" ""
    rc_log_event "build-$label" "ok" "$dur" ""
    return 0
  fi
  local dur=$(( $(rc_now_ms) - t0 ))
  rc_banner_fail "build $label" "$dur" "see $log"
  tail -40 "$log" >&2 || true
  rc_log_event "build-$label" "fail" "$dur" "see $log"
  return 1
}

IS_MACOS=false
[ "$(uname -s)" = "Darwin" ] && IS_MACOS=true

if $IS_MACOS; then
  run_build "ios" flutter build ios --release --no-codesign || exit "$RC_EXIT_BUILD"
fi

run_build "apk" flutter build apk --release || exit "$RC_EXIT_BUILD"

if $IS_MACOS; then
  run_build "macos" flutter build macos --release || exit "$RC_EXIT_BUILD"
fi
