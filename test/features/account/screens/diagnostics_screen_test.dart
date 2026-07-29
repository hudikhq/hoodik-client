import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/features/account/screens/diagnostics_screen.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

/// Diagnostics screen has a lot of copy and ends with a primary action —
/// a default 600px viewport truncates the button below the fold, so every
/// test pumps a taller surface.
Future<void> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiagnosticsScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the no-telemetry copy and all four repro steps', (
    tester,
  ) async {
    await _pump(tester);

    expect(
      find.textContaining('don’t track anything about your device'),
      findsOneWidget,
    );
    expect(find.textContaining('doesn’t use Sentry'), findsOneWidget);
    expect(find.text('Close Hoodik completely.'), findsOneWidget);
    expect(find.text('Open it again.'), findsOneWidget);
    expect(find.text('Try to reproduce the bug.'), findsOneWidget);
    expect(
      find.text('Come back here and tap Export Logs below.'),
      findsOneWidget,
    );
  });

  testWidgets('exposes the Export Logs primary button', (tester) async {
    await _pump(tester);
    expect(find.text('Export Logs'), findsOneWidget);
  });

  testWidgets('surfaces the plaintext-in-logs warning', (tester) async {
    await _pump(tester);

    // The user must be informed that filenames may appear and content never
    // will — consent for the redaction step.
    expect(find.textContaining('filenames and server URLs'), findsOneWidget);
    expect(find.textContaining('never contain file contents'), findsOneWidget);
  });
}
