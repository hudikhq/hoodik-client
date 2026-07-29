# release-check

`just release-check` is the single gate before tagging a release. It runs
the full ladder from `dart format` to Patrol E2E on real simulators and
release-mode builds. Green = ship. Red = don't.

## Phase 1 status

Scaffolding only. The justfile recipes and step scripts exist; the
Phase 1 E2E tests (onboarding, upload-download, logout) are in
`integration_test/e2e/` and will pass once the ephemeral hoodik Docker
server and a simulator/emulator are available.

## Phase 2 status (invariants)

All five invariants are wired in:

| # | Sub-check | Script | Effect |
|--:|-----------|--------|--------|
| 1 | forbidden markers (diff-based since baseline tag) | `invariants/forbidden_markers.sh` | fail |
| 2 | grandfather list shrink | `invariants/grandfather.sh` (reads `grandfather.json`) | fail |
| 3 | new .dart file under 500-line ceiling | `invariants/new_file_ceiling.sh` | fail |
| 4 | FFI codegen drift | `invariants/ffi_drift.sh` (via `flutter_rust_bridge_codegen`) | fail |
| 5 | store-screenshot freshness vs baseline tag | `invariants/screenshots.sh` | warn |

`invariants.sh` orchestrates, aggregates sub-statuses, and exits with
`RC_EXIT_INVARIANTS` (6) if any sub-check failed. Warnings do not fail
the step. Tests for each sub-check live at
`test/tools/invariants_test.dart`.

`grandfather.json` is the machine-readable baseline. Update it via
`just release-snapshot` after a successful tag — do not hand-edit mid-
sprint.

## Golden image tests

Sprint T Phase 2 lands a 40-PNG golden suite under `test/goldens/` (5
screens × 8 viewport/theme/platform variants) that runs as part of
`flutter test` and therefore as part of `just unit`. The goldens are
stored via Git LFS — the `.gitattributes` entry scopes LFS to
`test/goldens/**/*.png` only.

Regeneration has two modes:

| Recipe | Runs | Notes |
|---|---|---|
| `just goldens-update-local` | Host flutter_test renderer | What the committed baselines were produced with. |
| `just goldens-update` | Docker `ghcr.io/cirruslabs/flutter:3.41.6` | More reproducible, but not what the current baselines came from. |

**The committed baselines are host-generated.** After regenerating, read the
diff: only the screens you changed should move. Every PNG changing means your
renderer differs from the one that produced the baselines, and committing that
swaps the drift onto everyone else rather than removing it.

Moving the baselines into the container is worth doing — it ends the drift
question — but it rewrites all 40 PNGs in one commit and wants to be its own
change, not a side effect of a UI tweak.

Note that **`just unit` does not run the golden suite**: `unit.sh` scopes to
`test/core/` and `test/features/`, so goldens execute only under a bare
`flutter test`. A golden regression will not fail CI.

The harness
(`test/goldens/golden_harness.dart`) fixes the wall clock to
`2026-04-20 12:00 UTC`, pre-populates decrypt caches with deterministic
fakes, and swallows `RenderFlex` overflow diagnostics caused by the
Ahem test font being wider than any real font. Real regressions still
bubble through as pixel diffs.

## Prerequisites

Install these once on each dev machine:

| Tool | Install | Used by |
|------|---------|---------|
| `just` | `brew install just` | All recipes |
| `docker` | https://docs.docker.com/get-docker/ | Ephemeral hoodik server |
| `patrol_cli` | `dart pub global activate patrol_cli` | E2E tests |
| iOS simulator | Xcode > Settings > Platforms | `e2e-ios`, `e2e-macos-smoke` |
| Android AVD | Android Studio > Device Manager (`Pixel_8_API_34`) | `e2e-android` |

Sibling repo required for the Rust path patches:

```
git clone https://github.com/hudikhq/hoodik ../hoodik
```

## Recipes

