import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/app_update.dart';
import 'package:hoodik_app/core/widgets/app_update_nudge.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

Widget _pump({required String? current, required AppStoreVersion? store}) {
  return ProviderScope(
    overrides: [
      currentAppVersionProvider.overrideWith((ref) async => current),
      latestAppStoreVersionProvider.overrideWith((ref) async => store),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AppUpdateNudge()),
    ),
  );
}

const _store = AppStoreVersion(
  version: '2.0.1',
  storeUrl: 'https://apps.apple.com/app/id123',
);

void main() {
  testWidgets('hides while the store version is unknown', (tester) async {
    // Android and offline both land here — no store version means no nudge.
    await tester.pumpWidget(_pump(current: '2.0.0', store: null));
    await tester.pump();
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('hides when the running version matches the store', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(current: '2.0.1', store: _store));
    await tester.pump();
    expect(
      find.textContaining('new version', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('hides when running ahead of the store', (tester) async {
    await tester.pumpWidget(_pump(current: '2.1.0', store: _store));
    await tester.pump();
    expect(
      find.textContaining('new version', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('shows the banner with the store version when behind', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(current: '2.0.0', store: _store));
    await tester.pump();
    expect(find.textContaining('v2.0.1', findRichText: true), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app_update_banner_update')),
      findsOneWidget,
    );
  });

  testWidgets('dismiss hides the banner for the session', (tester) async {
    await tester.pumpWidget(_pump(current: '2.0.0', store: _store));
    await tester.pump();
    expect(
      find.textContaining('new version', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('app_update_banner_dismiss')));
    await tester.pump();
    expect(
      find.textContaining('new version', findRichText: true),
      findsNothing,
    );
  });
}
