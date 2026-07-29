package com.hudikhq.hoodik

import io.flutter.embedding.android.FlutterFragmentActivity

// `FlutterFragmentActivity` (rather than the default `FlutterActivity`) is
// required by `local_auth_android` — its BiometricPrompt host needs a
// FragmentActivity ancestor. With plain FlutterActivity the plugin throws
// `PlatformException(code: "no_fragment_activity")` on every biometric
// attempt, which the unlock screen surfaces as a generic "Biometric
// failed" (see GitHub issue #160 — Galaxy S25 / Android 16).
class MainActivity : FlutterFragmentActivity()
