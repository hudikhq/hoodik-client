import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/features/notes/widgets/notes_landing_app_bar.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

/// Creating a note used to be a floating button that covered the last row of
/// the recent-notes list, and that hid itself once a note was open — which
/// left the mobile layout with no visible way to make a second one. It is an
/// app-bar action now, so it is always reachable and never on top of content.
void main() {
  testWidgets('carries a create action that calls back', (tester) async {
    var created = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: NotesLandingAppBar(onCreateNote: () => created++),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.byTooltip('New note'));
    expect(created, 1);
  });
}
