# Development Setup & Building

How to set up the development environment, build for all platforms, and run linting/analysis. Start here when setting up the project for the first time.

---

## Prerequisites

- **Flutter SDK** >= 3.41 (stable channel) -- provides Dart 3.11+
- **Rust** >= 1.91 (via rustup)
- **flutter_rust_bridge_codegen** v2.11.1 (`cargo install flutter_rust_bridge_codegen`)
- **Main hoodik repo** checked out at `../hoodik/` relative to `hoodik-client/` (for shared Rust crates)
- **Platform-specific:**
  - iOS/macOS: Xcode >= 15, CocoaPods
  - Android: Android Studio, JDK 17, Android NDK (set `ANDROID_NDK_HOME`)
  - Linux: Standard build tools (`clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`)
  - Windows: Visual Studio with C++ desktop workload

---

## Quick Start

```shell
# 1. Clone both repos side-by-side
git clone git@github.com:hudikhq/hoodik.git
git clone git@github.com:hudikhq/hoodik-client.git

# 2. Install dependencies
cd hoodik-client
flutter pub get

# 3. Run the app
flutter run
# First Rust compilation takes 5-10 minutes (transitive dependencies)
# Subsequent builds are incremental
```

---

## Rust FFI Build System

The app's Rust crate (`hoodik_mobile`) is compiled natively for each platform via `cargokit` (a build system plugin bundled at `rust_builder/`).

### Path Dependencies

`rust/.cargo/config.toml` patches dependencies to local paths:

```toml
[patch."https://github.com/hudikhq/hoodik"]
transfer = { path = "../../hoodik/transfer" }
cryptfns = { path = "../../hoodik/cryptfns" }
```

This means the main hoodik repo must be at `../../hoodik/` relative to `rust/`, which is `../hoodik/` relative to the project root.

### Regenerating FFI Bindings

After modifying `rust/src/api.rs`:

```shell
flutter_rust_bridge_codegen generate
```

Configuration is in `flutter_rust_bridge.yaml`:

```yaml
rust_input: crate::api
rust_root: rust/
dart_output: lib/src/rust
full_dep: true
```

**Known issue:** Codegen sometimes sets `stem: 'UNKNOWN'` in `lib/src/rust/frb_generated.dart`. Fix it manually to `'hoodik_mobile'`.

---

## Building

### iOS

```shell
# Development (simulator)
rustup target add aarch64-apple-ios-sim  # One-time
flutter run -d "iPhone"

# Release (no codesign, for CI verification)
flutter build ios --release --no-codesign

# Release (signed, for App Store)
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
# Output: build/ios/ipa/hoodik_app.ipa

# Onto a physical device, for hands-on testing
just device-install <devicectl-device-id>   # id from `xcrun devicectl list devices`
```

Deployment target: iOS 13.0+

Use the recipe rather than `flutter build ios --release` for a device build.
It resets CocoaPods first and switches signing to development, which are the
two things a bare build gets wrong:

- **`Module 'patrol' not found`.** `patrol` is a dev dependency that registers
  itself in the generated plugin registrant, but its pod reaches the Runner
  target only when CocoaPods resolves from scratch. Every device build after a
  `flutter clean` or a project-file edit hits this, so the recipe clears
  `ios/Pods` and `ios/Podfile.lock` up front instead of failing first.
- **`ApplicationVerificationFailed` on install.** Every Release block pins the
  manual "Hoodik App Store" distribution profile, which the device refuses.
  The recipe rewrites those blocks to automatic development signing for the
  build and restores the project file afterwards — including when the build
  fails, so the edit is never left behind and never committed.

A device that is locked refuses the install with
`kAMDMobileImageMounterDeviceLocked`; unlock it and run the recipe again.

### Android

```shell
# Development
flutter run -d "emulator"

# Release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Release App Bundle (for Play Store)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

Android signing requires `android/key.properties` (gitignored):

```properties
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=/path/to/hoodik-upload.jks
```

If `key.properties` is missing, release builds fall back to debug signing for local development.

### macOS

```shell
# Development
flutter run -d macos

# Release
flutter build macos --release
# Output: build/macos/Build/Products/Release/hoodik_app.app
```

Deployment target: macOS 10.15+

**Note:** Debug and release builds use different entitlement files. Debug (`DebugProfile.entitlements`) includes JIT permissions for development. Release (`Release.entitlements`) omits JIT but includes the entitlements needed for production. If you add new capabilities (e.g., biometric authentication, keychain access), make sure to update the appropriate entitlements file.

### Linux

```shell
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

### Windows

```shell
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

Linux and Windows builds are scaffolded but not fully tested.

---

## Linting & Analysis

```shell
# Dart static analysis (must pass clean -- zero warnings)
dart analyze

# Code formatting
dart format .
```

Lint rules are in `analysis_options.yaml`:

- **Base:** `package:flutter_lints/flutter.yaml`
- **Code quality rules:** `prefer_single_quotes`, `avoid_print`, `unawaited_futures`, `sized_box_for_whitespace`, `use_null_aware_elements`
- **Safety rules:** `cancel_subscriptions`, `close_sinks`, `no_adjacent_strings_in_list`, `test_types_in_equals`, `throw_in_finally`, `unnecessary_statements`
- **Excluded from analysis:** `lib/src/rust/**` (auto-generated FFI), `rust_builder/cargokit/**` (third-party build tooling)
- **Downgraded to warnings:** `prefer_single_quotes`, `unawaited_futures` (to avoid breaking CI on style issues)

---

## Platform Identities

All platforms use the same bundle identifier:

| Platform | Bundle/Application ID |
|----------|----------------------|
| iOS | `com.hudikhq.hoodik` |
| Android | `com.hudikhq.hoodik` |
| macOS | `com.hudikhq.hoodik` |
| Linux | `com.hudikhq.hoodik` |

Additional iOS identifiers:

- Share Extension: `com.hudikhq.hoodik.ShareExtension`
- App Group: `group.com.hudikhq.hoodik`
- Team ID: `J3G7362G8Y`

---

## Known Issues & Gotchas

1. **First Rust build is slow** -- 5-10 minutes for transitive dependencies. Subsequent builds are incremental.
2. **FRB codegen stem** -- `flutter_rust_bridge_codegen generate` sometimes sets `stem: 'UNKNOWN'` in `frb_generated.dart`. Fix manually to `'hoodik_mobile'`.
3. **iOS simulator target** -- Requires `aarch64-apple-ios-sim` Rust target (`rustup target add aarch64-apple-ios-sim`).
4. **macOS entitlements** -- Debug and release builds use different entitlements files. Check both when adding new capabilities.
5. **Android NDK** -- Must be installed and `ANDROID_NDK_HOME` set for Android builds with Rust FFI.
6. **local_auth in tests** -- `local_auth` requires platform channel mocking in tests. Two pre-existing tests in `test/widget_test.dart` fail due to this.
7. **Android signing fallback** -- If `android/key.properties` is missing, release builds silently fall back to debug signing. This is fine for local development but will not work for store submissions.

---

## Related Docs

- [Security](security.md) -- encryption model, key handling, threat model
- [Architecture](architecture.md) -- full architecture and key files reference
- [Testing](testing.md) -- test structure, coverage, and conventions
- [Release Guide](release-guide.md) -- signing, certificates, store submission
- [CI/CD](ci-cd.md) -- GitHub Actions pipeline
