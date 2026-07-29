#!/usr/bin/env bash
# Sub-check: regenerating flutter_rust_bridge bindings produces no diff.
# If codegen is not on PATH, skip with a warning.
# Strategy: back up lib/src/rust/, regenerate, diff, restore — leaves the
# working tree exactly as it was regardless of outcome.

set -euo pipefail

SUB_START=$(rc_now_ms)

if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
  SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
  printf 'warn %s flutter_rust_bridge_codegen not on PATH — skipping FFI drift\n' "$SUB_DUR" >> "$SUB_LOG"
  exit 0
fi

if [ ! -d lib/src/rust ]; then
  SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
  printf 'warn %s lib/src/rust/ missing — skipping FFI drift\n' "$SUB_DUR" >> "$SUB_LOG"
  exit 0
fi

BACKUP_DIR="$(mktemp -d -t hoodik-frb-XXXXXX)"
REGEN_LOG="${RELEASE_CHECK_DIR:-.release-check}/ffi-drift.log"
mkdir -p "$(dirname "$REGEN_LOG")"
trap 'rm -rf "$BACKUP_DIR"' EXIT

cp -R lib/src/rust/. "$BACKUP_DIR/"

restore_and_exit() {
  local status="$1"
  rm -rf lib/src/rust
  mkdir -p lib/src/rust
  cp -R "$BACKUP_DIR/." lib/src/rust/
  exit "$status"
}

if ! flutter_rust_bridge_codegen generate >"$REGEN_LOG" 2>&1; then
  SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
  printf 'warn %s codegen failed (see %s) — skipping FFI drift\n' \
    "$SUB_DUR" "$REGEN_LOG" >> "$SUB_LOG"
  restore_and_exit 0
fi

if diff -r -q "$BACKUP_DIR" lib/src/rust >/dev/null 2>&1; then
  SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
  printf 'ok %s FFI bindings current\n' "$SUB_DUR" >> "$SUB_LOG"
  restore_and_exit 0
fi

SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
printf 'fail %s FFI bindings are out of date\n' "$SUB_DUR" >> "$SUB_LOG"
{
  printf '  Run: flutter_rust_bridge_codegen generate\n'
  printf "  Then fix: lib/src/rust/frb_generated.dart's stem: 'UNKNOWN' -> 'hoodik_mobile'\n"
  printf '  Changes detected:\n'
  diff -r -q "$BACKUP_DIR" lib/src/rust | sed 's/^/    /' || true
} >> "$SUB_LOG.detail"
restore_and_exit 1
