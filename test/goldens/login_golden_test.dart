import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/auth/screens/add_server_screen.dart'
    show selectedServerProvider;
import 'package:hoodik_app/features/auth/screens/login_screen.dart';

import 'golden_harness.dart';
import 'login_test_fakes.dart';

/// Golden for the login screen's empty state — the viewport matrix fans
/// that single state into 8 PNGs covering phone/tablet × light/dark ×
/// Material/Cupertino.
void main() {
  late LoginGoldenAuthService auth;

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await configureGoldenEnvironment();
    auth = LoginGoldenAuthService();
  });

  Future<List<Override>> overrides() async {
    final prefs = await fakePreferences();
    return [
      authServiceProvider.overrideWithValue(auth),
      selectedServerProvider.overrideWith((ref) => fakeServer()),
      preferencesProvider.overrideWithValue(prefs),
    ];
  }

  runGoldenMatrix(
    screen: 'login',
    body: (tester, config) async {
      await pumpGoldenHarness(
        tester,
        config: config,
        child: const LoginScreen(),
        overrides: await overrides(),
      );
    },
  );
}
