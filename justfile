set shell := ["bash", "-cu"]
set dotenv-load := true

default:
    @just --list

release-check:
    @scripts/release-check/preflight.sh
    @scripts/release-check/format.sh
    @scripts/release-check/analyze.sh
    @scripts/release-check/invariants.sh
    @scripts/release-check/unit.sh
    @scripts/release-check/integration.sh
    @just e2e-ios
    @just e2e-android
    @just e2e-macos-smoke
    @scripts/release-check/build.sh
    @scripts/release-check/summary.sh

release-check-fast:
    @scripts/release-check/preflight.sh
    @scripts/release-check/format.sh
    @scripts/release-check/analyze.sh
    @scripts/release-check/invariants.sh
    @scripts/release-check/unit.sh
    @scripts/release-check/integration.sh
    @scripts/release-check/summary.sh

preflight:
    @scripts/release-check/preflight.sh

format:
    @scripts/release-check/format.sh

analyze:
    @scripts/release-check/analyze.sh

invariants:
    @scripts/release-check/invariants.sh

unit:
    @scripts/release-check/unit.sh

integration:
    @scripts/release-check/integration.sh

# Export the schema snapshot for the current version and rebuild the migration
# helper. Run after adding a migration and bumping currentSchemaVersion — the
# snapshot is what lets a later release test the upgrade from this one.
schema-snapshot:
    dart run drift_dev schema dump lib/core/storage/database.dart drift_schemas/
    dart run drift_dev schema generate drift_schemas/ test/generated/migrations/

# Run the Patrol iOS smoke flows against an ephemeral hoodik server.
# Lifecycle: docker-hoodik-up → Playwright bootstrap (registers e2e@hoodik.local
# via the real /auth/register form) → patrol test → docker-hoodik-down.
# Idempotent re-runs reuse the docker container and skip re-registration.
# Local-only — there is no CI counterpart by design.
e2e-ios device="iPhone 16":
    #!/usr/bin/env bash
    set -uo pipefail
    export PATH="${HOME}/.pub-cache/bin:${PATH}"
    command -v patrol >/dev/null 2>&1 || { echo "patrol_cli missing — dart pub global activate patrol_cli 3.11.0" >&2; exit 127; }
    trap 'scripts/release-check/docker-hoodik-down.sh' EXIT
    scripts/release-check/docker-hoodik-up.sh
    scripts/release-check/bootstrap.sh
    xcrun simctl boot "{{device}}" 2>/dev/null || true
    patrol test --target integration_test/e2e/ --tags smoke --device "{{device}}"

# Run the Patrol Android smoke flows against an ephemeral hoodik server.
# Same lifecycle as e2e-ios. The Android emulator reaches the host via
# 10.0.2.2 (not 127.0.0.1), so HOODIK_E2E_URL is overridden via dart-define.
# Requires a booted emulator (emulator-5554 by default — boot one first with
# `emulator -avd <AVD_NAME> -no-snapshot-save -no-audio &`).
e2e-android device="emulator-5554":
    #!/usr/bin/env bash
    set -uo pipefail
    export PATH="${HOME}/.pub-cache/bin:${PATH}"
    command -v patrol >/dev/null 2>&1 || { echo "patrol_cli missing — dart pub global activate patrol_cli 3.11.0" >&2; exit 127; }
    command -v adb >/dev/null 2>&1 || { echo "adb missing — \$ANDROID_HOME/platform-tools/adb" >&2; exit 127; }
    if ! adb -s "{{device}}" get-state >/dev/null 2>&1; then
        echo "emulator '{{device}}' not running — boot one first:" >&2
        echo "  emulator -avd <AVD_NAME> -no-snapshot-save -no-audio &" >&2
        exit 69
    fi
    trap 'scripts/release-check/docker-hoodik-down.sh' EXIT
    scripts/release-check/docker-hoodik-up.sh
    scripts/release-check/bootstrap.sh
    # Android emulator can't reach 127.0.0.1 on host — it sees the host as
    # 10.0.2.2. Server runs USE_HEADERS_FOR_AUTH=true so cookie domains are
    # irrelevant; only the HTTP base URL needs overriding.
    patrol test --target integration_test/e2e/ --tags smoke --device "{{device}}" --dart-define=HOODIK_E2E_URL=http://10.0.2.2:5443

