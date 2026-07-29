# Testing Guide

## Summary

Tests mirror the source tree: anything under `lib/core/` has its counterpart
under `test/core/`, and each feature under `lib/features/<name>/` has one under
`test/features/<name>/`. Tests that need the Rust FFI, a real device, or a live
server live in `integration_test/` instead, because the Dart VM test runner
cannot load the native library.

---

## Running Tests

```shell
# Everything that runs on the host VM
flutter test

# A single file
flutter test test/core/utils/hex_test.dart

# Verbose reporter
flutter test --reporter expanded

# Integration tests (requires a device/emulator and the Rust FFI built)
flutter test integration_test/
```

Through the task runner, `just unit` runs the host-VM suite the release gate
uses.

---

## Layout

| Path | Covers |
|------|--------|
| `test/core/api/` | Wire models, request shaping, per-domain HTTP clients |
| `test/core/auth/` | Login, signature auth, session restore, key transition |
| `test/core/crypto/` | Key handling, file/name encryption, search tokenization |
| `test/core/mcp/` | MCP protocol framing, tool dispatch, lock gating, audit log |
| `test/core/services/` | Transfers, offline cache, sync, thumbnails, log export |
| `test/core/storage/` | Drift schema, migrations, CRUD |
| `test/core/utils/` | Hex, redaction, formatting helpers |
| `test/core/workers/` | Typed isolate messages |
| `test/features/*/` | Screens, widgets, controllers and providers, per feature |
| `test/goldens/` | Pixel goldens across the viewport matrix |
| `test/l10n/` | Translation catalogue completeness across en/fr/de/hr |
| `test/tools/` | The release-check shell scripts themselves |
| `integration_test/e2e/` | Full flows against an ephemeral server |
| `integration_test/e2e/compat/` | Backwards-compat gate against older server builds |

---

## Conventions

**Everything new gets a test.** Fixing a bug starts with a test that reproduces
it; adding a feature writes tests alongside the implementation, not after.

**Mirror the source path.** `lib/core/utils/hex.dart` is tested by
`test/core/utils/hex_test.dart`.

**Never fake the component under test.** A suite that injects a fake of the
thing it is meant to exercise proves only that the fake works. Fakes belong at
the boundaries — the network, the clock, the platform channel — never in the
middle.

**Crypto gets roundtrips.** Encrypt/decrypt over empty input, large input, and
multi-byte characters, across every supported cipher (AEGIS-128L, AEGIS-256,
Ascon-128a, ChaCha20-Poly1305). Anything needing the real Rust implementation
belongs in `integration_test/`.

**Platform channels need mocking.** Packages like `local_auth` have no host-VM
implementation. Call `TestWidgetsFlutterBinding.ensureInitialized()` and install
a mock method channel.

---

## Goldens

Golden PNGs are renderer-sensitive, so where they were generated matters.

**The committed baselines are host-generated**, on macOS. Regenerate with:

```shell
just goldens-update-local
```

Then check the resulting diff: only the screens you actually changed should
move. If every PNG changes, your renderer differs from the one that produced
the baselines, and committing that would break them for everyone else.

`just goldens-update` runs the same thing inside the pinned
`ghcr.io/cirruslabs/flutter` container, which is the more reproducible option.
It is not what the current baselines were made with, though, so switching to it
rewrites all 40 PNGs at once — a deliberate migration, not a routine update.

Two things to know before relying on this suite:

- **CI does not run it.** `scripts/release-check/unit.sh` scopes to `test/core/`
  and `test/features/`, so goldens only run when you invoke `flutter test` with
  no path filter. A golden regression will not fail a pull request.
- Because of that, a golden break is a local signal, not a gate.

---

## Static Analysis

```shell
dart analyze
dart format .
```

Analysis config is `analysis_options.yaml`:

- Base: `package:flutter_lints/flutter.yaml`
- Excluded: `lib/src/rust/**` (auto-generated), `rust_builder/cargokit/**` (third-party)

---

## Related Docs

- [Development](development.md) -- building and running the app
- [Architecture](architecture.md) -- codebase structure and key files
- [CI/CD](ci-cd.md) -- automated test pipeline
- [Compat Testing](compat-testing.md) -- the backwards-compat gate
