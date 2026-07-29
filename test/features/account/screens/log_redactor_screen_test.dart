import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/log_export_service.dart';
import 'package:hoodik_app/core/utils/log_file_sink.dart';
import 'package:hoodik_app/core/utils/logger.dart';
import 'package:hoodik_app/core/widgets/adaptive.dart';
import 'package:hoodik_app/features/account/screens/log_redactor_screen.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

LogRecord _record(DateTime ts, String msg) => LogRecord(
  timestamp: ts,
  level: Level.info,
  component: 'T',
  message: msg,
  fields: const {},
);

void main() {
  late Directory tmp;
  late LogFileSink sink;
  late LogExportService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hoodik_redactor_');
    sink = await LogFileSink.open(directoryOverride: tmp);
    service = LogExportService(sinkOverride: sink);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// The redactor has a sticky footer with two buttons below an Expanded
  /// list; a default 600px viewport crams everything off-screen. Every
  /// test pumps a taller surface to keep the primary actions visible.
  ///
  /// We explicitly sequence the frames because [pumpAndSettle] spins
  /// forever on the Cupertino activity indicator the screen shows while
  /// `_loading = true`.
  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Pump the widget inside runAsync so `_reload`'s real file I/O can
    // complete in real time (the fake test clock would otherwise stall
    // the await on `readLinesSince`).
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LogRedactorScreen(serviceOverride: service),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    // Apply the setState scheduled when `_reload` resolved.
    await tester.pump();
  }

  testWidgets('shows the empty state when there are no logs to review', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('No log lines to review.'), findsOneWidget);
  });

  testWidgets('renders each retained log line and counts them in the toolbar', (
    tester,
  ) async {
    sink.record(_record(DateTime.now(), 'line-one'));
    sink.record(_record(DateTime.now(), 'line-two'));

    await pump(tester);

    expect(find.textContaining('line-one'), findsOneWidget);
    expect(find.textContaining('line-two'), findsOneWidget);
    expect(find.text('2 lines'), findsOneWidget);
  });

  testWidgets('Clear all empties the list and disables the send button', (
    tester,
  ) async {
    sink.record(_record(DateTime.now(), 'one'));
    sink.record(_record(DateTime.now(), 'two'));

    await pump(tester);

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    expect(find.text('No log lines to review.'), findsOneWidget);

    // The primary send button stays mounted but must be disabled when
    // there is nothing left to send — otherwise users can fire an empty
    // share sheet and be confused. Query the platform-agnostic
    // AdaptiveButton wrapper so this test passes on both macOS
    // (Cupertino) and Android (Material) test hosts.
    final sendButton = tester.widget<AdaptiveButton>(
      find.widgetWithText(
        AdaptiveButton,
        'Send via Email (${LogExportService.supportEmail})',
      ),
    );
    expect(sendButton.onPressed, isNull);
  });

  testWidgets('exposes the scope toggle with current-session default', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Current session'), findsOneWidget);
    expect(find.text('Past 3 days'), findsOneWidget);
  });

  testWidgets('exposes a Copy to Clipboard fallback button', (tester) async {
    sink.record(_record(DateTime.now(), 'anything'));
    await pump(tester);

    expect(find.text('Copy to Clipboard'), findsOneWidget);
  });
}
