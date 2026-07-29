#!/usr/bin/env bash
# Sub-check: if docs/store-status.md says "Released" for a platform, the
# matching release/screenshots/output/<platform>_*.png must be newer than
# the baseline tag's commit date. Stale = warning only, never a failure.

set -euo pipefail

SUB_START=$(rc_now_ms)

STATUS_FILE="docs/store-status.md"
OUTPUT_DIR="release/screenshots/output"

if [ ! -f "$STATUS_FILE" ]; then
  SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
  printf 'warn %s %s not found — skipping screenshot freshness\n' \
    "$SUB_DUR" "$STATUS_FILE" >> "$SUB_LOG"
  exit 0
fi

if [ ! -d "$OUTPUT_DIR" ]; then
  SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
  printf 'warn %s %s/ not found — skipping screenshot freshness\n' \
    "$SUB_DUR" "$OUTPUT_DIR" >> "$SUB_LOG"
  exit 0
fi

if [ -z "$BASELINE_TAG" ]; then
  SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
  printf 'warn %s no baseline tag — skipping screenshot freshness\n' \
    "$SUB_DUR" >> "$SUB_LOG"
  exit 0
fi

BASELINE_EPOCH="$(git log -1 --format=%ct "$BASELINE_TAG" 2>/dev/null || echo 0)"
if [ "$BASELINE_EPOCH" = "0" ]; then
  SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
  printf 'warn %s could not read tag date — skipping\n' "$SUB_DUR" >> "$SUB_LOG"
  exit 0
fi

# Scrape which platforms are marked Released. The table row looks like:
# | Android | Google Play Store | Released | 2026-04-01 |
RELEASED_PLATFORMS="$(
  grep -Ei '^\| *(android|ios|macos|linux|windows) *\|.*\| *Released *\|' "$STATUS_FILE" \
    | awk -F'|' '{gsub(/^ +| +$/, "", $2); print tolower($2)}' \
    || true
)"

if [ -z "$RELEASED_PLATFORMS" ]; then
  SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
  printf 'ok %s no platforms marked Released\n' "$SUB_DUR" >> "$SUB_LOG"
  exit 0
fi

# iOS ships two screenshot sets under their device names, so there is no
# `ios_` prefix in output/. Every other platform names its files after itself.
prefixes_for() {
  case "$1" in
    ios) printf 'iphone ipad' ;;
    *) printf '%s' "$1" ;;
  esac
}

STALE=""
FRESH=""
while IFS= read -r platform; do
  [ -z "$platform" ] && continue
  matches=0
  newest=0
  for prefix in $(prefixes_for "$platform"); do
    for f in "$OUTPUT_DIR/${prefix}"_*.png; do
      [ -f "$f" ] || continue
      matches=$((matches + 1))
      # GNU stat first: on current Linux CI runners `stat -f %m` returns filesystem
      # status and exits 0 instead of failing through, so `mtime` would be a
      # multi-line string and the `-gt` test below would abort under `set -e`. The
      # BSD/macOS `stat -c` errors cleanly, so ordering `-c` ahead of `-f %m` works
      # on both.
      mtime="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)"
      if [ "$mtime" -gt "$newest" ]; then
        newest="$mtime"
      fi
    done
  done
  if [ "$matches" = "0" ]; then
    STALE+="  $platform: no screenshots in $OUTPUT_DIR"$'\n'
    continue
  fi
  if [ "$newest" -lt "$BASELINE_EPOCH" ]; then
    STALE+="  $platform: newest screenshot older than $BASELINE_TAG"$'\n'
  else
    FRESH+="$platform "
  fi
done <<< "$RELEASED_PLATFORMS"

SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
if [ -z "$STALE" ]; then
  printf 'ok %s screenshots fresh: %s\n' "$SUB_DUR" "${FRESH% }" >> "$SUB_LOG"
  exit 0
fi

printf 'warn %s stale screenshots\n' "$SUB_DUR" >> "$SUB_LOG"
printf '%s' "$STALE" >> "$SUB_LOG.detail"
exit 0
