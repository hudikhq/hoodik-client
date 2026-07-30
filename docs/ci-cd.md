# CI/CD Pipeline

## Summary

GitHub Actions workflows, Fastlane configuration, and required secrets for automated builds and store uploads.

## Workflows Overview

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| CI | `.github/workflows/ci.yml` | Push to `main`, PRs to `main` | Lint, test, verify builds |
| Release | `.github/workflows/release.yml` | Tag push (`v*`) | Build signed apps, upload to TestFlight + Play Store |

## CI Workflow (`ci.yml`)

Two jobs:

### 1. Analyze & Test (ubuntu-latest)

Pure Dart -- no Rust compilation needed:

```
flutter pub get -> dart analyze -> flutter test
```

Runs on every push/PR to main. Fast feedback on code quality.

### 2. Build Verify iOS (macos-latest)

Full build including Rust FFI compilation:

- Clones `hudikhq/hoodik` repo to `../hoodik` (for shared Rust crates)
- Installs Rust toolchain with `aarch64-apple-ios` target
- Uses `Swatinem/rust-cache@v2` for Rust dependency caching
- Builds: `flutter build ios --release --no-codesign`
- Verifies the full Rust FFI -> Flutter pipeline compiles

## Release Workflow (`release.yml`)

Triggered only on version tags (`v*`). Two jobs:

### 1. Build & Upload iOS (macos-latest)

- Clones hoodik repo for Rust crates
- Installs signing certificates (`apple-actions/import-codesign-certs@v2`)
- Installs provisioning profiles (app + share extension)
- Builds: `flutter build ipa --release --export-options-plist=ios/ExportOptions.plist`
- Uploads to TestFlight via Fastlane (`bundle exec fastlane ios beta`)

### 2. Build & Upload Android (ubuntu-latest)

- Clones hoodik repo for Rust crates
- Decodes signing keystore from secrets
- Creates `android/key.properties` from secrets
- Builds: `flutter build appbundle --release`
- Uploads the bundle to Google Play internal track (`r0adkll/upload-google-play@v1`)
- Downloads the Play-signed universal APK (`generatedApks` API, `scripts/release/fetch_play_universal_apk.py`) and attaches it to the GitHub release

## Rust FFI in CI

The Rust crate at `rust/` depends on `../../hoodik/transfer` and `../../hoodik/cryptfns` via local path patches. In CI, the hoodik server repo must be cloned at the correct relative path:

```
$GITHUB_WORKSPACE/../hoodik/    <-- cloned via git clone --depth 1
$GITHUB_WORKSPACE/              <-- hoodik-client (main checkout)
```

The main hoodik repo is public, so no auth token is needed for the clone.

**Note:** `actions/checkout@v4` restricts `path` to within `$GITHUB_WORKSPACE`, so we use `git clone --depth 1` instead for the hoodik repo.

## Fastlane (iOS)

Fastlane handles iOS TestFlight upload:

**`fastlane/Fastfile`** -- two lanes:

- `ios beta` -- upload to TestFlight (used by CI)
- `ios release` -- upload to App Store for review (manual)

**`fastlane/Appfile`:**

```ruby
app_identifier("com.hudikhq.hoodik")
apple_id(ENV["APPLE_ID"])
team_id(ENV["APPLE_TEAM_ID"])
```

**`Gemfile`:**

```ruby
source "https://rubygems.org"
gem "fastlane"
```

Android uses the `upload-google-play` action directly -- Fastlane is not needed for Android.

## Required GitHub Secrets

### iOS Signing & Upload

| Secret | Value | How to generate |
|--------|-------|-----------------|
| `IOS_CERTIFICATE_P12` | Base64-encoded p12 certificate | `base64 -i cert.p12` |
| `IOS_CERTIFICATE_PASSWORD` | Password set when exporting .p12 | -- |
| `IOS_PROVISIONING_PROFILE` | Base64-encoded app provisioning profile | `base64 -i profile.mobileprovision` |
| `IOS_SHARE_EXTENSION_PROVISIONING_PROFILE` | Base64-encoded share extension profile | `base64 -i share_extension.mobileprovision` |
| `ASC_KEY_ID` | App Store Connect API Key ID | App Store Connect -> Users and Access -> Keys |
| `ASC_ISSUER_ID` | App Store Connect API Issuer ID | Same page |
| `ASC_API_KEY` | Base64-encoded AuthKey p8 file | `base64 -i AuthKey_XXXX.p8` |

### macOS Signing & Upload

| Secret | Value | How to generate |
|--------|-------|-----------------|
| `MACOS_CERTIFICATE_P12` | Base64-encoded p12 certificate | `base64 -i cert.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | Password set when exporting .p12; also used as the temporary keychain password | -- |
| `MACOS_INSTALLER_CERTIFICATE_P12` | Base64-encoded Mac Installer Distribution p12 | `base64 -i installer.p12` |
| `MACOS_INSTALLER_CERTIFICATE_PASSWORD` | Password set when exporting .p12 | -- |
| `MACOS_PROVISIONING_PROFILE` | Base64-encoded macOS provisioning profile | `base64 -i profile.provisionprofile` |

### Android Signing & Upload

| Secret | Value | How to generate |
|--------|-------|-----------------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded upload keystore | `base64 -i hoodik-upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password | -- |
| `ANDROID_KEY_PASSWORD` | Key password | -- |
| `GOOGLE_PLAY_SERVICE_ACCOUNT` | Service account JSON | Play Console -> Settings -> API access |

Keep the source of truth for these in a password manager, and set them as
repository secrets in GitHub. None of them belong in the repository.

## Release Process

```shell
# 1. Update version in pubspec.yaml
# 2. Commit changes
git add -A && git commit -m "Release v1.0.1"

# 3. Tag the release
git tag v1.0.1

# 4. Push with tags (triggers release workflow)
git push origin main --tags

# 5. Monitor the release workflow
gh run list --workflow=release.yml

# 6. After CI succeeds:
#    - iOS: promote TestFlight build to App Store review in App Store Connect
#    - Android: promote internal track build to production in Google Play Console
```

## Flutter & Dart Version

CI uses `subosito/flutter-action@v2` with `flutter-version: "3.41.x"` (stable channel). This provides Dart 3.11.4+ which satisfies the `sdk: ^3.11.4` constraint in pubspec.yaml.

## Related Docs

- [Release Guide](release-guide.md) -- signing setup, store submission details
- [Development](development.md) -- local build setup
- [Store Status](store-status.md) -- current release status
