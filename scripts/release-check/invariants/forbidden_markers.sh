#!/usr/bin/env bash
# Sub-check: no new forbidden markers added since the baseline tag.
# Sources env from invariants.sh ($BASELINE_TAG, $SUB_LOG).
# Writes a sub-result line to $SUB_LOG: "ok|fail|warn <duration_ms> <message>".

set -euo pipefail

SUB_START=$(rc_now_ms)

GENERAL_PATTERN='TODO|FIXME|XXX|HACK|unimplemented!|todo!|#\[allow\(dead_code\)\]|#\[allow\(unused\)\]|not yet supported|not yet implemented|not implemented'
PANIC_PATTERN='panic!'

is_excluded_path() {
  local path="$1"
  case "$path" in
    lib/src/rust/*|*/lib/src/rust/*) return 0 ;;
    rust_builder/cargokit/*|*/rust_builder/cargokit/*) return 0 ;;
    .release-check/*) return 0 ;;
  esac
  return 1
}

# panic! is allowed in test code — rust test modules, Dart test directories,
# and the integration_test tree (which is itself a test harness). Any `.rs`
# file whose path contains `/tests/` or ends in `_test.rs`/`tests.rs` counts
# as test code.
is_test_path() {
  local path="$1"
  case "$path" in
    */tests/*|tests/*) return 0 ;;
    *_test.rs|*/tests.rs) return 0 ;;
    integration_test/*|*/integration_test/*) return 0 ;;
    test/*|*/test/*) return 0 ;;
  esac
  return 1
}

scan_added_lines() {
  local path="$1" content="$2"
  local hits=""
  local general
  # Case-sensitive — TODO/FIXME/XXX/HACK are uppercase-only by convention;
  # `-i` would false-match substrings like "toDouble" or "panic" in English
  # prose, while Rust's `unimplemented!` / `todo!` / `panic!` are always
  # lowercase.
  general="$(printf '%s\n' "$content" | grep -En "$GENERAL_PATTERN" || true)"
  if [ -n "$general" ]; then
    while IFS= read -r line; do
      hits+="$path: $line"$'\n'
    done <<< "$general"
  fi
  if ! is_test_path "$path"; then
    local panic
    panic="$(printf '%s\n' "$content" | grep -En "$PANIC_PATTERN" || true)"
    if [ -n "$panic" ]; then
      while IFS= read -r line; do
        hits+="$path: $line"$'\n'
      done <<< "$panic"
    fi
  fi
  printf '%s' "$hits"
}

append_hits() {
  # `$(...)` strips trailing newlines — manually re-append one so each scan's
  # hits don't merge onto the previous scan's last line.
  local new="$1"
  [ -z "$new" ] && return 0
  printf '%s\n' "$new"
}

collect_hits_from_tracked_diff() {
  local current_path=""
  local current_added=""
  local line
  while IFS= read -r line; do
    case "$line" in
      "diff --git a/"*)
        if [ -n "$current_path" ] && [ -n "$current_added" ]; then
          append_hits "$(scan_added_lines "$current_path" "$current_added")"
        fi
        current_path="${line#diff --git a/}"
        current_path="${current_path%% b/*}"
        current_added=""
        ;;
      "+++ b/"*)
        current_path="${line#+++ b/}"
        ;;
      "+++ /dev/null")
        current_path=""
        ;;
      +*)
        case "$line" in
          +++*) ;;
          *)
            if [ -n "$current_path" ] && ! is_excluded_path "$current_path"; then
              current_added+="${line#+}"$'\n'
            fi
            ;;
        esac
        ;;
    esac
  done
  if [ -n "$current_path" ] && [ -n "$current_added" ]; then
    append_hits "$(scan_added_lines "$current_path" "$current_added")"
  fi
}

collect_hits_from_untracked() {
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    is_excluded_path "$file" && continue
    case "$file" in
      lib/*|rust/src/*|integration_test/*) ;;
      *) continue ;;
    esac
    [ -f "$file" ] || continue
    local content
    content="$(cat "$file")"
    append_hits "$(scan_added_lines "$file" "$content")"
  done < <(git ls-files --others --exclude-standard)
}

DIFF_SCOPE=(lib rust/src integration_test)
ALL_HITS=""
if [ -n "$BASELINE_TAG" ]; then
  ALL_HITS+="$(
    git diff "$BASELINE_TAG" -- "${DIFF_SCOPE[@]}" \
      | collect_hits_from_tracked_diff
  )"$'\n'
fi
ALL_HITS+="$(collect_hits_from_untracked)"

TRIMMED_HITS="$(printf '%s' "$ALL_HITS" | sed '/^$/d')"

if [ -z "$TRIMMED_HITS" ]; then
  SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
  printf 'ok %s %s\n' "$SUB_DUR" "no new forbidden markers since ${BASELINE_TAG:-root}" >> "$SUB_LOG"
  exit 0
fi

SUB_DUR=$(( $(rc_now_ms) - SUB_START ))
printf 'fail %s forbidden markers added since %s\n' \
  "$SUB_DUR" "${BASELINE_TAG:-root}" >> "$SUB_LOG"
printf '%s\n' "$TRIMMED_HITS" >> "$SUB_LOG.detail"
exit 1
