# Biometric unlock — manual verification checklist

This is the on-device QA pass for the biometric unlock flow. Use it
before tagging a release that touches `MainActivity.kt`,
`AndroidManifest.xml`, `local_auth*` versions, or
`features/auth/screens/unlock_screen.dart`.

The native smoke test (`integration_test/biometric_native_smoke_test.dart`)
catches the most common regression — `MainActivity` not extending
`FlutterFragmentActivity` — but it runs on an emulator that may not
have biometric hardware. End-to-end on a real device with an enrolled
biometric is the only thing that proves a user-visible unlock works.

GitHub issue [#160](https://github.com/hudikhq/hoodik/issues/160) was
the motivating case (Samsung Galaxy S25 / Android 16 → "Biometric
failed").

## Setup (real device — Android or iOS)

1. Enrol a fingerprint or Face ID on the device through system Settings.
   Hoodik never sees the biometric itself; it just asks the OS to
   confirm "user authenticated" via `local_auth`.
2. Install the candidate build (TestFlight / Play internal track / sideload).
3. Sign out of any existing Hoodik account so you start clean.

## Steps

### 1. First-time enable

- Sign in with email + password on a test server (or the demo).
- Set a 4–8 digit PIN when prompted.
- Open Account → Security → toggle "Biometric unlock" **on**.
  - Expected: the OS biometric prompt appears.
  - On approval: toggle stays on, no error banner.
  - On denial: toggle stays off, no error banner. (Not a bug.)

### 2. Lock + unlock

- Background the app for ≥ 10 s, then resume.
  - Expected: lock overlay (`Enter Passcode`) appears with a
    "Use Biometric" button, and the OS biometric prompt fires
    automatically.
- Approve the biometric.
  - Expected: lock overlay disappears, you're back in the app, files
    list / notes list still populated (private key was rehydrated).

### 3. Negative paths — each should match the table below

| Scenario | Expected behaviour |
|---|---|
| Tap "Use Biometric" then **cancel** the OS prompt | No error banner; PIN field stays focused. Re-tap unlocks again. |
| Fail biometric 3–5 times (Android-specific, varies by OEM) | "Too many attempts — try again in 30 s, or use your PIN" |
| Disable the device's biometric in Settings, then come back | "No biometric enrolled on this device — use your PIN" |
| Unlock with PIN instead of biometric | Always works. The biometric path is a shortcut, not a replacement. |

If any of these surface a generic "Biometric failed" *without* the
specific message above, capture the in-app log (Account → Diagnostics →
Export Log) and attach it to the bug — the new logging emits
`platform_code` / `platform_message` fields directly from the OS so the
actual cause is visible.

### 4. Galaxy S25 / Android 16 specifically

This is the device class that reproduced #160. Extra confirmation steps:

- Step 1 (enable) — the OS prompt must show as **Samsung Pass** UI
  styling, not the generic Material BiometricPrompt. Either is fine
  functionally, but Samsung's wrapper is what was failing pre-fix.
- Step 2 (unlock) — must succeed without showing
  "Biometric failed" anywhere on screen.
- Watch the in-app log during step 2 — there should be no
  `platform_code: "no_fragment_activity"` records. (If there are, the
  `MainActivity` fix didn't ship; check the APK.)

## What this checklist does NOT cover

- iOS Touch ID / Face ID — the bug was Android-specific
  (FlutterFragmentActivity), but the unlock screen path is shared, so
  a pass here doesn't prove iOS regressed. Run the same checklist on
  an iPhone before any auth-related change ships.
- The PIN-only fallback. Covered by `e2e/biometric_unlock_test.dart`
  (which stubs the native channel — different layer).

## When to update this doc

Add new rows to the table above whenever:
- A new `PlatformException.code` shows up in production logs that the
  unlock screen handles. Update `_biometricMessageFor` in
  `unlock_screen.dart` and add the row.
- A new device class breaks. Add a §4-style sub-section with what's
  unique about it.
