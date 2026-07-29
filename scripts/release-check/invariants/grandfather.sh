#!/usr/bin/env bash
# Sub-check: files on the grandfather list must not grow past their baseline.
# Equal or fewer lines = pass. More lines = fail.
# Reads scripts/release-check/grandfather.json.

set -euo pipefail

SUB_START=$(rc_now_ms)

GF_FILE="$SCRIPT_DIR/grandfather.json"

if [ ! -f "$GF_FILE" ]; then
  SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
  printf 'warn %s grandfather.json not found — skipping\n' "$SUB_DUR" >> "$SUB_LOG"
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
  printf 'warn %s python3 not on PATH — skipping grandfather\n' "$SUB_DUR" >> "$SUB_LOG"
  exit 0
fi

# Emit one "path baseline_lines" line per entry for shell iteration.
ENTRIES="$(
  python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except Exception as e:
    sys.stderr.write(f"grandfather.json parse error: {e}\n")
    sys.exit(2)
for f in data.get("files", []):
    print(f["path"], f["lines"])
' "$GF_FILE"
)"

if [ -z "$ENTRIES" ]; then
  SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
  printf 'ok %s grandfather list empty — nothing to check\n' "$SUB_DUR" >> "$SUB_LOG"
  exit 0
fi

FAILURES=""
REMOVED=""
while IFS=' ' read -r path baseline; do
  [ -z "$path" ] && continue
  if [ ! -f "$path" ]; then
    # File deleted entirely — counts as shrunk to zero. Note it for the
    # detail log so the operator knows to drop it from grandfather.json,
    # but it's not a failure.
    REMOVED+="  removed: $path (baseline $baseline → 0; drop from grandfather.json)"$'\n'
    continue
  fi
  current="$(wc -l < "$path" | tr -d ' ')"
  if [ "$current" -gt "$baseline" ]; then
    FAILURES+="  $path grew: baseline $baseline → current $current"$'\n'
  fi
done <<< "$ENTRIES"

SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
if [ -z "$FAILURES" ]; then
  printf 'ok %s grandfather list held the line\n' "$SUB_DUR" >> "$SUB_LOG"
  [ -n "$REMOVED" ] && printf '%s' "$REMOVED" >> "$SUB_LOG.detail"
  exit 0
fi

printf 'fail %s grandfather list grew\n' "$SUB_DUR" >> "$SUB_LOG"
printf '%s' "$FAILURES" >> "$SUB_LOG.detail"
[ -n "$REMOVED" ] && printf '%s' "$REMOVED" >> "$SUB_LOG.detail"
exit 1
