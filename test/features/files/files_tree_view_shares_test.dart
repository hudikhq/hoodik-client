import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart' show ShareRole;
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/connectivity_service.dart';
import 'package:hoodik_app/core/services/sync_service.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/files/widgets/files_tree_rows.dart';
import 'package:hoodik_app/features/files/widgets/files_tree_view.dart';
import 'package:hoodik_app/features/shares/shared_constants.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

import '../../helpers/fakes.dart';

class _FakeSharesClient extends Fake implements SharesClient {
  _FakeSharesClient({this.pages = const []});

  final List<IncomingSharePage> pages;
  int _index = 0;

  @override
  Future<IncomingSharePage> getSharesMine({int? limit, int? offset}) async {
    final page = _index < pages.length ? pages[_index] : _emptyPage;
    _index++;
    return page;
  }

  IncomingSharePage get _emptyPage =>
      IncomingSharePage(items: const [], total: 0, limit: 0, offset: 0);
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._shares);

  final _FakeSharesClient _shares;

  @override
  SharesClient get shares => _shares;
}

class _StubSyncService extends SyncService {
  _StubSyncService(AppDatabase db, ConnectivityService connectivity)
    : super(db: db, connectivity: connectivity);

  List<FileItem> ownedFiles = const [];

  @override
  Future<DirectoryListingResult> fetchFiles({String? dirId}) async {
    return DirectoryListingResult(files: ownedFiles, isFromCache: false);
  }
}

IncomingShare _share(String id) {
  return IncomingShare(
    fileId: id,
    mime: 'image/png',
    encryptedName: 'enc-name-$id',
    cipher: 'aegis128l',
    editable: false,
    shareRole: ShareRole.reader,
    encryptedKey: 'enc-key-$id',
    createdAt: 100,
    finishedUploadAt: 200,
    ownerId: 'owner-uuid',
    ownerEmail: 'owner@example.com',
    ownerPubkey: 'pub',
    ownerPubkeyFingerprint: 'fp',
  );
}

void main() {
  late AppDatabase db;
  late _StubSyncService sync;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sync = _StubSyncService(db, FakeConnectivityService(fakeOnline: true));
  });

  tearDown(() async => db.close());

  Future<void> pumpTree(
    WidgetTester tester, {
    required String? rootDirId,
    required _FakeSharesClient sharesClient,
    bool sharingEnabled = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApiClient(sharesClient)),
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
              rootDirId: rootDirId,
              activeFileId: null,
              sharingEnabled: sharingEnabled,
              onTapFile: (_) {},
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
  }

  testWidgets('shows the "Shared with me" folder at root when shares exist', (
    tester,
  ) async {
    sync.ownedFiles = [
      FileItem(id: 'owned-1', encryptedName: 'enc', mime: 'dir'),
    ];
    final sharesClient = _FakeSharesClient(
      pages: [
        IncomingSharePage(items: const [], total: 2, limit: 1, offset: 0),
      ],
    );

    await pumpTree(tester, rootDirId: null, sharesClient: sharesClient);

    expect(find.text(sharedWithMeDirName), findsOneWidget);
  });

  testWidgets('omits the synthetic folder at root when there are no shares', (
    tester,
  ) async {
    sync.ownedFiles = [
      FileItem(id: 'owned-1', encryptedName: 'enc', mime: 'dir'),
    ];
    final sharesClient = _FakeSharesClient(
      pages: [
        IncomingSharePage(items: const [], total: 0, limit: 1, offset: 0),
      ],
    );

    await pumpTree(tester, rootDirId: null, sharesClient: sharesClient);

    expect(find.text(sharedWithMeDirName), findsNothing);
  });

  testWidgets('lists the incoming shares when rooted at the synthetic folder', (
    tester,
  ) async {
    final sharesClient = _FakeSharesClient(
      pages: [
        IncomingSharePage(
          items: [_share('a'), _share('b')],
          total: 2,
          limit: 100,
          offset: 0,
        ),
      ],
    );

    await pumpTree(
      tester,
      rootDirId: sharedWithMeDirId,
      sharesClient: sharesClient,
    );

    expect(find.byType(TreeFileRow), findsNWidgets(2));
  });
}