```bash
just release-check          # full sequence — simulators + builds (~35 min)
just release-check-fast     # format + analyze + invariants + unit + integration (~3 min)

just preflight              # verify binaries + repo layout
just format                 # dart format --set-exit-if-changed
just analyze                # flutter analyze --fatal-infos --fatal-warnings
just invariants             # forbidden markers + grandfather + 500-line ceiling + FFI drift + screenshot freshness
just unit                   # test/core + test/features with coverage
just integration            # integration_test/ non-e2e
just e2e-ios                # Patrol iOS (HOODIK_IOS_DEVICE overrides device)
just e2e-android            # Patrol Android (HOODIK_ANDROID_DEVICE overrides)
just e2e-macos-smoke        # Patrol macOS, tags=smoke only
just build                  # iOS no-codesign, APK, macOS
just summary                # aggregate .release-check/last-run.json

just docker-hoodik-up       # boot ephemeral hoodik server on localhost:5443
just docker-hoodik-down     # tear it down

just goldens-update-local   # regenerate goldens on the host (matches the baselines)
just goldens-update         # regenerate goldens under docker Linux (rewrites all 40)
```

## Environment variables

| Var | Default | Purpose |
|-----|---------|---------|
| `HOODIK_IOS_DEVICE` | `iPhone 16` | iOS simulator name |
| `HOODIK_ANDROID_DEVICE` | `Pixel_8_API_34` | Android AVD name |
| `HOODIK_E2E_URL` | `http://127.0.0.1:5443` | Ephemeral server URL |
| `HOODIK_E2E_EMAIL` | `e2e@hoodik.local` | Demo account email |
| `HOODIK_E2E_PASSWORD` | `e2e-user-password-1234` | Demo account password |
| `HOODIK_E2E_PIN` | `123456` | Demo PIN |
| `HOODIK_IMAGE` | `hudik/hoodik:latest` | Docker image for ephemeral server |

## Exit codes (spec §5)

| Code | Meaning |
|-----:|---------|
| 0 | All checks passed. Safe to tag. |
| 1 | Format / static analysis failed. |
| 2 | Unit or widget tests failed. |
| 3 | Integration tests failed. |
| 4 | E2E tests failed. |
| 5 | Build verify failed. |
| 6 | Invariant check failed. |
| 7 | Preflight failed. |

## Known gaps (Phase 1)

- **Image pull.** `HOODIK_IMAGE` defaults to `hudik/hoodik:latest`. Override
  via env var to pin to a specific tag (e.g. `v1.15.0`).
- **Video fixture.** `integration_test/fixtures.dart` writes a 64 KB
  random blob to `30s.mp4` — not a valid video. The media_kit preview
  test (flow #6) will fail against it and should be skipped or its
  fixture replaced with a real bundled asset in Phase 2.
- **Invariants.** All five sub-checks are enforced; see the Phase 2
  status table above.
- **Patrol CLI.** Not installed automatically on the user's machine;
  `preflight.sh` warns and `e2e-*.sh` fails hard. Install with:
  `dart pub global activate patrol_cli`.
- **First-run permissiveness.** If no Git tag exists, `invariants.sh`
  skips with a warning. A baseline tag must exist for the check to be
  meaningful.
- **Drift wipe between tests.** `TestHooks.wipeLocalState` deletes rows
  from key tables but does not re-run migrations. If the schema churns
  mid-suite, the hook needs to drop and recreate the DB file instead.
- **Selector keys.** The Phase 1 tests reference `#serverUrlField`,
  `#emailField`, `#pinField`, etc. Those Keys do not exist in the UI
  yet — adding them to `AddServerScreen`, `LoginScreen`, and
  `SetupPinScreen` is part of Phase 1 follow-up before the tests can
  actually pass.

## Output

Each step appends a JSON line to `.release-check/last-run.json` plus a
dedicated `<step>.log` for failure diagnostics. `summary.sh` renders the
human banner + version-bump suggestion from those artifacts. The
directory is gitignored.
