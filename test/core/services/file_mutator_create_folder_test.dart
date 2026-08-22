import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/services/file_mutator.dart';
import 'package:hoodik_app/core/services/shared_folder_target.dart';
import 'package:hoodik_app/core/services/shared_folder_upload.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

class _FakeResolver extends Fake implements SharedFolderTargetResolver {
  _FakeResolver(this.shared);
  final bool shared;
  @override
  Future<bool> isSharedDestination(
    String? parentDirId, {
    FileItem? parentItem,
  }) async => shared;
}

class _MockSharedFolderUpload extends Fake implements SharedFolderUpload {
  int calls = 0;
  String? mime;
  int? chunks;

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
    List<String>? digestTokensRoot,
    List<String>? digestTokensFile,
    String? encryptedThumbnail,
    int? fileModifiedAt,
  }) async {
    calls += 1;
    this.mime = mime;
    this.chunks = chunks;
    return newFileId;
  }
}

class _DirFilesClient extends Fake implements FilesClient {
  int createCalls = 0;
  String? parentDirId;
  String? cipher;

  @override
  Future<Map<String, dynamic>> createDirectory({
    required String encryptedKey,
    required String nameHash,
    required String encryptedName,
    String? parentDirId,
    String? cipher,
    List<String>? searchTokensRoot,
    List<String>? searchTokensFile,
    List<String>? digestTokensRoot,
    List<String>? digestTokensFile,
  }) async {
    createCalls += 1;
    this.parentDirId = parentDirId;
    this.cipher = cipher;
    return {'id': 'owner-dir-id'};
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

  setUp(() {
    final kp = rust.generateRsaKeypair();
    fileCrypto = FileCrypto(privateKeyPem: kp.privateKeyPem);
    publicKeyPem = kp.publicKeyPem;
  });

  FileMutator build({
    required _DirFilesClient files,
    required bool shared,
    SharedFolderUpload? upload,
    String defaultCipher = 'aegis128l',
  }) => FileMutator(
    client: _FakeApiClient(files),
    fileCrypto: fileCrypto,
    publicKeyPem: publicKeyPem,
    defaultCipher: defaultCipher,
    sharedTarget: _FakeResolver(shared),
    sharedUpload: upload,
  );

  test(
    'a sub-folder in a shared folder is created multi-key as a dir',
    () async {
      final files = _DirFilesClient();
      final upload = _MockSharedFolderUpload();
      await build(
        files: files,
        shared: true,
        upload: upload,
      ).createFolder('sub', parentDirId: 'folder-id');

      expect(upload.calls, 1);
      expect(upload.mime, 'dir');
      expect(upload.chunks, 0);
      expect(files.createCalls, 0, reason: 'owner-only create must not run');
    },
  );

  test('a folder in an owned location takes the owner-only create', () async {
    final files = _DirFilesClient();
    final upload = _MockSharedFolderUpload();
    await build(
      files: files,
      shared: false,
      upload: upload,
    ).createFolder('sub', parentDirId: 'folder-id');

    expect(upload.calls, 0);
    expect(files.createCalls, 1);
    expect(files.parentDirId, 'folder-id');
    expect(files.cipher, 'aegis128l');
  });

  test('a folder is keyed with the injected default cipher', () async {
    final files = _DirFilesClient();
    await build(
      files: files,
      shared: false,
      defaultCipher: 'aegis256',
    ).createFolder('sub', parentDirId: 'folder-id');

    expect(files.cipher, 'aegis256');
  });

  test('a shared folder with no upload service fails clearly', () async {
    final files = _DirFilesClient();
    await expectLater(
      build(
        files: files,
        shared: true,
        upload: null,
      ).createFolder('sub', parentDirId: 'folder-id'),
      throwsA(isA<SharingUnavailableException>()),
    );
    expect(files.createCalls, 0);
  });
}
