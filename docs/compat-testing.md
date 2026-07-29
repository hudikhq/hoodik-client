# Backwards-Compat E2E Gate

> **Status:** Pre-release gate. Runs locally, not in CI.
> **Last updated:** 2026-04-20.

---

## 1. Why this exists

Hoodik is open-source. Real self-hosters and paying users often stay pinned
to a server version for months after the mobile app ships a new release —
servers are the thing you upgrade last, not first. The upcoming app release
depends on new server features that no released tag has (`POST /api/storage/:id?format=tar`
tar uploads, `file_versions`, `files.editable`), and the app's graceful-
degradation paths (`TarCapabilityCache`, markdown editor hiding itself when
`file.editable` is absent) have so far only been tested against master.

If any fallback is broken, the first report comes from a paying customer.
This gate catches it before tagging.

---

## 2. Running the gate

Prerequisites: Docker Desktop, Python 3, Android SDK + a booted Android
emulator, and `patrol_cli 3.11.0` (pinned to match `patrol 3.20.0` per the
compat table in `~/.pub-cache/hosted/pub.dev/patrol_cli-3.11.0/lib/src/compatibility_checker/version_compatibility.dart`):

```shell
dart pub global activate patrol_cli 3.11.0
```

The justfile recipe prepends `~/.pub-cache/bin` to `$PATH` automatically,
so you don't have to edit your shell rc. Xcode is optional — iOS support
is parked; Android is the primary path (simpler Gradle + JUnit setup, no
XCTest wiring fragility).

```shell
# Single version — boots container, bootstraps, runs the compat suite, tears down.
just e2e-compat v1.9.0

# Matrix — runs v1.7.0, v1.8.1, v1.9.0 sequentially, fail-fast, prints summary.
just e2e-compat-matrix

# Nuke any leftover compat container/volume if a run was interrupted.
just e2e-compat-clean
```

First invocation is slower: `scripts/compat/bootstrap.sh` creates a Python
venv at `scripts/compat/.venv/` and `pip install`s `cryptography`, `ascon`,
and `requests`. Subsequent runs reuse the venv.

A successful run prints:

```
[compat-bootstrap] server healthy (HTTP 401 from /api/auth/self)
[compat-bootstrap] registering compat test user (compat@hoodik.local)
[compat-bootstrap] compat server ready at http://127.0.0.1:5443
[Patrol]  ... 3 tests passed ...
[compat-teardown] docker compose down -v
```

---

## 3. Version → capability table

The Flutter client branches on features per tag. This table is the single
source of truth — mirrored in `integration_test/e2e/compat/compat_helpers.dart`.

| Tag       | tar upload | tar download | versioning | editable files | sharing |
|-----------|:---------:|:------------:|:----------:|:--------------:|:-------:|
| v1.7.0    | ❌ | ❌ | ❌ | ❌ | ❌ |
| v1.8.0    | ❌ | ❌ | ❌ | ❌ | ❌ |
| v1.8.1    | ❌ | ❌ | ❌ | ❌ | ❌ |
| v1.9.0    | ❌ | ❌ | ❌ | ❌ | ❌ |
| v1.10.0   | ❌ | ❌ | ❌ | ❌ | ❌ |
| v1.11.0   | ❌ | ❌ | ❌ | ❌ | ❌ |
| v1.12.0   | ❌ | ✅ | ❌ | ❌ | ❌ |
| v1.13.0   | ❌ | ✅ | ❌ | ❌ | ❌ |
| v1.13.1   | ❌ | ✅ | ❌ | ❌ | ❌ |
| v1.13.2   | ❌ | ✅ | ❌ | ❌ | ❌ |
| v1.14.0   | ❌ | ✅ | ❌ | ✅ | ❌ |
| v1.14.1   | ❌ | ✅ | ❌ | ✅ | ❌ |

