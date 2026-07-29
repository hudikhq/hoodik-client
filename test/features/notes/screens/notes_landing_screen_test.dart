import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/notes/screens/notes_landing_screen.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

/// Locks the FAB-visibility rule for `/notes` on mobile: the "new note"
/// FAB shows on the recent-notes empty state and disappears the moment a
/// tab is open, so it doesn't sit on top of the editor toolbar / content.
///
/// The signal is piggy-backed on [notesBranchTitleProvider] — null when
/// no tab is open, the active tab's file name otherwise — which the
/// workspace publishes for the breadcrumb anyway. The widget test drives
/// that provider directly instead of mounting the full `NotesWorkspace`,
/// which would pull in WebView / Riverpod / FFI dependencies the unit
/// suite isn't equipped to satisfy.
void main() {
  Future<void> pumpChrome(
    WidgetTester tester, {
    required bool isMobile,
    String? branchTitle,
    VoidCallback? onCreateNote,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notesBranchTitleProvider.overrideWith((_) => branchTitle)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotesLandingChrome(
            isMobile: isMobile,
            onCreateNote: onCreateNote ?? () {},
            child: const SizedBox.shrink(key: Key('workspace-stub')),
          ),
        ),
      ),
    );
  }

  group('NotesLandingChrome', () {
    testWidgets('mobile + no open note → FAB visible (this is the only '
        'discoverable "new note" affordance on the mobile layout)', (
      tester,
    ) async {
      await pumpChrome(tester, isMobile: true, branchTitle: null);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byTooltip('New note'), findsOneWidget);
    });

    testWidgets('mobile + a note is open → FAB hidden so it does not sit '
        'on top of the editor toolbar / content', (tester) async {
      await pumpChrome(
        tester,
        isMobile: true,
        branchTitle: 'AlternativeTo-Listing.md',
      );
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('FAB toggles with the open-note signal across rebuilds — '
        'a tab close pushes the title back to null and the FAB returns', (
      tester,
    ) async {
      // Start with a note open: FAB is gone.
      final container = ProviderContainer(
        overrides: [
          notesBranchTitleProvider.overrideWith((_) => 'open-note.md'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotesLandingChrome(
              isMobile: true,
              onCreateNote: () {},
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      expect(find.byType(FloatingActionButton), findsNothing);

      // Close the note → branch title goes null → FAB reappears.
      container.read(notesBranchTitleProvider.notifier).state = null;
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('desktop / tablet path → no FAB regardless of branch '
        'title (sidebar already has its own "new" control)', (tester) async {
      await pumpChrome(tester, isMobile: false, branchTitle: null);
      expect(find.byType(FloatingActionButton), findsNothing);

      await pumpChrome(tester, isMobile: false, branchTitle: 'open-note.md');
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('tapping the FAB invokes onCreateNote (the only way to '
        'create a new note on mobile when no tab is open)', (tester) async {
      var taps = 0;
      await pumpChrome(
        tester,
        isMobile: true,
        branchTitle: null,
        onCreateNote: () => taps++,
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(taps, equals(1));
    });
  });
}
