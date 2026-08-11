import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/features/files/widgets/file_actions_sheet.dart';
import 'package:hoodik_app/features/files/widgets/file_menu_actions_builder.dart';
import 'package:hoodik_app/features/shares/shared_constants.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

FileMenuCallbacks _callbacks({
  void Function(FileItem)? onShare,
  void Function(FileItem)? onLeave,
  void Function(FileItem)? onFork,
}) {
  return FileMenuCallbacks(
    onPreview: (_) {},
    onDownload: (_) {},
    onRename: (_) {},
    onDelete: (_) {},
    onCreateLink: (_) {},
    onShare: onShare,
    onLeave: onLeave,
    onFork: onFork,
    onMakeOffline: (_) {},
    onRemoveOffline: (_) {},
    onDetails: (_) {},
    onConvertToNote: (_) {},
    onSelect: (_) {},
  );
}

FileItem _file({
  bool isOwner = true,
  String mime = 'image/png',
  ShareRole? shareRole,
}) {
  return FileItem(
    id: 'id-1',
    encryptedName: 'enc',
    mime: mime,
    isOwner: isOwner,
    shareRole: shareRole,
    finishedUploadAt: 1,
  );
}

/// Open the sheet over a throwaway scaffold so the modal-route content mounts.
Future<void> _open(
  WidgetTester tester, {
  required FileItem file,
  required bool sharingEnabled,
  FileMenuCallbacks? callbacks,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showFileActionsSheet(
                context: context,
                file: file,
                displayName: 'photo.png',
                isOffline: false,
                sharingEnabled: sharingEnabled,
                callbacks: callbacks ?? _callbacks(onLeave: (_) {}),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('Leave entry in the file actions sheet', () {
    testWidgets('shown for a non-owned file when sharing is enabled', (
      tester,
    ) async {
      await _open(tester, file: _file(isOwner: false), sharingEnabled: true);
      expect(find.text('Leave'), findsOneWidget);
    });

    testWidgets('hidden for an owned file', (tester) async {
      await _open(tester, file: _file(), sharingEnabled: true);
      expect(find.text('Leave'), findsNothing);
    });

    testWidgets('hidden for the synthetic "Shared with me" root row', (
      tester,
    ) async {
      await _open(tester, file: sharedWithMeFolder(), sharingEnabled: true);
      expect(find.text('Leave'), findsNothing);
    });

    testWidgets('hidden when sharing is disabled on the server', (
      tester,
    ) async {
      await _open(tester, file: _file(isOwner: false), sharingEnabled: false);
      expect(find.text('Leave'), findsNothing);
    });

    testWidgets('hidden when the caller did not wire onLeave', (tester) async {
      await _open(
        tester,
        file: _file(isOwner: false),
        sharingEnabled: true,
        callbacks: _callbacks(onLeave: null),
      );
      expect(find.text('Leave'), findsNothing);
    });

    testWidgets('tapping Leave invokes onLeave with the file', (tester) async {
      FileItem? left;
      final file = _file(isOwner: false);
      await _open(
        tester,
        file: file,
        sharingEnabled: true,
        callbacks: _callbacks(onLeave: (f) => left = f),
      );
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(left, same(file));
    });
  });

  group('Save to my drive (Fork) entry in the file actions sheet', () {
    testWidgets('shown for a co-owned non-dir share when sharing is enabled', (
      tester,
    ) async {
      await _open(
        tester,
        file: _file(isOwner: false, shareRole: ShareRole.coOwner),
        sharingEnabled: true,
        callbacks: _callbacks(onFork: (_) {}),
      );
      expect(find.text('Save to my drive'), findsOneWidget);
    });

    testWidgets('hidden for an editor share', (tester) async {
      await _open(
        tester,
        file: _file(isOwner: false, shareRole: ShareRole.editor),
        sharingEnabled: true,
        callbacks: _callbacks(onFork: (_) {}),
      );
      expect(find.text('Save to my drive'), findsNothing);
    });

    testWidgets('hidden for an owned file', (tester) async {
      await _open(
        tester,
        file: _file(),
        sharingEnabled: true,
        callbacks: _callbacks(onFork: (_) {}),
      );
      expect(find.text('Save to my drive'), findsNothing);
    });

    testWidgets('hidden when sharing is disabled on the server', (
      tester,
    ) async {
      await _open(
        tester,
        file: _file(isOwner: false, shareRole: ShareRole.coOwner),
        sharingEnabled: false,
        callbacks: _callbacks(onFork: (_) {}),
      );
      expect(find.text('Save to my drive'), findsNothing);
    });

    testWidgets('hidden when the caller did not wire onFork', (tester) async {
      await _open(
        tester,
        file: _file(isOwner: false, shareRole: ShareRole.coOwner),
        sharingEnabled: true,
        callbacks: _callbacks(onFork: null),
      );
      expect(find.text('Save to my drive'), findsNothing);
    });

    testWidgets('tapping Save to my drive invokes onFork with the file', (
      tester,
    ) async {
      FileItem? forked;
      final file = _file(isOwner: false, shareRole: ShareRole.coOwner);
      await _open(
        tester,
        file: file,
        sharingEnabled: true,
        callbacks: _callbacks(onFork: (f) => forked = f),
      );
      // The sheet scrolls; the fork entry sits below the default test viewport,
      // so bring it on-screen before tapping.
      await tester.ensureVisible(find.text('Save to my drive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save to my drive'));
      await tester.pumpAndSettle();
      expect(forked, same(file));
    });
  });

  group('FAB menu sheet', () {
    Future<void> openFabSheet(
      WidgetTester tester, {
      required VoidCallback onCreateNote,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showFabMenuSheet(
                    context: context,
                    onCreateFolder: () {},
                    onCreateNote: onCreateNote,
                    onUploadFile: () {},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers New note under the Create section', (tester) async {
      var created = false;
      await openFabSheet(tester, onCreateNote: () => created = true);

      // Both phones get the grouped sheet. A Cupertino action sheet is
      // text-only and centred, so it would drop these headers entirely.
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);

      await tester.tap(find.text('New note'));
      await tester.pumpAndSettle();
      expect(created, isTrue);
      expect(find.text('New note'), findsNothing);
    });
  });
}
