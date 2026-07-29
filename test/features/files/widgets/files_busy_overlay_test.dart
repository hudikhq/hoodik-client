import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/features/files/controllers/files_upload_controller.dart';
import 'package:hoodik_app/features/files/widgets/files_busy_overlay.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool busy = false,
    bool preparing = false,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [uploadPreparingProvider.overrideWith((ref) => preparing)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FilesBusyOverlay(busy: busy),
        ),
      ),
    );
  }

  testWidgets('renders nothing when idle', (tester) async {
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('busy shows spinner without label', (tester) async {
    await pump(tester, busy: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Preparing…'), findsNothing);
  });

  testWidgets('preparing shows spinner with label', (tester) async {
    await pump(tester, preparing: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Preparing…'), findsOneWidget);
  });
}
