import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/theme/hoodik_theme.dart';
import 'package:hoodik_app/features/auth/services/migration_notice.dart';
import 'package:hoodik_app/features/auth/widgets/migration_notice_gate.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/auth_test_helpers.dart';

class _MigratedFakeAuthService extends FakeAuthService {
  String? fakeLegacyRsa;

  @override
  String? get decryptedLegacyRsaPrivateKey => fakeLegacyRsa;
}

void main() {
  const noticeTitle = 'Your account security was upgraded';

  late _MigratedFakeAuthService fakeAuth;

  setUp(() {
    fakeAuth = _MigratedFakeAuthService();
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(fakeAuth),
        activeAccountProvider.overrideWith(
          (ref) => fakeAccount(id: 'srv_user@test.com'),
        ),
      ],
      child: MaterialApp(
        theme: HoodikTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MigrationNoticeGate(child: Text('SHELL')),
      ),
    );
  }

  testWidgets('shows the notice once for a migrated account', (tester) async {
    fakeAuth.fakeLegacyRsa = 'LEGACY_RSA_PEM';

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text(noticeTitle), findsOneWidget);
    expect(find.text('SHELL'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text(noticeTitle), findsNothing);

    expect(await isMigrationNoticeSeen('srv_user@test.com'), isTrue);
  });

  testWidgets('stays silent once the notice was acknowledged', (tester) async {
    fakeAuth.fakeLegacyRsa = 'LEGACY_RSA_PEM';
    await markMigrationNoticeSeen('srv_user@test.com');

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text(noticeTitle), findsNothing);
  });

  testWidgets('stays silent without a retained RSA key', (tester) async {
    fakeAuth.fakeLegacyRsa = null;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text(noticeTitle), findsNothing);
  });
}
