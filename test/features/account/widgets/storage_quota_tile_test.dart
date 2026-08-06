import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/account/widgets/storage_quota_tile.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

Account _account({int? quota}) => Account(
  id: 'a1',
  serverId: 's1',
  userId: 'u1',
  email: 'test@test.com',
  quota: quota,
  isActive: true,
  createdAt: DateTime(2026),
);

Future<void> _pump(
  WidgetTester tester, {
  StorageUsage? usage,
  Account? account,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeAccountProvider.overrideWith((ref) => account),
        storageUsageProvider.overrideWith((ref) async => usage),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: StorageQuotaTile()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders a used/total bar when usage and quota are known', (
    tester,
  ) async {
    await _pump(
      tester,
      account: _account(quota: 1024 * 1024 * 1024),
      usage: const StorageUsage(
        usedSpace: 512 * 1024 * 1024,
        quota: 1024 * 1024 * 1024,
      ),
    );

    expect(find.text('512.0 MB of 1.0 GB used'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.5, 0.001));
  });

  testWidgets('shows used space without a bar on unlimited accounts', (
    tester,
  ) async {
    await _pump(
      tester,
      account: _account(),
      usage: const StorageUsage(usedSpace: 512 * 1024 * 1024),
    );

    expect(find.textContaining('512.0 MB used'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('falls back to the cached quota while stats are unavailable', (
    tester,
  ) async {
    await _pump(tester, account: _account(quota: 1024 * 1024 * 1024));

    expect(find.text('Quota: 1.0 GB'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
