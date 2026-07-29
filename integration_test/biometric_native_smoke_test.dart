import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_auth/local_auth.dart';

/// Native-layer smoke test for the biometric unlock plumbing.
///
/// **Why this exists, the short version**: the existing
/// `e2e/biometric_unlock_test.dart` stubs the `local_auth` MethodChannel
/// before any native code runs (its docstring says so explicitly). That
/// makes it useful for asserting the *Dart* state machine — lock overlay,
/// PIN re-population, etc. — but it would have happily passed with a
/// MainActivity that extends `FlutterActivity` instead of
/// `FlutterFragmentActivity`, which is exactly the configuration that
/// triggered GitHub issue #160.
///
/// This test crosses the native boundary on purpose. It calls
/// `LocalAuthentication.authenticate` against the *real* MethodChannel,
/// then asserts the failure is anything other than the
/// `"no_fragment_activity"` PlatformException — which is the platform
/// channel's literal way of saying "your host activity is wrong, fix
/// MainActivity".
///
/// We don't assert success. The emulator typically has no biometric
/// enrolled, so the call legitimately fails with `NotEnrolled`,
/// `NotAvailable`, or returns `false`. That's fine — the bug we're
/// guarding against is a *specific* native-config error, not a
/// general "biometric works" assertion (which can't be tested on
/// emulators without OEM-specific setup).
///
/// Pre-fix this test fails with `PlatformException(code:
/// "no_fragment_activity", ...)`. Post-fix it passes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LocalAuthentication crosses the native boundary without '
      'tripping no_fragment_activity — proves MainActivity extends '
      'FlutterFragmentActivity (issue #160)', (tester) async {
    final auth = LocalAuthentication();

    // Touch a couple of native methods before authenticate(). On an
    // emulator with no biometric hardware exposed, these can also be
    // the call that surfaces a misconfigured host activity, depending
    // on the local_auth_android version. Both must complete without
    // throwing the host-activity error.
    await expectLater(
      () async => auth.isDeviceSupported(),
      returnsNormally,
      reason:
          'isDeviceSupported() must complete without a host-activity '
          'error — it does no UI work, just queries the hardware',
    );
    await expectLater(() async => auth.canCheckBiometrics, returnsNormally);

    // The real test: authenticate() shows the BiometricPrompt and
    // *that* is the call that needs a FragmentActivity ancestor. With
    // FlutterActivity, local_auth_android throws here.
    try {
      await auth.authenticate(
        localizedReason: 'Hoodik integration smoke test',
        options: const AuthenticationOptions(
          biometricOnly: false,
          // Don't get stuck waiting for the user — fail fast if the
          // emulator has no biometric. Either outcome (NotEnrolled,
          // NotAvailable, or a quick `false`) is acceptable; only
          // no_fragment_activity is the bug we're catching.
          stickyAuth: false,
        ),
      );
      // No exception → either succeeded (very unlikely on emulator) or
      // returned false silently. Both are non-bug outcomes.
    } on PlatformException catch (e) {
      expect(
        e.code,
        isNot(equals('no_fragment_activity')),
        reason:
            'PlatformException(code: "no_fragment_activity") means '
            'MainActivity does NOT extend FlutterFragmentActivity. '
            'See android/app/src/main/kotlin/.../MainActivity.kt — it '
            'must use FlutterFragmentActivity for local_auth_android '
            'to function. Issue #160.',
      );
      // Any other code is fine. Common ones on a fresh emulator:
      //   - "NotEnrolled"  : no fingerprint / face registered
      //   - "NotAvailable" : emulator has no biometric hardware
      //   - "PasscodeNotSet": device has no lock screen credential
      // These are all expected when the host activity is correctly
      // configured but the test environment lacks biometric setup.
    }
  });
}
