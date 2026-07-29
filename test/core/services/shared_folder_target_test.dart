import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_models.dart';
import 'package:hoodik_app/core/api/files_client.dart';
import 'package:hoodik_app/core/services/shared_folder_target.dart';

/// Returns a scripted metadata map and counts fetches so a test can assert the
/// resolver short-circuits (root, held item, capability off) without a network
/// round-trip.
class _FakeFilesClient extends Fake implements FilesClient {
  _FakeFilesClient(this.meta);

  final Map<String, dynamic> meta;
  int fetches = 0;

  @override
  Future<Map<String, dynamic>> getFileMetadata(String fileId) async {
    fetches += 1;
    return meta;
  }
}

Map<String, dynamic> _meta({
  required bool isOwner,
  int? membersSignedAt,
  String mime = 'dir',
}) => {
  'id': 'folder-id',
  'mime': mime,
  'is_owner': isOwner,
  'members_signed_at': membersSignedAt,
};

FileItem _item({
  required bool isOwner,
  int? membersSignedAt,
  String mime = 'dir',
}) => FileItem.fromJson(
  _meta(isOwner: isOwner, membersSignedAt: membersSignedAt, mime: mime),
);

void main() {
  group('isMultiKeyTarget', () {
    test('a folder shared with the caller is a multi-key target', () {
      expect(
        SharedFolderTargetResolver.isMultiKeyTarget(_item(isOwner: false)),
        isTrue,
      );
    });

    test('an owned folder the caller has shared is a multi-key target', () {
      expect(
        SharedFolderTargetResolver.isMultiKeyTarget(
          _item(isOwner: true, membersSignedAt: 1736000000),
        ),
        isTrue,
      );
    });

    test('the caller\'s own never-shared folder is not a target', () {
      expect(
        SharedFolderTargetResolver.isMultiKeyTarget(_item(isOwner: true)),
        isFalse,
      );
    });

    test('a non-folder is never a target, even when shared', () {
      expect(
        SharedFolderTargetResolver.isMultiKeyTarget(
          _item(isOwner: false, mime: 'text/markdown'),
        ),
        isFalse,
      );
    });
  });

  group('isSharedDestination', () {
    SharedFolderTargetResolver build(
      _FakeFilesClient files, {
      bool sharingEnabled = true,
    }) => SharedFolderTargetResolver(
      files: files,
      sharingEnabled: sharingEnabled,
    );

    test('the account root is never shared and is not fetched', () async {
      final files = _FakeFilesClient(_meta(isOwner: false));
      expect(await build(files).isSharedDestination(null), isFalse);
      expect(files.fetches, 0);
    });

    test('a held shared item routes multi-key without a fetch', () async {
      final files = _FakeFilesClient(_meta(isOwner: true));
      final shared = await build(
        files,
      ).isSharedDestination('folder-id', parentItem: _item(isOwner: false));
      expect(shared, isTrue);
      expect(files.fetches, 0);
    });

    test('a held own folder stays owner-only without a fetch', () async {
      final files = _FakeFilesClient(_meta(isOwner: false));
      final shared = await build(
        files,
      ).isSharedDestination('folder-id', parentItem: _item(isOwner: true));
      expect(shared, isFalse);
      expect(files.fetches, 0);
    });

    test(
      'sharing off (kill-switch or old server) never engages multi-key',
      () async {
        final files = _FakeFilesClient(_meta(isOwner: false));
        final resolver = build(files, sharingEnabled: false);
        // Neither the fetch path nor a held shared item routes multi-key when
        // the server has sharing switched off.
        expect(await resolver.isSharedDestination('folder-id'), isFalse);
        expect(
          await resolver.isSharedDestination(
            'folder-id',
            parentItem: _item(isOwner: false),
          ),
          isFalse,
        );
        expect(files.fetches, 0);
      },
    );

    test('a fetched folder shared with the caller routes multi-key', () async {
      final files = _FakeFilesClient(_meta(isOwner: false));
      expect(await build(files).isSharedDestination('folder-id'), isTrue);
      expect(files.fetches, 1);
    });

    test('a fetched owned-and-shared folder routes multi-key', () async {
      final files = _FakeFilesClient(
        _meta(isOwner: true, membersSignedAt: 1736000000),
      );
      expect(await build(files).isSharedDestination('folder-id'), isTrue);
      expect(files.fetches, 1);
    });

    test('a fetched own never-shared folder stays owner-only', () async {
      final files = _FakeFilesClient(_meta(isOwner: true));
      expect(await build(files).isSharedDestination('folder-id'), isFalse);
      expect(files.fetches, 1);
    });
  });
}
