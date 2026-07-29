import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/account/screens/mcp_audit_log_screen.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

/// Build an in-memory Drift instance just for the synchronous seeds —
/// we only need it to mint valid [McpAuditLogData] rows; the provider is
/// overridden with a static stream so the widget tree never subscribes to
/// a real Drift stream (those leave pending timers that trip the test
/// framework's leak detector).
AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

/// Push fresh synthetic entries through the override controller so the
/// screen rebuilds with the expected data.
McpAuditLogData _sample({
  int id = 1,
  String tool = 'list_files',
  String status = 'ok',
  String? errorMessage,
}) {
  return McpAuditLogData(
    id: id,
    timestamp: DateTime(2026, 4, 19, 12, id),
    sessionId: '0123456789abcdef',
    accountId: 'acct-1',
    toolName: tool,
    paramsHash: 'a' * 64,
    resultStatus: status,
    errorMessage: errorMessage,
    durationMs: 5,
  );
}

Widget _harness(List<McpAuditLogData> entries, AppDatabase db) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      mcpAuditLogProvider.overrideWith((_) => Stream.value(entries)),
      mcpAuditToolNamesProvider.overrideWith(
        (_) async => entries.map((e) => e.toolName).toSet().toList()..sort(),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: McpAuditLogScreen(),
    ),
  );
}

void main() {
  testWidgets('renders empty state when the log is empty', (tester) async {
    final db = _db();
    addTearDown(db.close);

    await tester.pumpWidget(_harness(const [], db));
    await tester.pumpAndSettle();

    expect(find.text('No audit entries yet'), findsOneWidget);
  });

  testWidgets('renders one row per audit entry', (tester) async {
    final db = _db();
    addTearDown(db.close);

    final entries = [
      _sample(id: 1, tool: 'list_files'),
      _sample(id: 2, tool: 'read_file'),
      _sample(id: 3, tool: 'write_file', status: 'error'),
    ];

    await tester.pumpWidget(_harness(entries, db));
    await tester.pumpAndSettle();

    expect(find.text('list_files'), findsOneWidget);
    expect(find.text('read_file'), findsOneWidget);
    expect(find.text('write_file'), findsOneWidget);
    expect(find.text('error'), findsOneWidget);
    // 'ok' appears in at least one status chip.
    expect(find.text('ok'), findsWidgets);
  });

  testWidgets('tool name is rendered in monospace so long names stay aligned', (
    tester,
  ) async {
    final db = _db();
    addTearDown(db.close);

    await tester.pumpWidget(_harness([_sample(tool: 'rename_file')], db));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('rename_file'));
    expect(title.style?.fontFamily, 'monospace');
  });

  testWidgets('filter popup menu buttons are exposed in the app bar', (
    tester,
  ) async {
    final db = _db();
    addTearDown(db.close);

    await tester.pumpWidget(_harness(const [], db));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Filter by tool'), findsOneWidget);
    expect(find.byTooltip('Filter by status'), findsOneWidget);
  });

  testWidgets('opening an entry reveals a detail sheet with every field', (
    tester,
  ) async {
    final db = _db();
    addTearDown(db.close);

    await tester.pumpWidget(_harness([_sample()], db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('list_files'));
    await tester.pumpAndSettle();

    expect(find.text('Timestamp'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Session'), findsOneWidget);
    expect(find.text('Params hash'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('detail sheet body scrolls so tall content cannot overflow', (
    tester,
  ) async {
    final db = _db();
    addTearDown(db.close);

    await tester.pumpWidget(_harness([_sample()], db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('list_files'));
    await tester.pumpAndSettle();

    // Regression: the sheet used to render a plain Column, which threw the
    // 'BOTTOM OVERFLOWED' banner under large text scale factors. It must
    // now live inside a SingleChildScrollView so content scrolls instead.
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
