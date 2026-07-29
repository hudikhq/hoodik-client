#!/usr/bin/env python3
"""Aggregate a release-check run and regenerate the flake dashboard.

Reads per-job artifact directories under ./artifacts (laid out by
actions/download-artifact) plus a handful of GITHUB_* / RC_* env vars,
appends one JSON Lines record to .release-check/runs.jsonl, and
rewrites .release-check/dashboard.md from the last 20 records. Both live in
the gitignored scratch dir — run history is local observability, not
something the repository should carry.

Shape of each JSONL record:

    {
      "sha": "abcd1234...",
      "run_id": "12345678",
      "run_number": 42,
      "timestamp": "2026-04-19T02:17:03Z",
      "event": "schedule",
      "conclusion": "success" | "failure",
      "duration_ms": 3456000,
      "steps": [
        {"name": "fast",            "status": "ok",   "duration_ms": 182000, "retries": 0},
        {"name": "e2e-ios",         "status": "ok",   "duration_ms": 582000, "retries": 1},
        ...
      ],
      "mutation_kill_rate": 0.92,           // present when mutation-crypto ran
      "grandfather": [                       // baseline snapshot at this SHA
        {"path": "...", "lines": 1390, "target": 500}
      ]
    }

The dashboard itself is a simple Markdown table over the last 20 rows —
small enough to read at a glance, large enough to catch multi-day flake
patterns. No prose commentary; the point is observability, not storytelling.
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS_DIR = REPO_ROOT / "artifacts"
RUNS_JSONL = REPO_ROOT / ".release-check" / "runs.jsonl"
DASHBOARD_MD = REPO_ROOT / ".release-check" / "dashboard.md"
GRANDFATHER_JSON = REPO_ROOT / "scripts" / "release-check" / "grandfather.json"

# GitHub's `needs.<job>.result` vocabulary → our three-way status.
RESULT_TO_STATUS = {
    "success": "ok",
    "failure": "fail",
    "cancelled": "skip",
    "skipped": "skip",
}


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default) or default


def _parse_last_run_events(path: Path) -> list[dict]:
    if not path.is_file():
        return []
    events: list[dict] = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return events


def _duration_and_retries(events: Iterable[dict]) -> tuple[int, int]:
    """Roll up per-step events from a single job's last-run.json.

    A run with ≥1 event in status `warn` counts as one retry — the scripts
    already treat warn as "passed on a non-ideal path", which is the best
    proxy we have for flakes until Patrol surfaces per-test retry counts.
    """
    duration = 0
    retries = 0
    for event in events:
        duration += int(event.get("duration_ms", 0) or 0)
        if event.get("status") == "warn":
            retries += 1
    return duration, retries


def _mutation_kill_rate() -> float | None:
    for candidate in ARTIFACTS_DIR.rglob("mutation-crypto.json"):
        try:
            data = json.loads(candidate.read_text())
            rate = data.get("killRate")
            if isinstance(rate, (int, float)):
                return float(rate)
        except (OSError, json.JSONDecodeError):
            continue
    return None


def _grandfather_snapshot() -> list[dict]:
    try:
        data = json.loads(GRANDFATHER_JSON.read_text())
    except (OSError, json.JSONDecodeError):
        return []
    return list(data.get("files", []))


def _collect_steps() -> list[dict]:
    """Build one entry per known job name, whether or not its artifact uploaded."""
    job_env = {
        "fast": _env("RC_FAST", "skipped"),
        "e2e-ios": _env("RC_E2E_IOS", "skipped"),
        "e2e-android": _env("RC_E2E_ANDROID", "skipped"),
        "e2e-macos-smoke": _env("RC_E2E_MACOS_SMOKE", "skipped"),
    }
    steps: list[dict] = []
    for job_name, result in job_env.items():
        status = RESULT_TO_STATUS.get(result, "skip")
        artifact_dir = ARTIFACTS_DIR / job_name
        last_run = artifact_dir / "last-run.json"
        events = _parse_last_run_events(last_run)
        duration, retries = _duration_and_retries(events)
        steps.append(
            {
                "name": job_name,
                "status": status,
                "duration_ms": duration,
                "retries": retries,
            }
        )
    return steps


def _overall_conclusion(steps: Iterable[dict]) -> str:
    step_list = list(steps)
    if any(s["status"] == "fail" for s in step_list):
        return "failure"
    if all(s["status"] == "skip" for s in step_list):
        return "failure"
    return "success"


def _append_run(record: dict) -> None:
    RUNS_JSONL.parent.mkdir(parents=True, exist_ok=True)
    with RUNS_JSONL.open("a") as fh:
        fh.write(json.dumps(record, separators=(",", ":")) + "\n")


def _tail_runs(limit: int = 20) -> list[dict]:
    if not RUNS_JSONL.is_file():
        return []
    lines = RUNS_JSONL.read_text().splitlines()
    out: list[dict] = []
    for line in lines[-limit:]:
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


def _fmt_duration(ms: int) -> str:
    secs = ms // 1000
    if secs < 60:
        return f"{secs}s"
    mins, secs = divmod(secs, 60)
    return f"{mins}m{secs:02d}s"


def _status_icon(status: str) -> str:
    return {"ok": "pass", "fail": "FAIL", "skip": "skip"}.get(status, status)


def _render_dashboard(records: list[dict]) -> str:
    lines: list[str] = []
    lines.append("# release-check dashboard")
    lines.append("")
    lines.append(
        "Auto-generated from `.release-check/runs.jsonl`. Each row is one "
        "`release-check.yml` run; steps are the matrix jobs. `flakes` counts "
        "steps that passed on a non-green path (a proxy for retries until "
        "Patrol exposes true retry counts)."
    )
    lines.append("")
    if not records:
        lines.append("_No runs recorded yet._")
        lines.append("")
        return "\n".join(lines)

    header = "| Run | Date | SHA | Event | Conclusion | fast | e2e-ios | e2e-android | e2e-macos-smoke | Flakes | Mutation |"
    divider = "|---|---|---|---|---|---|---|---|---|---|---|"
    lines.append(header)
    lines.append(divider)

    for record in reversed(records):
        steps = {s["name"]: s for s in record.get("steps", [])}
        flakes = sum(s.get("retries", 0) for s in steps.values())
        mutation = record.get("mutation_kill_rate")
        mutation_str = f"{mutation * 100:.0f}%" if isinstance(mutation, (int, float)) else "—"
        short_sha = (record.get("sha") or "")[:7] or "—"
        run_id = record.get("run_id") or record.get("run_number") or "—"
        date = (record.get("timestamp") or "")[:10] or "—"
        conclusion = record.get("conclusion") or "—"
        row = [
            f"[{run_id}](#)",
            date,
            f"`{short_sha}`",
            record.get("event", "—"),
            conclusion,
            _render_step(steps.get("fast")),
            _render_step(steps.get("e2e-ios")),
            _render_step(steps.get("e2e-android")),
            _render_step(steps.get("e2e-macos-smoke")),
            str(flakes),
            mutation_str,
        ]
        lines.append("| " + " | ".join(row) + " |")

    lines.append("")
    latest = records[-1]
    grandfather = latest.get("grandfather") or []
    if grandfather:
        lines.append("## Grandfather list (latest run)")
        lines.append("")
        lines.append("| File | Current lines | Target |")
        lines.append("|---|---:|---:|")
        for entry in grandfather:
            lines.append(
                f"| `{entry.get('path', '—')}` | {entry.get('lines', '—')} | {entry.get('target', '—')} |"
            )
        lines.append("")

    return "\n".join(lines)


def _render_step(step: dict | None) -> str:
    if not step:
        return "—"
    icon = _status_icon(step.get("status", "skip"))
    dur = _fmt_duration(int(step.get("duration_ms", 0)))
    retries = step.get("retries", 0)
    if retries:
        return f"{icon} ({dur}, +{retries}f)"
    return f"{icon} ({dur})"


def main() -> int:
    sha = _env("RC_SHA", _env("GITHUB_SHA", "unknown"))
    run_id = _env("RC_RUN_ID", _env("GITHUB_RUN_ID", "local"))
    run_number_raw = _env("RC_RUN_NUMBER", _env("GITHUB_RUN_NUMBER", "0"))
    try:
        run_number = int(run_number_raw)
    except ValueError:
        run_number = 0
    event = _env("RC_EVENT", _env("GITHUB_EVENT_NAME", "local"))

    steps = _collect_steps()
    conclusion = _overall_conclusion(steps)
    duration_ms = sum(int(s.get("duration_ms", 0)) for s in steps)

    record = {
        "sha": sha,
        "run_id": run_id,
        "run_number": run_number,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "event": event,
        "conclusion": conclusion,
        "duration_ms": duration_ms,
        "steps": steps,
        "grandfather": _grandfather_snapshot(),
    }
    mutation = _mutation_kill_rate()
    if mutation is not None:
        record["mutation_kill_rate"] = mutation

    _append_run(record)
    DASHBOARD_MD.parent.mkdir(parents=True, exist_ok=True)
    DASHBOARD_MD.write_text(_render_dashboard(_tail_runs(20)))

    print(f"dashboard: wrote {RUNS_JSONL.relative_to(REPO_ROOT)} + {DASHBOARD_MD.relative_to(REPO_ROOT)}")
    print(f"dashboard: run {run_number} / sha {sha[:7]} / conclusion {conclusion}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
