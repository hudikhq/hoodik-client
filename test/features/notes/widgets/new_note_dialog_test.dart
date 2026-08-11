import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/features/notes/widgets/new_note_dialog.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

/// The dialog used to state where the note would land without letting the
/// user change it, so a note created from the landing screen always went to
/// the root and had to be moved afterwards.
void main() {
  final apple = Platform.isIOS || Platform.isMacOS;

  /// Finds the dialog whichever widget set the host platform draws.
  Finder dialog() =>
      apple ? find.byType(CupertinoAlertDialog) : find.byType(AlertDialog);

  /// The destination control — a button on both platforms, never a caption.
  Finder destination() => find.ancestor(
    of: find.textContaining('note'),
    matching: apple ? find.byType(CupertinoButton) : find.byType(TextButton),
  );

  late NewNote? result;

  Future<void> open(
    WidgetTester tester, {
    String? parentDirId,
    String? parentFolderName,
  }) async {
    result = null;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async => result = await showNewNoteDialog(
                    context: context,
                    parentDirId: parentDirId,
                    parentFolderName: parentFolderName,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the destination is a control, not a caption', (tester) async {
    await open(tester, parentDirId: 'dir-1', parentFolderName: 'Travel');

    expect(find.textContaining('Travel'), findsOneWidget);
    expect(destination(), findsOneWidget);
  });

  testWidgets('root is the destination when none was seeded', (tester) async {
    await open(tester);

    expect(find.textContaining('Travel'), findsNothing);
    expect(destination(), findsOneWidget);
  });

  testWidgets('returns the name and the folder it was seeded with', (
    tester,
  ) async {
    await open(tester, parentDirId: 'dir-1', parentFolderName: 'Travel');

    await tester.enterText(find.byType(EditableText), 'Packing list');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(dialog(), findsNothing);
    expect(result?.name, 'Packing list');
    expect(result?.parentDirId, 'dir-1');
    expect(result?.parentName, 'Travel');
  });

  testWidgets('an empty name is refused', (tester) async {
    await open(tester);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(dialog(), findsOneWidget);
    expect(find.text('Name is required'), findsOneWidget);
    expect(result, isNull);
  });
}
