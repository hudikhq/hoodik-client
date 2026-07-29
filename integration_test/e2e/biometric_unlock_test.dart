import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../fixtures.dart';
import 'test_env.dart';
import 'test_hooks.dart';

/// Flow #2 from spec §4. After onboarding, background the app for long
/// enough that the lock grace period (3s) elapses, resume, and verify
/// the lock overlay shows. Then drive the biometric flow — success
/// dismisses the overlay and repopulates the private key; failure
/// keeps the PIN screen visible.
///
/// `local_auth` is not a Patrol-controllable dialog, so these tests
/// stub its MethodChannel directly. This is the same approach the
/// package recommends for integration tests where an actual biometric
/// scan is not available (simulators lack real sensors; `Matching Face`
/// is available on iOS sim but not on Android emulators pre-API 30).
///
/// We accept that the stubbing bypasses one OS layer. The goal of this
/// test is to prove the *app's* state transitions — lock overlay on
/// background, PIN repopulated on success, overlay retained on
/// failure — not to re-test the platform's biometric implementation.
void main() {
  late Fixtures fixtures;

  patrolSetUp(() async {
    fixtures = await Fixtures.prepare();
    await TestHooks.wipeLocalState();
  });

  patrolTearDown(() async {
    await fixtures.cleanup();
    _restoreBiometric();
  });

  patrolTest(
    'biometric success dismisses the lock overlay and keeps the key in memory',
    ($) async {
      unawaited(app.main());
      await $.pumpAndSettle();

      await TestHooks.onboardAndLogin(
        $,
        TestEnv.serverUrl,
        TestEnv.email,
        TestEnv.password,
        TestEnv.pin,
      );

      _stubBiometric(success: true);

      await $.native.pressHome();
      await Future<void>.delayed(const Duration(seconds: 5));
      await $.native.openApp();
      await $.pumpAndSettle();

      await $.waitUntilVisible(
        $('Enter Passcode'),
        timeout: const Duration(seconds: 10),
      );

      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      final container = TestHooks.containerForTest();
      expect(
        container.read(isLockedProvider),
        isFalse,
        reason: 'biometric success must clear the lock',
      );
      expect(
        container.read(decryptedPrivateKeyProvider),
        isNotNull,
        reason: 'private key must still be populated after biometric unlock',
      );
    },
  );

  patrolTest(
    'biometric failure leaves the lock overlay visible for PIN fallback',
    ($) async {
      unawaited(app.main());
      await $.pumpAndSettle();

      await TestHooks.onboardAndLogin(
        $,
        TestEnv.serverUrl,
        TestEnv.email,
        TestEnv.password,
        TestEnv.pin,
      );

      _stubBiometric(success: false);

      await $.native.pressHome();
      await Future<void>.delayed(const Duration(seconds: 5));
      await $.native.openApp();
      await $.pumpAndSettle();

      await $.waitUntilVisible(
        $('Enter Passcode'),
        timeout: const Duration(seconds: 10),
      );

      final container = TestHooks.containerForTest();
      expect(
        container.read(isLockedProvider),
        isTrue,
        reason: 'biometric failure must leave the overlay up',
      );
      expect(
        $('Enter Passcode').evaluate().isNotEmpty,
        isTrue,
        reason: 'PIN fallback UI must remain visible for manual unlock',
      );
    },
  );
}

const MethodChannel _biometricChannel = MethodChannel(
  'plugins.flutter.io/local_auth',
);

void _stubBiometric({required bool success}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_biometricChannel, (call) async {
        switch (call.method) {
          case 'authenticate':
            return success;
          case 'getAvailableBiometrics':
            return <String>['face'];
          case 'isDeviceSupported':
          case 'deviceSupportsBiometrics':
            return true;
        }
        return null;
      });
}

void _restoreBiometric() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_biometricChannel, null);
}
