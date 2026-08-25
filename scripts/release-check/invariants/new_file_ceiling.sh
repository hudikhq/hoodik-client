#!/usr/bin/env bash
# Sub-check: any .dart file added since the baseline tag must be under the
# 500-line hard ceiling. Grandfather-listed files are exempt (they have their
# own rule). Generated files — lib/src/rust/, the drift schema snapshots,
# `*.g.dart` — are exempt; their size is the generator's business.

set -euo pipefail

SUB_START=$(rc_now_ms)

CEILING=500

if [ -z "$BASELINE_TAG" ]; then
  # In permissive mode we still want a signal: any .dart file over the
  # ceiling in the working tree, tracked or not.
  BASELINE_TAG=""
fi

GF_FILE="$SCRIPT_DIR/grandfather.json"
GRANDFATHER_PATHS=""
if [ -f "$GF_FILE" ] && command -v python3 >/dev/null 2>&1; then
  GRANDFATHER_PATHS="$(
    python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    for entry in d.get("files", []):
        print(entry["path"])
except Exception:
    pass
' "$GF_FILE"
  )"
fi

is_grandfathered() {
  local path="$1"
  [ -z "$GRANDFATHER_PATHS" ] && return 1
  while IFS= read -r gf; do
    [ "$path" = "$gf" ] && return 0
  done <<< "$GRANDFATHER_PATHS"
  return 1
}

is_exempt_path() {
  local path="$1"
  case "$path" in
    lib/src/rust/*) return 0 ;;
    lib/l10n/generated/*) return 0 ;;
    test/generated/migrations/*) return 0 ;;
    *.g.dart) return 0 ;;
    *.freezed.dart) return 0 ;;
    rust_builder/cargokit/*) return 0 ;;
    build/*) return 0 ;;
    .dart_tool/*) return 0 ;;
  esac
  return 1
}

# Added files = (files in `git diff --diff-filter=A` vs baseline) ∪ (untracked
# .dart files). An unstaged new file shows up only as untracked; a committed
# new file shows up only in the diff.
ADDED_FILES=""
if [ -n "$BASELINE_TAG" ]; then
  ADDED_FILES+="$(git diff --diff-filter=A --name-only "$BASELINE_TAG" -- '*.dart' 2>/dev/null || true)"$'\n'
fi
ADDED_FILES+="$(git ls-files --others --exclude-standard -- '*.dart' 2>/dev/null || true)"

FAILURES=""
while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ -f "$file" ] || continue
  is_exempt_path "$file" && continue
  is_grandfathered "$file" && continue
  lines="$(wc -l < "$file" | tr -d ' ')"
  if [ "$lines" -ge "$CEILING" ]; then
    FAILURES+="  $file: $lines lines (ceiling $CEILING)"$'\n'
  fi
done <<< "$(printf '%s\n' "$ADDED_FILES" | sort -u)"

SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
if [ -z "$FAILURES" ]; then
  printf 'ok %s no new .dart file ≥ %s lines\n' "$SUB_DUR" "$CEILING" >> "$SUB_LOG"
  exit 0
fi

printf 'fail %s new .dart files over %s-line ceiling\n' "$SUB_DUR" "$CEILING" >> "$SUB_LOG"
printf '%s' "$FAILURES" >> "$SUB_LOG.detail"
exit 1
