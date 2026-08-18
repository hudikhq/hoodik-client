import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/services/binary_upload_metadata.dart';
import 'package:hoodik_app/core/services/shared_folder_target.dart';
import 'package:hoodik_app/core/services/shared_folder_upload.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

/// Scripts the share-status decision so the routing branch is exercised
/// without a network fetch, and records the id it was asked about.
class _FakeResolver extends Fake implements SharedFolderTargetResolver {
  _FakeResolver(this.shared);

  final bool shared;
  String? sawParentDirId;

  @override
  Future<bool> isSharedDestination(
    String? parentDirId, {
    FileItem? parentItem,
  }) async {
    sawParentDirId = parentDirId;
    return shared;
  }
}

/// Captures the multi-key call and echoes the minted id back like the server.
class _MockSharedFolderUpload extends Fake implements SharedFolderUpload {
  int calls = 0;
  late String folderId;
  late String newFileId;
  late Uint8List fileKey;
  late String mime;
  late int chunks;
  int? size;
  String? sha256;
  String? encryptedThumbnail;

  @override
  Future<String> uploadIntoSharedFolder({
    required String folderId,
    required String newFileId,
    required Uint8List fileKey,
    required String nameHash,
    required String encryptedName,
    required String mime,
    required int chunks,
    int? size,
    String? sha256,
    String? cipher,
    bool? editable,
    List<String>? searchTokensRoot,
    List<String>? searchTokensFile,
    String? encryptedThumbnail,
    int? fileModifiedAt,
  }) async {
    calls += 1;
    this.folderId = folderId;
    this.newFileId = newFileId;
    this.fileKey = fileKey;
    this.mime = mime;
    this.chunks = chunks;
    this.size = size;
    this.sha256 = sha256;
    this.encryptedThumbnail = encryptedThumbnail;
    return newFileId;
  }
}

class _CapturingFilesClient extends Fake implements FilesClient {
  int calls = 0;
  Map<String, dynamic>? captured;

  @override
  Future<Map<String, dynamic>> createFileEntry({
    required String encryptedKey,
    required String nameHash,
    required String encryptedName,
    required String mime,
    required int size,
    required int chunks,
    String? parentDirId,
    String? cipher,
    String? encryptedThumbnail,
    List<String>? searchTokensRoot,
    List<String>? searchTokensFile,
    String? fileModifiedAt,
    String? sha256,
    bool? editable,
  }) async {
    calls += 1;
    captured = {
      'encrypted_key': encryptedKey,
      'mime': mime,
      'size': size,
      'chunks': chunks,
      'parent_dir_id': parentDirId,
      'sha256': sha256,
    };
    return {'id': 'owner-only-id'};
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._files);
  final FilesClient _files;
  @override
  FilesClient get files => _files;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late FileCrypto fileCrypto;
  late String publicKeyPem;
  final fileKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

  setUp(() {
    final kp = rust.generateRsaKeypair();
    fileCrypto = FileCrypto(privateKeyPem: kp.privateKeyPem);
    publicKeyPem = kp.publicKeyPem;
  });

  Future<Map<String, dynamic>> run(
    BinaryUploadMetadata metadata, {
    String? parentDirId = 'folder-id',
  }) {
    return metadata.createEntry(
      fileName: 'photo.bin',
      fileSize: 4096,
      totalChunks: 3,
      mime: 'application/octet-stream',
      cipher: 'aegis128l',
      fileKey: fileKey,
      nameHash: 'name-hash',
      parentDirId: parentDirId,
      localPath: '/tmp/photo.bin',
      sha256: 'deadbeef',
    );
  }

  test('a shared destination routes through the multi-key upload', () async {
    final upload = _MockSharedFolderUpload();
    final files = _CapturingFilesClient();
    final metadata = BinaryUploadMetadata(
      client: _FakeApiClient(files),
      fileCrypto: fileCrypto,
      publicKeyPem: publicKeyPem,
      sharedTarget: _FakeResolver(true),
      sharedUpload: upload,
    );

    final entry = await run(metadata);

    expect(upload.calls, 1);
    expect(files.calls, 0, reason: 'owner-only create must not run');
    expect(upload.folderId, 'folder-id');
    expect(upload.fileKey, fileKey);
    expect(upload.mime, 'application/octet-stream');
    expect(upload.chunks, 3);
    expect(upload.size, 4096);
    expect(upload.sha256, 'deadbeef');
    expect(entry['id'], upload.newFileId);
    expect(entry['id'], isNotEmpty);
  });

  test('a non-shared destination takes the owner-only create', () async {
    final upload = _MockSharedFolderUpload();
    final files = _CapturingFilesClient();
    final metadata = BinaryUploadMetadata(
      client: _FakeApiClient(files),
      fileCrypto: fileCrypto,
      publicKeyPem: publicKeyPem,
      sharedTarget: _FakeResolver(false),
      sharedUpload: upload,
    );

    final entry = await run(metadata);

    expect(upload.calls, 0);
    expect(files.calls, 1);
    expect(files.captured!['parent_dir_id'], 'folder-id');
    expect(files.captured!['mime'], 'application/octet-stream');
    expect(files.captured!['chunks'], 3);
    expect(files.captured!['sha256'], 'deadbeef');
    expect((files.captured!['encrypted_key'] as String), isNotEmpty);
    expect(entry['id'], 'owner-only-id');
  });

  test('a shared destination with no upload service fails clearly', () async {
    final files = _CapturingFilesClient();
    final metadata = BinaryUploadMetadata(
      client: _FakeApiClient(files),
      fileCrypto: fileCrypto,
      publicKeyPem: publicKeyPem,
      sharedTarget: _FakeResolver(true),
      sharedUpload: null,
    );

    await expectLater(
      run(metadata),
      throwsA(isA<SharingUnavailableException>()),
    );
    expect(files.calls, 0);
  });

  test('a null resolver always takes the owner-only path', () async {
    final files = _CapturingFilesClient();
    final metadata = BinaryUploadMetadata(
      client: _FakeApiClient(files),
      fileCrypto: fileCrypto,
      publicKeyPem: publicKeyPem,
    );

    final entry = await run(metadata);

    expect(files.calls, 1);
    expect(entry['id'], 'owner-only-id');
  });
}
