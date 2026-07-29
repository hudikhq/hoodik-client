#!/usr/bin/env bash
# Usage: scripts/release-check/format.sh
# Runs `dart format --set-exit-if-changed .` excluding generated code.
# Exits 1 on formatting drift per spec §5.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

STEP="format"
START=$(rc_now_ms)

# lib/src/rust/ is FFI codegen output; rust_builder/cargokit is vendored
# tooling. Both re-format on generation — touching them would loop forever.
# `dart format` (since Dart 3.x) has no --exclude flag, so we enumerate
# the files we DO want formatted. macOS ships bash 3.2 (no mapfile), so
# read into an array via while-read.
TARGETS=()
while IFS= read -r line; do
  TARGETS+=("$line")
done < <(
  find . \
    -type f \
    -name '*.dart' \
    -not -path './lib/src/rust/*' \
    -not -path './rust_builder/cargokit/*' \
    -not -path './build/*' \
    -not -path './.dart_tool/*' \
    -not -path '*/.symlinks/*' \
    -not -path './patrol_test/*' \
    -not -path './integration_test/test_bundle.dart'
)

if [ "${#TARGETS[@]}" -eq 0 ]; then
  DUR=$(( $(rc_now_ms) - START ))
  rc_banner_skip "$STEP" "no dart files to format"
  rc_log_event "$STEP" "skip" "$DUR" "no files"
  exit 0
fi

if dart format --set-exit-if-changed "${TARGETS[@]}" >/dev/null 2>&1; then
  DUR=$(( $(rc_now_ms) - START ))
  rc_banner_ok "$STEP" "$DUR" ""
  rc_log_event "$STEP" "ok" "$DUR" ""
  exit 0
fi

DUR=$(( $(rc_now_ms) - START ))
rc_banner_fail "$STEP" "$DUR" "run: dart format ."
dart format --output=none --show=changed "${TARGETS[@]}" || true
rc_log_event "$STEP" "fail" "$DUR" "format drift — run: dart format ."
exit "$RC_EXIT_ANALYSIS"
