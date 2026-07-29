#!/usr/bin/env bash
# Usage: scripts/release-check/summary.sh
# Aggregates .release-check/last-run.json into a banner + version bump hint.
# Exit code reflects the worst step seen.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

if [ ! -f "$RELEASE_CHECK_LOG" ]; then
  echo "[release-check] summary: no events in $RELEASE_CHECK_LOG — was anything run?" >&2
  exit 0
fi

python3 - "$RELEASE_CHECK_LOG" <<'PY'
import json
import sys
from pathlib import Path

events = []
with Path(sys.argv[1]).open() as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            pass

if not events:
    print('[release-check] summary: empty log')
    sys.exit(0)

total_ms = sum(int(e.get('duration_ms', 0) or 0) for e in events)
any_fail = any(e.get('status') == 'fail' for e in events)
any_warn = any(e.get('status') == 'warn' for e in events)

def fmt_duration(ms):
    s = ms // 1000
    m, s = divmod(s, 60)
    if m:
        return f'{m}m {s}s'
    return f'{s}s'

print()
print('=' * 64)
if any_fail:
    print(f'  FAILED                                   total {fmt_duration(total_ms)}')
else:
    print(f'  PASSED                                   total {fmt_duration(total_ms)}')
print('=' * 64)
for e in events:
    print(f"  {e['step']:<22} {e['status']:<6} {fmt_duration(int(e.get('duration_ms', 0) or 0)):<8} {e.get('message', '')}")
print()

if any_fail:
    sys.exit(1)
PY

# Suggest a version bump based on commit subjects since the last tag.
LAST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
if [ -n "$LAST_TAG" ]; then
  COMMITS="$(git log "$LAST_TAG..HEAD" --pretty=%s 2>/dev/null || true)"
  if [ -n "$COMMITS" ]; then
    # Heuristic: "feat!" / "BREAKING" → major; "feat:" → minor; else patch.
    BUMP="patch"
    if echo "$COMMITS" | grep -qE '^feat!|BREAKING CHANGE'; then
      BUMP="major"
    elif echo "$COMMITS" | grep -qE '^feat(\(.*\))?:'; then
      BUMP="minor"
    fi
    echo "  Last tag: $LAST_TAG"
    echo "  Suggested bump: $BUMP ($(echo "$COMMITS" | wc -l | tr -d ' ') commits)"
    echo
  fi
fi
