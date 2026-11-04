import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/features/files/widgets/files_empty_state.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

Future<void> _pump(WidgetTester tester, VoidCallback? onAdd) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: FilesEmptyState(onAdd: onAdd)),
    ),
  );
}

void main() {
  testWidgets('shows the add button when it has a callback', (tester) async {
    await _pump(tester, () {});
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('hides the add button without a callback', (tester) async {
    await _pump(tester, null);
    expect(find.byType(ElevatedButton), findsNothing);
  });
}
