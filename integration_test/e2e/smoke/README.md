# Smoke subset

macOS runs the §12-approved smoke subset, not the full 14-flow matrix.

**Selection is by Dart test tag**, not by directory layout. Patrol picks
up the `tags: ['smoke']` parameter on `patrolTest(...)` and
`e2e-macos-smoke.sh` invokes `patrol test --tags smoke`. Keeping one copy
of each flow avoids drift between a "full" and a "smoke" variant.

Tests currently tagged `smoke`:

- `../onboarding_test.dart` — first-time install, login, PIN (flow #1)
- `../upload_download_test.dart` — 2 MB PNG round-trip (flow #3)
- `../logout_test.dart` — private-key clearing (flow #14)

When adding a new flow, decide whether it belongs in the macOS smoke
loop. If yes, add `tags: ['smoke']` to its `patrolTest(...)` call and
list it here.
