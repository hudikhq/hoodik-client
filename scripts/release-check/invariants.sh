#!/usr/bin/env bash
# Usage: scripts/release-check/invariants.sh
#
# Runs 5 sub-checks:
#   1. forbidden_markers — no new TODO/FIXME/XXX/HACK/unimplemented!/todo!/
#      panic!/#[allow(dead_code)]/#[allow(unused)]/not yet supported/... lines
#      added since the baseline tag.
#   2. grandfather       — files listed in grandfather.json must not grow.
#   3. new_file_ceiling  — any .dart file added since the baseline tag must
#      be under 500 lines.
#   4. ffi_drift         — regenerating flutter_rust_bridge bindings must be
#      a no-op.
#   5. screenshots       — for platforms marked Released in store-status.md,
#      screenshots must be newer than the baseline tag. Warn only.
#
# Baseline tag resolution: `git describe --tags --abbrev=0`. If no tag exists
# we drop into permissive mode — only forbidden_markers and new_file_ceiling
# run on the whole working tree, grandfather is still checked (absolute
# baseline), and ffi_drift + screenshots skip with a warning.
#
# Exit codes:
#   0 — all sub-checks ok or warn
#   $RC_EXIT_INVARIANTS (6) — at least one sub-check failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

export SCRIPT_DIR

STEP="invariants"
START=$(rc_now_ms)

BASELINE_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
export BASELINE_TAG

PERMISSIVE=0
if [ -z "$BASELINE_TAG" ]; then
  PERMISSIVE=1
  rc_banner_warn "$STEP" "no git tag found — running in permissive mode"
fi

SUB_LOG="$(mktemp -t hoodik-invariants-XXXXXX)"
SUB_DETAIL="$SUB_LOG.detail"
: > "$SUB_DETAIL"
export SUB_LOG

cleanup() { rm -f "$SUB_LOG" "$SUB_DETAIL"; }
trap cleanup EXIT

run_sub() {
  local name="$1" script="$2"
  if [ ! -x "$script" ]; then
    printf 'warn 0 %s: script not executable\n' "$name" >> "$SUB_LOG"
    return 0
  fi
  local old_count
  old_count="$(wc -l < "$SUB_LOG" | tr -d ' ')"
  # shellcheck disable=SC1090
  if ! (source "$script"); then
    if [ "$(wc -l < "$SUB_LOG" | tr -d ' ')" = "$old_count" ]; then
      printf 'fail 0 %s: script exited non-zero with no status line\n' "$name" >> "$SUB_LOG"
    fi
  fi
  # Force a trailing status line to be attributed to this sub-check.
  local latest
  latest="$(tail -1 "$SUB_LOG" || true)"
  case "$latest" in
    ok\ *|fail\ *|warn\ *) ;;
    *)
      printf 'warn 0 %s: no status emitted\n' "$name" >> "$SUB_LOG"
      ;;
  esac
}

# forbidden_markers runs in all modes — it's the cheapest meaningful signal.
run_sub "forbidden_markers" "$SCRIPT_DIR/invariants/forbidden_markers.sh"

# grandfather runs even in permissive mode (the JSON has its own baseline).
run_sub "grandfather" "$SCRIPT_DIR/invariants/grandfather.sh"

# new_file_ceiling runs in all modes. Permissive mode scans only untracked
# files (no tag → no diff); normal mode scans added-since-tag plus untracked.
run_sub "new_file_ceiling" "$SCRIPT_DIR/invariants/new_file_ceiling.sh"

if [ "$PERMISSIVE" = "0" ]; then
  run_sub "ffi_drift"   "$SCRIPT_DIR/invariants/ffi_drift.sh"
  run_sub "screenshots" "$SCRIPT_DIR/invariants/screenshots.sh"
else
  printf 'warn 0 ffi_drift skipped (permissive mode)\n' >> "$SUB_LOG"
  printf 'warn 0 screenshots skipped (permissive mode)\n' >> "$SUB_LOG"
fi

FAILS=0
WARNS=0
OKS=0
NAMES=(forbidden_markers grandfather new_file_ceiling ffi_drift screenshots)
NAME_IDX=0
while IFS= read -r line; do
  status="${line%% *}"
  case "$status" in
    ok)   OKS=$((OKS + 1)) ;;
    warn) WARNS=$((WARNS + 1)) ;;
    fail) FAILS=$((FAILS + 1)) ;;
  esac
  name="${NAMES[$NAME_IDX]:-unknown}"
  rest="${line#* }"        # duration + message
  dur="${rest%% *}"
  msg="${rest#* }"
  printf '[release-check]   %-20s %-4s (%sms) %s\n' "$name" "$status" "$dur" "$msg"
  NAME_IDX=$((NAME_IDX + 1))
done < "$SUB_LOG"

if [ -s "$SUB_DETAIL" ]; then
  printf '\n[release-check] invariant details:\n' >&2
  sed 's/^/  /' "$SUB_DETAIL" >&2
fi

DUR=$(( $(rc_now_ms) - START ))
SUMMARY="$OKS ok, $WARNS warn, $FAILS fail (baseline=${BASELINE_TAG:-<none>})"

if [ "$FAILS" -gt 0 ]; then
  rc_banner_fail "$STEP" "$DUR" "$SUMMARY"
  rc_log_event "$STEP" "fail" "$DUR" "$SUMMARY"
  exit "$RC_EXIT_INVARIANTS"
fi

if [ "$WARNS" -gt 0 ]; then
  rc_banner_ok "$STEP" "$DUR" "$SUMMARY"
  rc_log_event "$STEP" "ok" "$DUR" "$SUMMARY"
  exit 0
fi

rc_banner_ok "$STEP" "$DUR" "$SUMMARY"
rc_log_event "$STEP" "ok" "$DUR" "$SUMMARY"
exit 0