# macOS smoke is currently parked: the macos/Runner.xcodeproj has no
# RunnerUITests target + scheme entry that Patrol needs to drive the desktop
# app via XCUITest (iOS has it; macOS does not). Re-enable by adding the
# target via Xcode GUI (Add Target → Test Bundle → wire to scheme → pod install).
e2e-macos-smoke:
    @echo "[release-check] e2e-macos-smoke      SKIP (macOS RunnerUITests target missing — Xcode GUI work)"

# Run all three E2E suites in sequence. Single docker container + single
# bootstrap is reused across runs (each recipe trap teardown runs at the end,
# but docker-hoodik-up is idempotent and bootstrap.sh detects the existing user
# and short-circuits).
e2e-all:
    @just e2e-ios
    @just e2e-android
    @just e2e-macos-smoke

build:
    @scripts/release-check/build.sh

summary:
    @scripts/release-check/summary.sh

docker-hoodik-up:
    @scripts/release-check/docker-hoodik-up.sh

docker-hoodik-down:
    @scripts/release-check/docker-hoodik-down.sh

release-snapshot:
    @scripts/release-check/release-snapshot.sh

dashboard:
    @python3 scripts/release-check/dashboard.py

# Regenerate goldens against the host's rendering stack. Subpixel drift
# from CI Linux is expected — use `goldens-update` (docker) when
# committing new baselines.
goldens-update-local:
    flutter test --update-goldens test/goldens/

# Regenerate goldens inside a Flutter Linux container so the committed
# PNGs match the CI renderer bit-for-bit.
# Regenerate inside the pinned container. The committed baselines were produced
# on a host (see docs/testing.md), so a container run rewrites all 40 PNGs, not
# just the ones your change touched — treat switching over as a deliberate
# migration rather than a routine update.
goldens-update:
    docker run --rm -v $(pwd):/app -w /app ghcr.io/cirruslabs/flutter:3.41.6 \
        flutter test --update-goldens test/goldens/

# Run the Patrol compat suite against a single released hoodik server tag
# on the Android emulator (e.g. `just e2e-compat v1.9.0`). Boots
# docker-compose.compat.yml, waits for the server, registers a deterministic
# test user, drives the three integration_test/e2e/compat/* flows, tears the
# container down. Local-only — never wired into CI because real Docker +
# emulator + network orchestration is too fragile for a merge gate.
#
# Why Android, not iOS: Patrol's iOS path requires Xcode-GUI-only wiring on
# the UITests target that's impractical to reproduce from the command line.
# Android runs through a single Gradle JUnit runner and is rock solid. The
# iOS scaffolding is still in the tree for anyone who wants to finish it.
e2e-compat version:
    #!/usr/bin/env bash
    set -euo pipefail
    version="{{version}}"
    if [[ -z "$version" ]]; then
        echo "usage: just e2e-compat <version>  (e.g. v1.9.0)" >&2
        exit 64
    fi
    # `dart pub global activate` drops executables into ~/.pub-cache/bin
    # which is not on most users' $PATH. Front-load it so `patrol`
    # resolves without the dev having to edit their shell rc.
    export PATH="${HOME}/.pub-cache/bin:${PATH}"
    if ! command -v patrol >/dev/null 2>&1; then
        echo "patrol_cli missing — install it once with:" >&2
        echo "  dart pub global activate patrol_cli 3.11.0" >&2
        echo "(the compat table pairs patrol_cli 3.11.0 with patrol 3.20.0 — see docs/compat-testing.md)" >&2
        exit 127
    fi
    export HOODIK_SERVER_VERSION="$version"
    trap './scripts/compat/teardown.sh' EXIT
    docker compose -f docker-compose.compat.yml up -d
    ./scripts/compat/bootstrap.sh
    # 10.0.2.2 is the Android emulator's alias for the host's 127.0.0.1, so
    # the instrumented app reaches the compat container the same way the
    # host bootstrap did — no port-forward, no reverse-tether. Cleartext HTTP
    # is allowed via android/app/src/debug/AndroidManifest.xml; release builds
    # never ship that flag.
    device="${HOODIK_ANDROID_DEVICE:-emulator-5554}"
    if ! adb -s "$device" get-state >/dev/null 2>&1; then
        echo "emulator '$device' not running — boot one first:" >&2
        echo "  emulator -avd <AVD_NAME> -no-snapshot-save -no-audio &" >&2
        exit 69
    fi
    patrol test \
        --target integration_test/e2e/compat/ \
        --device "$device" \
        --dart-define=SERVER_VERSION="$version" \
        --dart-define=COMPAT_BASE_URL=http://10.0.2.2:5443