*Tar download* landed in v1.12.0 (`GET /api/storage/:id?format=tar`, PR #149).
*Editable files* (A1) landed in v1.14.0 (`set_editable`, `replace_content`,
PR #153). *Tar upload* and *file versioning* (A2) are on master; no tag yet.
*Account-to-account sharing* (`/api/capabilities` advertising `sharing.enabled`,
`move-into-shared` / `move-out-of-shared`) is on master; no tag yet — so the
move funnel's degradation path is exercised against every entry above.
*Share groups* (`share_groups`, the `groups` roster routes, and the client-side
share-to-group fan-out) are part of the same unreleased sharing track — also on
master, no tag — so `share_groups` reads false on every entry and the group UI
stays hidden across the whole matrix. A group is a saved recipient selection
with no server-side group→file tracking, so sharing to a group is N independent
single shares; there is no group-only endpoint an old server could be asked to
serve once the Groups tab is gated off.
*Lazy thumbnails* (the listing `attributes` projection + `GET
/api/storage/:id/thumbnail`) are on master; no tag yet. No capability column is
needed: old servers ignore the `attributes` parameter and keep shipping
`encrypted_thumbnail` inline, which the `ThumbnailLoader` consumes directly —
the lazy fetch only fires when a listing row advertises `has_thumbnail` without
the blob, which only servers that also have the thumbnail route emit. The
route-absent 404 path is additionally pinned by
`test/core/services/thumbnail_loader_test.dart`.

The matrix (`just e2e-compat-matrix`) tests `v1.7.0`, `v1.8.1`, `v1.9.0` —
the oldest widely-deployed tags. Adding newer tags to the matrix has
diminishing returns; add them only when a specific degradation path
changes shape across versions.

---

## 4. What the suite covers

Five Patrol tests in `integration_test/e2e/compat/`:

| File                                   | Runs on                     | Asserts |
|----------------------------------------|-----------------------------|---------|
| `basic_roundtrip_compat_test.dart`     | every version               | upload 2 MB PNG → list → download → SHA-256 round-trip → delete |
| `tar_fallback_compat_test.dart`        | servers where `hasTarUpload == false` | first upload imprints `TarCapabilityCache[baseUrl] = false` and still succeeds |
| `versioning_absent_compat_test.dart`   | servers where `hasEditableFiles == false` | opening a `.md` hides `FormattingToolbar` and surfaces no error banner |
| `sharing_absent_compat_test.dart`      | servers where `hasSharing == false` | live `/api/capabilities` reports sharing off, and the real `MoveRouter` fed that gate classifies an owned folder into a shared-looking dest as `PlainMove` — the absent move endpoints are never hit |
| `group_roles_absent_compat_test.dart`  | every version (no tag ships share groups) | live `/api/capabilities` reports `share_groups` off, so the Groups tab and the share-dialog group target stay hidden — an old server is never asked for a group route |

The happy-path test runs on every version — if it breaks, the release is
shippable to nobody. The degradation tests use `markTestSkipped` when
the targeted server doesn't exhibit the degraded path, so the same test
binary can run unchanged across the matrix.

---

## 5. Adding a new released server tag

When a new `hudik/hoodik:vX.Y.Z` image ships and you want the compat gate
to cover it:

1. **Verify the image exists on Docker Hub:**
   ```shell
   docker pull hudik/hoodik:vX.Y.Z
   ```

2. **Identify the capability deltas.** In the `hoodik/` sibling repo:
   ```shell
   git ls-tree -r vX.Y.Z --name-only | grep -E "storage/src/routes/(upload_tar|versions|set_editable|replace_content)\.rs"
   ```
   The presence of each route file is a boolean — add or remove the
   corresponding flag for this tag.

3. **Add the entry to `_capabilityTable`** in
   `integration_test/e2e/compat/compat_helpers.dart`. Keep the list sorted
   by version to make diffs readable.

4. **Update the table above** (section 3). The Dart source and this doc
   must agree — they're the two places a reviewer looks.

5. **Add the tag to `just e2e-compat-matrix`** (inside `justfile`) only
   if this tag covers a *distinct* degradation path. Adding every release
   bloats the matrix runtime without catching new bugs.

The whole loop should be about 10 minutes end-to-end. If it takes longer,
something in this doc is out of date — fix the doc as part of the change.

---

## 6. Adding a new compat test

1. Drop a new `*_compat_test.dart` into `integration_test/e2e/compat/`,
   following the pattern of the existing three (load `ServerCapabilities`,
   short-circuit with `markTestSkipped` when the targeted server doesn't
   exhibit the path you're testing, use `CompatEnv` for credentials).

2. Import from `compat_helpers.dart`, not directly from the server-version
   constants. Tests branch on booleans, never on tag strings.

3. Every compat test must be idempotent — the matrix runs them back-to-back
   against different servers on the same device, and teardown wipes the
   volume between runs but not the simulator's state. If your test writes
   to `TestHooks.pendingUploads()` or any other cross-session artifact,
   clean up in `patrolTearDown`.

4. If your test needs a new assertion helper (reading another provider,
   inspecting a new cache), extend `compat_helpers.dart` rather than
   duplicating the Riverpod boilerplate in the test file.

---

## 7. Updating the capability table when the server ships a feature

When the `hoodik/` repo tags a release that adds a new server capability
the app cares about:

1. Add a new boolean to `ServerCapabilities` in `compat_helpers.dart`.
   Default it to `false` for every existing entry — old tags never ship
   with new features.

2. Flip it to `true` on every tag that ships the feature. If you're
   unsure which tag first shipped a route, `git log --diff-filter=A
   -- storage/src/routes/<route>.rs` in the `hoodik/` repo gives the
   introducing commit — `git tag --contains <sha>` narrows to tags.

3. Write a new compat test that exercises both the presence and the
   absence of the feature (or two tests, if they're distinct). Gate
   each on the new boolean.

4. Update section 3 of this doc.

---

## 8. Limits

- **iOS simulator only.** Android emu + Linux/Windows aren't covered yet.
  Parity is a roadmap item — not blocked on this gate, blocked on Patrol
  stability and simulator orchestration on non-Mac hosts.
- **Released tags only.** We don't test against master or RC images —
  those move too fast to gate on, and the whole point is covering what
  real users actually run.
- **No data-migration tests.** Upgrade/downgrade compatibility of the
  stored file format is a different problem; this gate only covers the
  wire protocol and UI degradation.
- **Not in CI.** Local-only. The cost of orchestrating Docker + iOS
  simulator + cross-repo tag pulls in GitHub Actions is higher than the
  value this gate provides if it fails less than once per release cycle.
  If we start shipping broken compat against tagged servers anyway, we'll
  revisit.
