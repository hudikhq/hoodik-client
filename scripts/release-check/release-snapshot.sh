#!/usr/bin/env bash
# Refresh scripts/release-check/grandfather.json after a release tag lands.
#
# For each file listed in grandfather.json, re-measure `wc -l` and write the
# current count back into the `lines` field. Also updates `baselineTag` to
# the nearest git tag and `baselineDate` to today. Files that no longer
# exist (i.e. fully decomposed away) are dropped from the list and noted in
# the summary — the rule says "must shrink", so deletion counts as the
# ultimate shrink.
#
# Usage: just release-snapshot  OR  scripts/release-check/release-snapshot.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GF_FILE="$SCRIPT_DIR/grandfather.json"

if [ ! -f "$GF_FILE" ]; then
  echo "release-snapshot: grandfather.json missing at $GF_FILE" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "release-snapshot: python3 required but not on PATH" >&2
  exit 1
fi

CURRENT_TAG="$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || true)"
if [ -z "$CURRENT_TAG" ]; then
  echo "release-snapshot: no git tag found — cut a release tag first, then rerun" >&2
  exit 1
fi

TODAY="$(date -u +%Y-%m-%d)"

python3 - "$GF_FILE" "$REPO_ROOT" "$CURRENT_TAG" "$TODAY" <<'PY'
import json
import sys
from pathlib import Path

gf_path = Path(sys.argv[1])
repo_root = Path(sys.argv[2])
tag = sys.argv[3]
today = sys.argv[4]

data = json.loads(gf_path.read_text())
files = data.get("files", [])

new_files = []
removed = []
updates = []

for entry in files:
    rel = entry.get("path")
    if not rel:
        continue
    abs_path = repo_root / rel
    if not abs_path.is_file():
        removed.append((rel, entry.get("lines", 0)))
        continue
    current = sum(1 for _ in abs_path.open("rb"))
    previous = entry.get("lines", current)
    new_entry = dict(entry)
    new_entry["lines"] = current
    new_files.append(new_entry)
    updates.append((rel, previous, current))

data["files"] = new_files
data["baselineTag"] = tag
data["baselineDate"] = today

gf_path.write_text(json.dumps(data, indent=2) + "\n")

print(f"release-snapshot: baseline updated to {tag} ({today})")
for rel, prev, current in updates:
    delta = current - prev
    arrow = "=" if delta == 0 else ("+" if delta > 0 else "")
    print(f"  {rel}: {prev} -> {current} ({arrow}{delta})")
for rel, prev in removed:
    print(f"  {rel}: {prev} -> removed (file decomposed away)")

if not new_files and not removed:
    print("  grandfather list is empty — nothing to track")
PY

echo "release-snapshot: wrote $GF_FILE"
