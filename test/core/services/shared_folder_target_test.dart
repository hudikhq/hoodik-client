import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_models.dart';
import 'package:hoodik_app/core/api/files_client.dart';
import 'package:hoodik_app/core/services/shared_folder_target.dart';

/// Scripts per-id metadata so the resolver's parent-chain walk can traverse a
/// tree, and counts fetches so a test can assert it short-circuits (root, held
/// item, capability off) without a network round-trip.
class _FakeFilesClient extends Fake implements FilesClient {
  _FakeFilesClient(this.byId);

  final Map<String, Map<String, dynamic>> byId;
  int fetches = 0;

  @override
  Future<Map<String, dynamic>> getFileMetadata(String fileId) async {
    fetches += 1;
    final meta = byId[fileId];
    if (meta == null) throw StateError('no metadata for $fileId');
    return meta;
  }
}

Map<String, dynamic> _meta({
  String id = 'folder-id',
  String? parentId,
  required bool isOwner,
  int? membersSignedAt,
  String mime = 'dir',
}) => {
  'id': id,
  'file_id': parentId,
  'mime': mime,
  'is_owner': isOwner,
  'members_signed_at': membersSignedAt,
};

FileItem _item({
  String id = 'folder-id',
  String? parentId,
  required bool isOwner,
  int? membersSignedAt,
  String mime = 'dir',
}) => FileItem.fromJson(
  _meta(
    id: id,
    parentId: parentId,
    isOwner: isOwner,
    membersSignedAt: membersSignedAt,
    mime: mime,
  ),
);

void main() {
  SharedFolderTargetResolver build(
    _FakeFilesClient files, {
    bool sharingEnabled = true,
  }) =>
      SharedFolderTargetResolver(files: files, sharingEnabled: sharingEnabled);

  group('resolveWriteRosterId', () {
    test('the account root is never shared and is not fetched', () async {
      final files = _FakeFilesClient({});
      expect(await build(files).resolveWriteRosterId(null), isNull);
      expect(files.fetches, 0);
    });

    test(
      'sharing off (kill-switch or old server) never engages multi-key',
      () async {
        final files = _FakeFilesClient({});
        final resolver = build(files, sharingEnabled: false);
        expect(await resolver.resolveWriteRosterId('folder-id'), isNull);
        expect(
          await resolver.resolveWriteRosterId(
            'folder-id',
            parentItem: _item(isOwner: false),
          ),
          isNull,
        );
        expect(files.fetches, 0);
      },
    );

    test('a held signed folder resolves to itself without a fetch', () async {
      final files = _FakeFilesClient({});
      final resolved = await build(files).resolveWriteRosterId(
        'folder-id',
        parentItem: _item(isOwner: true, membersSignedAt: 1736000000),
      );
      expect(resolved, 'folder-id');
      expect(files.fetches, 0);
    });

    test('a held own never-shared folder stays owner-only', () async {
      final files = _FakeFilesClient({});
      final resolved = await build(files).resolveWriteRosterId(
        'folder-id',
        parentItem: _item(isOwner: true, parentId: null),
      );
      expect(resolved, isNull);
      expect(files.fetches, 0);
    });

    test('a folder below the share root resolves to the root', () async {
      // leaf -> mid -> root, only the root carries a signed list. The walk
      // pays one fetch per unsigned level plus the root.
      final files = _FakeFilesClient({
        'leaf': _meta(id: 'leaf', parentId: 'mid', isOwner: true),
        'mid': _meta(id: 'mid', parentId: 'root', isOwner: true),
        'root': _meta(id: 'root', isOwner: true, membersSignedAt: 1736000000),
      });
      expect(await build(files).resolveWriteRosterId('leaf'), 'root');
      expect(files.fetches, 3);
    });

    test(
      'a recipient folder with no signed chain falls back to itself',
      () async {
        // A pre-signature legacy share: the write keeps today's verification
        // error instead of silently landing owner-only.
        final files = _FakeFilesClient({
          'legacy': _meta(id: 'legacy', parentId: null, isOwner: false),
        });
        expect(await build(files).resolveWriteRosterId('legacy'), 'legacy');
      },
    );

    test('a non-folder is never a multi-key target', () async {
      final files = _FakeFilesClient({});
      expect(
        await build(files).resolveWriteRosterId(
          'note-id',
          parentItem: _item(isOwner: false, mime: 'text/markdown'),
        ),
        isNull,
      );
    });

    test('an unreadable chain propagates instead of guessing', () async {
      final files = _FakeFilesClient({
        'leaf': _meta(id: 'leaf', parentId: 'gone', isOwner: true),
      });
      expect(
        () => build(files).resolveWriteRosterId('leaf'),
        throwsA(isA<StateError>()),
      );
    });

    test('a parent-pointer cycle terminates as not shared', () async {
      final files = _FakeFilesClient({
        'a': _meta(id: 'a', parentId: 'b', isOwner: true),
        'b': _meta(id: 'b', parentId: 'a', isOwner: true),
      });
      expect(await build(files).resolveWriteRosterId('a'), isNull);
    });
  });
}
