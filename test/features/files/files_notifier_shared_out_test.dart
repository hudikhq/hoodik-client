import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart' show ShareRole;
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/connectivity_service.dart';
import 'package:hoodik_app/core/services/sync_service.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/files/providers/files_notifier.dart';
import 'package:hoodik_app/features/shares/shared_constants.dart';

import '../../helpers/fakes.dart';

class _StubSyncService extends SyncService {
  _StubSyncService(AppDatabase db, ConnectivityService connectivity)
    : super(db: db, connectivity: connectivity);

  List<FileItem> ownedFiles = const [];

  @override
  Future<DirectoryListingResult> fetchFiles({String? dirId}) async {
    return DirectoryListingResult(files: ownedFiles, isFromCache: false);
  }
}

FileItem _owned(String id, {int? sharedWithCount}) => FileItem(
  id: id,
  encryptedName: 'enc-$id',
  mime: 'image/png',
  finishedUploadAt: 1,
  sharedWithCount: sharedWithCount,
);

void main() {
  late AppDatabase db;
  late _StubSyncService sync;

  ProviderContainer container({required List<FileItem> files}) {
    final connectivity = FakeConnectivityService(fakeOnline: true);
    sync = _StubSyncService(db, connectivity)..ownedFiles = files;
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        connectivityProvider.overrideWith((ref) => connectivity),
        syncServiceProvider.overrideWith((ref) => sync),
        workerManagerProvider.overrideWithValue(null),
      ],
    );
  }

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => await db.close());

  group('markFileSharedOut', () {
    test(
      'flips the matching owned row so its owner indicator shows at once',
      () async {
        final c = container(files: [_owned('a'), _owned('b')]);
        addTearDown(c.dispose);
        await c.read(filesNotifierProvider(null).notifier).load();

        // Before: neither owned row reads as shared out.
        var state = c.read(filesNotifierProvider(null));
        expect(
          state.files!.every(
            (f) => !showsOwnerShareIndicator(f, sharingEnabled: true),
          ),
          isTrue,
        );

        c.read(filesNotifierProvider(null).notifier).markFileSharedOut('a');

        state = c.read(filesNotifierProvider(null));
        final a = state.files!.firstWhere((f) => f.id == 'a');
        final b = state.files!.firstWhere((f) => f.id == 'b');
        expect(showsOwnerShareIndicator(a, sharingEnabled: true), isTrue);
        // The other row is untouched.
        expect(showsOwnerShareIndicator(b, sharingEnabled: true), isFalse);
      },
    );

    test('leaves an already-shared row alone — a true no-op, state '
        'unchanged', () async {
      final c = container(files: [_owned('a', sharedWithCount: 3)]);
      addTearDown(c.dispose);
      await c.read(filesNotifierProvider(null).notifier).load();
      final before = c.read(filesNotifierProvider(null));

      c.read(filesNotifierProvider(null).notifier).markFileSharedOut('a');

      final after = c.read(filesNotifierProvider(null));
      // No new snapshot is emitted at all, not merely a count that happens to
      // survive a rebuild.
      expect(identical(after, before), isTrue);
      expect(after.files!.single.sharedWithCount, 3);
    });

    test('is a no-op for an unknown id', () async {
      final c = container(files: [_owned('a')]);
      addTearDown(c.dispose);
      await c.read(filesNotifierProvider(null).notifier).load();
      final before = c.read(filesNotifierProvider(null)).files;

      c.read(filesNotifierProvider(null).notifier).markFileSharedOut('missing');

      expect(
        identical(c.read(filesNotifierProvider(null)).files, before),
        isTrue,
      );
    });
  });

  group('markFileSharedInNone', () {
    test('clears a shared-out owned row so its owner indicator hides at '
        'once', () async {
      final c = container(
        files: [_owned('a', sharedWithCount: 2), _owned('b')],
      );
      addTearDown(c.dispose);
      await c.read(filesNotifierProvider(null).notifier).load();

      var a = c
          .read(filesNotifierProvider(null))
          .files!
          .firstWhere((f) => f.id == 'a');
      expect(showsOwnerShareIndicator(a, sharingEnabled: true), isTrue);

      c.read(filesNotifierProvider(null).notifier).markFileSharedInNone('a');

      final state = c.read(filesNotifierProvider(null));
      a = state.files!.firstWhere((f) => f.id == 'a');
      expect(a.sharedWithCount, 0);
      expect(showsOwnerShareIndicator(a, sharingEnabled: true), isFalse);
    });

    test('leaves an already-cleared row alone — a true no-op, state '
        'unchanged', () async {
      final c = container(files: [_owned('a')]);
      addTearDown(c.dispose);
      await c.read(filesNotifierProvider(null).notifier).load();
      final before = c.read(filesNotifierProvider(null));

      c.read(filesNotifierProvider(null).notifier).markFileSharedInNone('a');

      expect(identical(c.read(filesNotifierProvider(null)), before), isTrue);
    });

    test('is a no-op for an unknown id', () async {
      final c = container(files: [_owned('a', sharedWithCount: 2)]);
      addTearDown(c.dispose);
      await c.read(filesNotifierProvider(null).notifier).load();
      final before = c.read(filesNotifierProvider(null)).files;

      c
          .read(filesNotifierProvider(null).notifier)
          .markFileSharedInNone('missing');

      expect(
        identical(c.read(filesNotifierProvider(null)).files, before),
        isTrue,
      );
    });
  });

  group('FileItem.copyWith', () {
    test('bumps sharedWithCount while preserving every other field', () {
      final original = FileItem(
        id: 'f',
        fileId: 'parent',
        encryptedName: 'enc',
        encryptedKey: 'key',
        mime: 'text/markdown',
        cipher: 'ascon128a',
        editable: true,
        isOwner: false,
        shareRole: ShareRole.editor,
        ownerEmail: 'a@b.test',
        finishedUploadAt: 9,
      );

      final copy = original.copyWith(sharedWithCount: 2);

      expect(copy.sharedWithCount, 2);
      expect(copy.id, 'f');
      expect(copy.fileId, 'parent');
      expect(copy.encryptedKey, 'key');
      expect(copy.cipher, 'ascon128a');
      expect(copy.editable, isTrue);
      expect(copy.isOwner, isFalse);
      expect(copy.shareRole, ShareRole.editor);
      expect(copy.ownerEmail, 'a@b.test');
      expect(copy.finishedUploadAt, 9);
    });

    test('preserves sharedWithCount when no override is given', () {
      final original = _owned('f', sharedWithCount: 5);
      expect(original.copyWith().sharedWithCount, 5);
    });
  });
}
