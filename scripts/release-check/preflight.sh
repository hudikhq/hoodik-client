#!/usr/bin/env bash
# Usage: scripts/release-check/preflight.sh
# Verifies required binaries and repo layout before release-check runs.
# Exits 7 on missing prerequisite per spec §5.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

STEP="preflight"
START=$(rc_now_ms)

fail() {
  local msg="$1"
  local dur=$(( $(rc_now_ms) - START ))
  rc_banner_fail "$STEP" "$dur" "$msg"
  rc_log_event "$STEP" "fail" "$dur" "$msg"
  exit "$RC_EXIT_PREFLIGHT"
}

require_bin() {
  local bin="$1" hint="${2:-}"
  if ! command -v "$bin" >/dev/null 2>&1; then
    fail "missing binary: $bin${hint:+ ($hint)}"
  fi
}

# Core toolchain.
require_bin just
require_bin flutter
require_bin dart

# Docker is only needed for the E2E jobs (ephemeral hoodik server). The fast
# path (format + analyze + invariants + unit + integration) never touches it.
# HOODIK_PREFLIGHT_NO_DOCKER=1 lets the fast CI lane skip that requirement.
if [ "${HOODIK_PREFLIGHT_NO_DOCKER:-0}" = "1" ]; then
  if ! command -v docker >/dev/null 2>&1; then
    rc_banner_warn "$STEP" "docker not on PATH — E2E recipes will fail"
  fi
else
  require_bin docker "needed for ephemeral hoodik server — https://docs.docker.com/get-docker/"
fi

# Platform-specific.
case "$(uname -s)" in
  Darwin)
    require_bin xcrun "iOS simulator + macOS builds"
    ;;
esac

# Android tools — warn only, since Android emulator is needed for e2e-android
# but not for release-check-fast.
if ! command -v adb >/dev/null 2>&1; then
  rc_banner_warn "$STEP" "adb not on PATH — Android E2E will fail. Expected at \$ANDROID_HOME/platform-tools/adb."
fi

# Patrol CLI: optional at preflight, required at e2e time. Warn only.
if ! command -v patrol >/dev/null 2>&1; then
  rc_banner_warn "$STEP" "patrol_cli not installed — run: dart pub global activate patrol_cli"
fi

# Flutter version: require 3.41.x per spec.
FLUTTER_VERSION="$(flutter --version 2>/dev/null | head -1 | awk '{print $2}')"
case "$FLUTTER_VERSION" in
  3.41.*) ;;
  *) rc_banner_warn "$STEP" "flutter $FLUTTER_VERSION (spec targets 3.41.x)" ;;
esac

# Dart version: require 3.11.x per spec.
DART_VERSION="$(dart --version 2>&1 | awk '{print $4}')"
case "$DART_VERSION" in
  3.11.*) ;;
  *) rc_banner_warn "$STEP" "dart $DART_VERSION (spec targets 3.11.x)" ;;
esac

# Sibling hoodik clone required for the Rust path patches in rust/.cargo/config.toml.
if [ ! -d "../hoodik" ]; then
  fail "../hoodik clone not found — git clone https://github.com/hudikhq/hoodik ../hoodik"
fi

DUR=$(( $(rc_now_ms) - START ))
rc_banner_ok "$STEP" "$DUR" "flutter=$FLUTTER_VERSION dart=$DART_VERSION"
rc_log_event "$STEP" "ok" "$DUR" "flutter=$FLUTTER_VERSION dart=$DART_VERSION"
