import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/theme/hoodik_theme.dart';
import 'package:hoodik_app/core/widgets/app_notification.dart';
import 'package:hoodik_app/features/account/screens/recovery_key_screen.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

import '../../auth/screens/auth_test_helpers.dart';

class _MigratedFakeAuthService extends FakeAuthService {
  String? fakeLegacyRsa;

  @override
  String? get decryptedLegacyRsaPrivateKey => fakeLegacyRsa;
}

void main() {
  late _MigratedFakeAuthService fakeAuth;

  setUp(() => fakeAuth = _MigratedFakeAuthService());
  tearDown(() => AppNotification.dismiss());

  Widget buildApp({String? identity, String? wrapping}) {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(fakeAuth),
        decryptedPrivateKeyProvider.overrideWith((ref) => identity),
        decryptedWrappingPrivateKeyProvider.overrideWith((ref) => wrapping),
      ],
      child: MaterialApp(
        theme: HoodikTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RecoveryKeyScreen(),
      ),
    );
  }

  testWidgets('reveals the full bundle for a migrated curve account', (
    tester,
  ) async {
    fakeAuth.fakeLegacyRsa = 'RSA_PEM';

    await tester.pumpWidget(buildApp(identity: 'ID_PEM', wrapping: 'W_PEM'));
    await tester.pumpAndSettle();

    const bundle = 'v1|rsa:RSA_PEM|ed:ID_PEM|x:W_PEM';
    expect(find.text(bundle), findsNothing);

    await tester.tap(find.byKey(const Key('revealRecoveryKey')));
    await tester.pumpAndSettle();
    expect(find.text(bundle), findsOneWidget);

    await tester.tap(find.byKey(const Key('revealRecoveryKey')));
    await tester.pumpAndSettle();
    expect(find.text(bundle), findsNothing);
  });

  testWidgets('shows the bare PEM for a legacy RSA account', (tester) async {
    await tester.pumpWidget(buildApp(identity: 'RSA_ONLY_PEM'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('revealRecoveryKey')));
    await tester.pumpAndSettle();
    expect(find.text('RSA_ONLY_PEM'), findsOneWidget);
  });

  testWidgets('copy confirms without revealing the key', (tester) async {
    // Clipboard.setData's platform message gets no reply in the test
    // environment, so the copy handler would await forever without this stub.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );

    await tester.pumpWidget(buildApp(identity: 'ID_PEM', wrapping: 'W_PEM'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('copyRecoveryKey')));
    await tester.pumpAndSettle();

    expect(find.text('Recovery key copied'), findsOneWidget);
    expect(find.text('v1|ed:ID_PEM|x:W_PEM'), findsNothing);
  });

  testWidgets('explains when no key is unlocked', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('revealRecoveryKey')), findsNothing);
    expect(find.textContaining('Sign in with your password'), findsOneWidget);
  });
}
