import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart' show ShareRole;
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/connectivity_service.dart';
import 'package:hoodik_app/core/services/sync_service.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/files/providers/files_notifier.dart';
import 'package:hoodik_app/features/shares/shared_constants.dart';

import '../../helpers/fakes.dart';

/// Returns a scripted page of incoming shares and records the paging
/// arguments so a test can assert it walked the whole set.
class _FakeSharesClient extends Fake implements SharesClient {
  _FakeSharesClient({this.pages = const []});

  /// One [IncomingSharePage] per call, in order. The notifier keeps paging
  /// until it has [IncomingSharePage.total] rows or hits an empty page.
  final List<IncomingSharePage> pages;
  int _index = 0;

  final List<(int?, int?)> calls = [];

  @override
  Future<IncomingSharePage> getSharesMine({int? limit, int? offset}) async {
    calls.add((limit, offset));
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

/// A [SyncService] whose directory listing is canned, so the root-injection
/// test doesn't drag in the file-operations provider chain.
class _StubSyncService extends SyncService {
  _StubSyncService(AppDatabase db, ConnectivityService connectivity)
    : super(db: db, connectivity: connectivity);

  List<FileItem> ownedFiles = const [];

  @override
  Future<DirectoryListingResult> fetchFiles({String? dirId}) async {
    return DirectoryListingResult(files: ownedFiles, isFromCache: false);
  }
}

IncomingShare _share(String id, {String mime = 'image/png'}) {
  return IncomingShare(
    fileId: id,
    mime: mime,
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
  late FakeConnectivityService connectivity;
  late _StubSyncService sync;

  ProviderContainer makeContainer({
    required _FakeSharesClient sharesClient,
    bool online = true,
    bool sharingEnabled = true,
  }) {
    final apiClient = _FakeApiClient(sharesClient);
    connectivity.fakeOnline = online;
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(apiClient),
        connectivityProvider.overrideWith((ref) => connectivity),
        syncServiceProvider.overrideWith((ref) => sync),
        workerManagerProvider.overrideWithValue(null),
        shareCapabilitiesProvider.overrideWith(
          (ref) async => sharingEnabled
              ? Capabilities(
                  sharingEnabled: true,
                  roles: const [ShareRole.reader],
                  editableFolders: false,
                  shareGroups: false,
                  auditLog: false,
                  fork: false,
                )
              : const Capabilities.disabled(),
        ),
      ],
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    connectivity = FakeConnectivityService(fakeOnline: true);
    sync = _StubSyncService(db, connectivity);
  });

  tearDown(() async {
    await db.close();
  });

  group('synthetic Shared-with-me listing', () {
    test('maps incoming shares into FileItems, paging through all', () async {
      final sharesClient = _FakeSharesClient(
        pages: [
          IncomingSharePage(
            items: [_share('a'), _share('b')],
            total: 3,
            limit: 2,
            offset: 0,
          ),
          IncomingSharePage(
            items: [_share('c')],
            total: 3,
            limit: 2,
            offset: 2,
          ),
        ],
      );
      final container = makeContainer(sharesClient: sharesClient);
      addTearDown(container.dispose);

      final notifier = container.read(
        filesNotifierProvider(sharedWithMeDirId).notifier,
      );
      await notifier.load();

      final state = container.read(filesNotifierProvider(sharedWithMeDirId));
      expect(state.loading, isFalse);
      expect(state.error, isNull);
      expect(state.files!.map((f) => f.id), ['a', 'b', 'c']);
      expect(state.files!.every((f) => !f.isOwner), isTrue);
      expect(state.files!.first.ownerEmail, 'owner@example.com');
      // Two pages requested, never the root limit:1 probe.
      expect(sharesClient.calls.length, 2);
    });

    test('renders a needs-connection state when offline, no fetch', () async {
      final sharesClient = _FakeSharesClient();
      final container = makeContainer(
        sharesClient: sharesClient,
        online: false,
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        filesNotifierProvider(sharedWithMeDirId).notifier,
      );
      await notifier.load();

      final state = container.read(filesNotifierProvider(sharedWithMeDirId));
      expect(state.loading, isFalse);
      expect(state.files, isEmpty);
      expect(state.error, contains('connection'));
      expect(sharesClient.calls, isEmpty);
    });
  });

  group('root injection', () {
    test('prepends the synthetic folder when the caller has shares', () async {
      sync.ownedFiles = [
        FileItem(id: 'owned-1', encryptedName: 'enc', mime: 'text/plain'),
      ];
      final sharesClient = _FakeSharesClient(
        pages: [
          IncomingSharePage(items: const [], total: 4, limit: 1, offset: 0),
        ],
      );
      final container = makeContainer(sharesClient: sharesClient);
      addTearDown(container.dispose);
      // Resolve the capability future before the root probe reads it.
      await container.read(shareCapabilitiesProvider.future);

      final notifier = container.read(filesNotifierProvider(null).notifier);
      await notifier.load();

      final state = container.read(filesNotifierProvider(null));
      expect(state.files!.first.id, sharedWithMeDirId);
      expect(state.files!.map((f) => f.id), [sharedWithMeDirId, 'owned-1']);
      expect(sharesClient.calls.single, (1, 0));
    });

    test('omits the synthetic folder when the caller has no shares', () async {
      sync.ownedFiles = [
        FileItem(id: 'owned-1', encryptedName: 'enc', mime: 'text/plain'),
      ];
      final sharesClient = _FakeSharesClient(
        pages: [
          IncomingSharePage(items: const [], total: 0, limit: 1, offset: 0),
        ],
      );
      final container = makeContainer(sharesClient: sharesClient);
      addTearDown(container.dispose);
      await container.read(shareCapabilitiesProvider.future);

      final notifier = container.read(filesNotifierProvider(null).notifier);
      await notifier.load();

      final state = container.read(filesNotifierProvider(null));
      expect(state.files!.map((f) => f.id), ['owned-1']);
    });

    test('omits the synthetic folder when sharing is disabled', () async {
      sync.ownedFiles = [
        FileItem(id: 'owned-1', encryptedName: 'enc', mime: 'text/plain'),
      ];
      final sharesClient = _FakeSharesClient(
        pages: [
          IncomingSharePage(items: const [], total: 9, limit: 1, offset: 0),
        ],
      );
      final container = makeContainer(
        sharesClient: sharesClient,
        sharingEnabled: false,
      );
      addTearDown(container.dispose);
      await container.read(shareCapabilitiesProvider.future);

      final notifier = container.read(filesNotifierProvider(null).notifier);
      await notifier.load();

      final state = container.read(filesNotifierProvider(null));
      expect(state.files!.map((f) => f.id), ['owned-1']);
      // The capability gate short-circuits before any probe.
      expect(sharesClient.calls, isEmpty);
    });
  });
}