# Run the compat suite sequentially against every released tag we care
# about (v1.7.0, v1.8.1, v1.9.0). Prints a per-version pass/fail summary
# at the end. Fail-fast: stops at the first broken tag so you see the
# shortest reproduction path. To add a new tag, update the list here AND
# the table in integration_test/e2e/compat/compat_helpers.dart.
e2e-compat-matrix:
    #!/usr/bin/env bash
    set -uo pipefail
    versions=(v1.7.0 v1.8.1 v1.9.0)
    declare -a results
    overall=0
    for v in "${versions[@]}"; do
        echo
        echo "================================================================"
        echo " compat matrix: $v"
        echo "================================================================"
        if just e2e-compat "$v"; then
            results+=("$v: PASS")
        else
            results+=("$v: FAIL")
            overall=1
            break
        fi
    done
    echo
    echo "================================================================"
    echo " compat matrix summary"
    echo "================================================================"
    printf ' %s\n' "${results[@]}"
    exit "$overall"

# Nuke any leftover compat container, volume, or interrupted venv setup.
# Safe to run anytime — does not touch the release-check E2E container.
e2e-compat-clean:
    @./scripts/compat/teardown.sh

# Prove the direct-transfer path against a real bucket protocol: the paired
# hoodik server built from ../hoodik with presigned URLs on, and the live
# round-trip test (register → direct upload → finalize → direct download →
# byte-for-byte compare). Defaults to a MinIO the hoodik compose file
# provides; export S3_* first (e.g. `set -a; source ../secrets/r2-testing.env;
# set +a; S3_PREFIX=ci-live/ just e2e-direct`) to run the same thing against
# a real bucket. Requires docker for the MinIO default and the ../hoodik
# checkout either way. Refuses to start while something else holds :5443.
e2e-direct:
    #!/usr/bin/env bash
    set -euo pipefail
    HOODIK=../hoodik

    if lsof -ti tcp:5443 >/dev/null 2>&1; then
        echo "something is already listening on :5443 — stop it first" >&2
        exit 69
    fi

    if [ -z "${S3_ENDPOINT:-}" ]; then
        docker compose -f "$HOODIK/docker-compose.yml" up -d minio minio-init
        export S3_ENDPOINT=http://127.0.0.1:9000
        export S3_BUCKET="${S3_BUCKET:-hoodik}"
        export S3_ACCESS_KEY="${S3_ACCESS_KEY:-minioadmin}"
        export S3_SECRET_KEY="${S3_SECRET_KEY:-minioadmin}"
        export S3_REGION="${S3_REGION:-us-east-1}"
    fi
    export S3_PATH_STYLE="${S3_PATH_STYLE:-true}"
    export S3_PREFIX="${S3_PREFIX:-app-e2e/}"

    (cd "$HOODIK" && cargo build --bin hoodik --release)

    DATA=$(mktemp -d)
    STORAGE_PROVIDER=s3 S3_DIRECT_TRANSFER=true S3_DIRECT_ALLOW_INSECURE=true \
    DATA_DIR="$DATA" DATABASE_URL="sqlite:$DATA/sqlite.db?mode=rwc" \
    SSL_DISABLED=true APP_URL=http://localhost:5443 APP_CLIENT_URL=http://localhost:5443 \
    MAILER_TYPE=none RUST_LOG=error \
    "$HOODIK/target/release/hoodik" &
    SERVER_PID=$!
    cleanup() { kill -9 $SERVER_PID 2>/dev/null; rm -rf "$DATA"; }
    trap cleanup EXIT

    for i in $(seq 1 60); do
        curl -fsS http://127.0.0.1:5443/api/liveness >/dev/null 2>&1 && break
        sleep 1
    done
    if ! curl -fsS http://127.0.0.1:5443/api/readiness | grep -q '"direct_transfer":true'; then
        echo "server does not advertise direct transfer:" >&2
        curl -s http://127.0.0.1:5443/api/readiness >&2 || true
        exit 1
    fi

    (cd rust && cargo build --release)
    flutter test --dart-define=HOODIK_LIVE=1 --tags live test/live/direct_transfer_live_test.dart
