# Release & Store Submission Guide

Complete guide for signing, building, and publishing the Hoodik Flutter app to the iOS App Store, Google Play, and Mac App Store.

---

## Table of Contents

1. [Accounts & Enrollment](#accounts--enrollment)
2. [App Identity](#app-identity)
3. [Store Listing Content](#store-listing-content)
4. [App Icons & Screenshots](#app-icons--screenshots)
5. [iOS Release](#ios-release)
6. [Android Release](#android-release)
7. [macOS Release](#macos-release)
8. [Pre-Launch Checklist](#pre-launch-checklist)
9. [Quick Reference Links](#quick-reference-links)
10. [Related Docs](#related-docs)

---

## Accounts & Enrollment

### Apple Developer Program ($99/year)

Required for App Store (iOS + macOS), TestFlight, code signing, and notarization.

1. Enroll at https://developer.apple.com/programs/enroll/
2. Sign in with your Apple ID (or create one)
3. Enroll as **Individual** or **Organization** (if you have a D-U-N-S number)
4. Pay $99/year
5. Wait for approval (usually 24-48 hours, sometimes instant)

**After approval you get:**
- Access to App Store Connect (https://appstoreconnect.apple.com)
- Ability to create signing certificates and provisioning profiles
- Team ID (needed for Xcode project configuration)

**Small Business Program (15% commission):** If you earn under $1M/year, Apple reduces their cut from 30% to 15%. Apply at https://developer.apple.com/app-store/small-business-program/

**Enrollment guide:** https://developer.apple.com/support/enrollment/

### Google Play Developer Account ($25 one-time)

Required for publishing on Google Play Store.

1. Sign up at https://play.google.com/console/signup
2. Sign in with your Google account
3. Pay $25 one-time registration fee
4. Fill in developer profile (name, address, contact)
5. Complete identity verification (may require photo ID, can take several days)

**After approval you get:**
- Access to Google Play Console
- Ability to create app listings and upload AABs for review

**Small Business Program (15% commission):** Apply at https://play.google.com/console/about/programs/702

**Enrollment guide:** https://support.google.com/googleplay/android-developer/answer/6112435

---

## App Identity

All platforms use `com.hudikhq.hoodik` as the bundle/application ID.

| Field | Value |
|-------|-------|
| Bundle ID (all platforms) | `com.hudikhq.hoodik` |
| iOS Share Extension | `com.hudikhq.hoodik.ShareExtension` |
| App Group | `group.com.hudikhq.hoodik` |
| Team ID | `J3G7362G8Y` |
| Display name | Hoodik |
| Version | Defined in `pubspec.yaml` |

**Configuration files:**

- **iOS:** `ios/Runner/Info.plist` (`CFBundleDisplayName`)
- **macOS:** `macos/Runner/Configs/AppInfo.xcconfig` (`PRODUCT_BUNDLE_IDENTIFIER`, `PRODUCT_NAME`)
- **Android:** `android/app/build.gradle.kts` (`applicationId`) and `android/app/src/main/AndroidManifest.xml` (`android:label`)

---

## Store Listing Content

Prepare this content for all stores before submission:

| Field | Requirements |
|-------|-------------|
| **App name** | Hoodik |
| **Subtitle / Short description** | "End-to-End Encrypted Cloud Storage" (max 30 chars iOS, 80 chars Android) |
| **Description** | Up to 4000 chars -- features, E2E encryption value proposition, key capabilities |
| **Keywords (iOS only)** | 100 chars total, e.g. `encryption,cloud,storage,privacy,e2e,files,secure,backup` |
| **Category** | Productivity (iOS/macOS) / Tools or Productivity (Android) |
| **Privacy policy URL** | **REQUIRED** by both stores -- hosted at `https://hoodik.io/privacy` |
| **Support URL** | Required by Apple |
| **Marketing URL** | Optional |

### Privacy policy content

Must cover:
- What data the app collects (minimal -- E2E encrypted, server never sees plaintext)
- How data is stored (encrypted at rest on server and on device)
- Third-party services (none if self-hosted)
- User rights (data deletion, export)
- Contact information

### Content rating (Google Play)

Google requires a content rating questionnaire. For Hoodik:
- No violence, sexual content, drugs, gambling
- User-generated content: Yes (users upload their own files)
- Data sharing: No (E2E encrypted)

This typically results in an "Everyone" / PEGI 3 rating.

### Data Safety (Google Play)

Google requires a data practices declaration:
- **Data collected:** Email address (for account), IP address (server logs)
- **Data shared with third parties:** None
- **Encryption in transit:** Yes (TLS + E2E)
- **Data deletion:** Users can delete their account and all data

---

## App Icons & Screenshots

### App Icon

Start with a 1024x1024 PNG (no transparency for iOS). Configured via `flutter_launcher_icons` in `pubspec.yaml`.

Icon locations:
- **iOS:** `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- **Android:** `android/app/src/main/res/mipmap-*/ic_launcher.png`
- **macOS:** `macos/Runner/Assets.xcassets/AppIcon.appiconset/`

### Screenshots

| Platform | Dimensions | Notes |
|----------|-----------|-------|
| **iOS 6.7"** (iPhone 15 Pro Max) | 1290 x 2796 px | **REQUIRED** |
| **iOS 6.5"** (iPhone 14 Plus) | 1284 x 2778 px | Recommended |
| **iPad 12.9"** | 2048 x 2732 px | Required if supporting iPad |
| **Android** | 16:9 or 9:16, min 320px, max 3840px | 2-8 screenshots required |
| **Android Feature Graphic** | 1024 x 500 px | Displayed at top of listing |
| **macOS** | 1280 x 800 or 1440 x 900 px | Up to 10 screenshots |

Screenshots and the tooling that frames them live in `shotkit/` at the workspace root.

**Tip:** Run the app on a simulator, take screenshots, and add marketing text overlay with Figma or https://screenshots.pro/

---

## iOS Release

### 1. Create signing certificate

**Via Xcode:**
1. Open Xcode -> Settings -> Accounts -> add your Apple ID
2. Select your team -> Manage Certificates
3. Click + -> Apple Distribution (for App Store)

**Via Apple Developer portal:**
1. Go to https://developer.apple.com/account/resources/certificates/list
2. Click + -> Apple Distribution
3. Follow CSR creation steps, download and install the certificate

**Guide:** https://developer.apple.com/help/account/create-certificates/create-a-certificate-signing-request

### 2. Create App ID

1. Go to https://developer.apple.com/account/resources/identifiers/list
2. Click + -> App IDs -> App
3. Bundle ID: `com.hudikhq.hoodik` (Explicit)
4. Enable capabilities as needed
5. Register

### 3. Create provisioning profile

1. Go to https://developer.apple.com/account/resources/profiles/list
2. Click + -> App Store Connect (Distribution)
3. Select your App ID (`com.hudikhq.hoodik`)
4. Select your Distribution certificate
5. Name it: "Hoodik App Store"
6. Download and double-click to install

### 4. Configure Xcode project

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target -> Signing & Capabilities
3. Set your Team, verify Bundle Identifier matches `com.hudikhq.hoodik`
4. Either enable "Automatically manage signing" or manually select your provisioning profile

### 5. Create app in App Store Connect

1. Go to https://appstoreconnect.apple.com -> My Apps -> +
2. Platform: iOS
3. Name: Hoodik
4. Primary language: English
5. Bundle ID: select your registered ID
6. SKU: `hoodik-ios`

### 6. Build and upload

```shell
flutter clean && flutter pub get
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

Output: `build/ios/ipa/hoodik_app.ipa`

**Upload options:**
- **Xcode:** Window -> Organizer -> Distribute App
- **Transporter:** Free Mac App Store app (https://apps.apple.com/app/transporter/id1450874784)
- **Command line:**
  ```shell
  xcrun altool --upload-app -f build/ios/ipa/hoodik_app.ipa -t ios -u APPLE_ID -p APP_SPECIFIC_PASSWORD
  ```
- **Fastlane:** `bundle exec fastlane ios beta` (CI uses this)

After upload, go to App Store Connect -> TestFlight to distribute to testers, or submit for App Store review.

**Guide:** https://docs.flutter.dev/deployment/ios

### 7. App review notes

Apple reviewers need to test the app. Since Hoodik requires a server, provide demo credentials in App Store Connect -> App Review Information -> Notes for Reviewer: the server URL, a review account's email and password, and this explanation:

> App connects to self-hosted servers. All data is end-to-end encrypted -- the server never sees plaintext file content or file names.

Keep the review account's credentials in your password manager, not in this repository.

### iOS permissions

In `ios/Runner/Info.plist`:
- `NSFaceIDUsageDescription` -- "Authenticate to access your Hoodik encryption keys"
- `NSPhotoLibraryUsageDescription` -- Add if supporting photo upload
- `NSCameraUsageDescription` -- Add if supporting camera capture

---

## Android Release

### 1. Create upload keystore

```shell
keytool -genkey -v \
  -keystore ~/hoodik-upload.jks \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias upload \
  -storepass YOUR_PASSWORD \
  -keypass YOUR_PASSWORD \
  -dname "CN=Hoodik, O=HudikHQ, L=City, ST=State, C=Country"
```

**CRITICAL:** Back up this keystore and passwords securely (password manager, encrypted backup). Google Play uses Play App Signing -- they hold the real signing key, but you still need the upload key for every update. Without it you cannot update your app on the Play Store.

### 2. Create key.properties

Create `android/key.properties` (this file is gitignored):

```properties
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=/path/to/hoodik-upload.jks
```

The `build.gradle.kts` automatically picks up these properties for release builds. If the file does not exist, debug signing is used as a fallback for local development.

### 3. Configure build.gradle.kts for release signing

Edit `android/app/build.gradle.kts`. Add at the top (before `android {}` block):

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystoreFile = rootProject.file("key.properties")
if (keystoreFile.exists()) {
    keystoreProperties.load(FileInputStream(keystoreFile))
}
```

Inside the `android {}` block, add or replace signing config:

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String?
        keyPassword = keystoreProperties["keyPassword"] as String?
        storeFile = keystoreProperties["storeFile"]?.let { file(it) }
        storePassword = keystoreProperties["storePassword"] as String?
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

### 4. Create app in Google Play Console

1. Go to https://play.google.com/console -> Create app
2. Name: Hoodik, Default language: English, App (not game)
3. Fill content rating questionnaire
4. Fill Data Safety section (see [Store Listing Content](#store-listing-content))

### 5. Build and upload

```shell
flutter clean && flutter pub get
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

**Upload to Play Console:**
1. Go to your app -> Production -> Create new release
2. Upload `app-release.aab`
3. Opt into Play App Signing (recommended)
4. Add release notes
5. Review and roll out

For direct distribution (side-loading), build an APK instead:

```shell
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

**Guide:** https://docs.flutter.dev/deployment/android

### Android permissions

In `android/app/src/main/AndroidManifest.xml`:
- `android.permission.INTERNET` -- Added by Flutter automatically
- `android.permission.USE_BIOMETRIC` -- Added by `local_auth` automatically
- `android.permission.READ_EXTERNAL_STORAGE` -- Add if needed for file picker on older Android
- `android.permission.WRITE_EXTERNAL_STORAGE` -- Add if needed for downloads on older Android

---

## macOS Release

### 1. Create macOS App ID

Same process as iOS but for macOS:
1. Go to https://developer.apple.com/account/resources/identifiers/list
2. Click + -> App IDs -> App
3. Platform: macOS
4. Bundle ID: `com.hudikhq.hoodik`

### 2. Configure signing

1. Open `macos/Runner.xcodeproj` in Xcode
2. Go to Signing & Capabilities for the Runner target
3. Select your Team
4. Enable Automatically manage signing
5. Add required capabilities (see entitlements below)

### 3. Update release entitlements

Edit `macos/Runner/Release.entitlements` to include biometric and keychain entitlements:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.personal-information.biometric</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)$(CFBundleIdentifier)</string>
    </array>
</dict>
</plist>
```

Note: The biometric and keychain entitlements require code signing. They are intentionally omitted from debug entitlements (`DebugProfile.entitlements`) to allow unsigned debug builds.

### 4. Create app in App Store Connect

1. Go to App Store Connect -> My Apps -> + (or add macOS platform to existing iOS app)
2. Platform: macOS
3. Name: Hoodik, Bundle ID: select registered ID

### 5. Build and upload

```shell
flutter clean && flutter pub get
flutter build macos --release
```

Output: `build/macos/Build/Products/Release/Hoodik.app`

Upload via Xcode Organizer or Transporter, same as iOS.

### 6. Direct distribution (outside App Store)

For distribution outside the Mac App Store, notarization is required:

```shell
flutter build macos --release

# Create a DMG or ZIP, then notarize:
xcrun notarytool submit hoodik.dmg \
  --apple-id YOUR_ID \
  --team-id YOUR_TEAM \
  --password YOUR_APP_SPECIFIC_PASSWORD \
  --wait

xcrun stapler staple hoodik.dmg
```

### macOS sandbox notes

The Mac App Store requires app sandbox. Verify these capabilities work:
- **Network client access** (API calls) -- already entitled
- **Keychain access** (secure storage) -- needs entitlement above
- **File system access** -- sandbox limits this to user-selected files only (file picker is fine)

**Guide:** https://docs.flutter.dev/deployment/macos

---

## Pre-Launch Checklist

- [ ] **Accounts:** Apple Developer + Google Play Console active
- [ ] **Bundle IDs:** `com.hudikhq.hoodik` everywhere
- [ ] **App icons:** Custom Hoodik icon in all sizes
- [ ] **Screenshots:** At least 3 per required device size
- [ ] **Store listing:** Name, description, keywords, category
- [ ] **Privacy policy:** Hosted at public URL
- [ ] **Version:** 1.0.0 in `pubspec.yaml`
- [ ] **Database schema:** if `schemaVersion` changed, export a snapshot for the
      new version and regenerate the helpers — a version without a snapshot has
      no migration anyone can verify afterwards, and snapshots cannot be
      recovered once the release is out:

      ```bash
      dart run drift_dev schema dump lib/core/storage/database.dart drift_schemas/
      dart run drift_dev schema generate drift_schemas/ test/generated/migrations/
      ```
- [ ] **Signing:** iOS cert + profile, Android keystore, macOS cert
- [ ] **Builds:** `flutter build ipa`, `flutter build appbundle`, `flutter build macos` all succeed
- [ ] **Tests:** 203 tests pass, manual smoke test on each platform
- [ ] **Demo server:** Available for Apple reviewers
- [ ] **Review notes:** Test credentials provided
- [ ] **Entitlements:** macOS release entitlements include biometric + keychain

---

## Quick Reference Links

| What | URL |
|------|-----|
| Apple Developer Enrollment | https://developer.apple.com/programs/enroll/ |
| App Store Connect | https://appstoreconnect.apple.com |
| Apple Certificates | https://developer.apple.com/account/resources/certificates/list |
| Apple Provisioning Profiles | https://developer.apple.com/account/resources/profiles/list |
| Apple Small Business Program | https://developer.apple.com/app-store/small-business-program/ |
| Apple Screenshot Specs | https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications |
| Apple Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ |
| Google Play Console | https://play.google.com/console |
| Google Data Safety | https://support.google.com/googleplay/android-developer/answer/10787469 |
| Flutter iOS Deployment | https://docs.flutter.dev/deployment/ios |
| Flutter Android Deployment | https://docs.flutter.dev/deployment/android |
| Flutter macOS Deployment | https://docs.flutter.dev/deployment/macos |

---

## Related Docs

- [Architecture](architecture.md) -- system design and component overview
- [Development](development.md) -- local build setup and prerequisites
- [Security](security.md) -- encryption model and key management
- [Testing](testing.md) -- test strategy and running tests
