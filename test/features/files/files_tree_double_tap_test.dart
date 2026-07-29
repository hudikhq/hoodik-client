import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/connectivity_service.dart';
import 'package:hoodik_app/core/services/sync_service.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/files/widgets/files_tree_rows.dart';
import 'package:hoodik_app/features/files/widgets/files_tree_view.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

import '../../helpers/fakes.dart';

/// Serves a per-directory children map so a folder's subtree can appear when it
/// expands. The tree only calls [fetchFiles].
class _MapSyncService extends SyncService {
  _MapSyncService(AppDatabase db, ConnectivityService connectivity, this.tree)
    : super(db: db, connectivity: connectivity);

  final Map<String?, List<FileItem>> tree;

  @override
  Future<DirectoryListingResult> fetchFiles({String? dirId}) async {
    return DirectoryListingResult(
      files: tree[dirId] ?? const [],
      isFromCache: false,
    );
  }
}

class _FakeApiClient extends Fake implements ApiClient {}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  testWidgets('double-tapping a folder expands it without navigating', (
    tester,
  ) async {
    final tappedFiles = <FileItem>[];
    final sync = _MapSyncService(
      db,
      FakeConnectivityService(fakeOnline: true),
      {
        null: [FileItem(id: 'folder-1', encryptedName: 'enc', mime: 'dir')],
        'folder-1': [
          FileItem(id: 'child-1', encryptedName: 'enc', mime: 'text/plain'),
        ],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApiClient()),
          syncServiceProvider.overrideWith((ref) => sync),
          connectivityProvider.overrideWith(
            (ref) => FakeConnectivityService(fakeOnline: true),
          ),
          workerManagerProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FilesTreeView(
              rootDirId: null,
              activeFileId: null,
              // Off so the synthetic "Shared with me" probe never runs — this
              // test is only about the folder's expand gesture.
              sharingEnabled: false,
              onTapFile: tappedFiles.add,
              onContextMenu: (_, _) {},
              onMove: (_, _) async {},
              dragPayloadFor: (f) => [f.id],
              usesImmediateDrag: true,
              buildFeedback: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Collapsed: the folder is shown, its child is not.
    expect(find.byType(TreeFolderRow), findsOneWidget);
    expect(find.byType(TreeFileRow), findsNothing);

    // Two taps inside the double-tap window register as a double tap; the
    // short pump keeps the second tap under kDoubleTapTimeout.
    await tester.tap(find.byType(TreeFolderRow));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.byType(TreeFolderRow));
    await tester.pumpAndSettle();

    // Expanded: the child row is now visible…
    expect(
      find.byType(TreeFileRow),
      findsOneWidget,
      reason: 'a double tap toggles expansion, revealing the subtree',
    );
    // …and the single-tap navigate never fired.
    expect(
      tappedFiles,
      isEmpty,
      reason: 'a double tap must not also navigate into the folder',
    );
  });

  testWidgets('a single tap navigates, not expands', (tester) async {
    final tappedFiles = <FileItem>[];
    final sync = _MapSyncService(
      db,
      FakeConnectivityService(fakeOnline: true),
      {
        null: [FileItem(id: 'folder-1', encryptedName: 'enc', mime: 'dir')],
        'folder-1': [
          FileItem(id: 'child-1', encryptedName: 'enc', mime: 'text/plain'),
        ],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApiClient()),
          syncServiceProvider.overrideWith((ref) => sync),
          connectivityProvider.overrideWith(
            (ref) => FakeConnectivityService(fakeOnline: true),
          ),
          workerManagerProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FilesTreeView(
              rootDirId: null,
              activeFileId: null,
              sharingEnabled: false,
              onTapFile: tappedFiles.add,
              onContextMenu: (_, _) {},
              onMove: (_, _) async {},
              dragPayloadFor: (f) => [f.id],
              usesImmediateDrag: true,
              buildFeedback: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TreeFolderRow));
    // A double-tap-aware recognizer holds the single tap until the double-tap
    // window lapses; wait past kDoubleTapTimeout, then confirm the navigate
    // fired and the folder did not expand.
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(tappedFiles.map((f) => f.id), ['folder-1']);
    expect(find.byType(TreeFileRow), findsNothing);
  });
}
