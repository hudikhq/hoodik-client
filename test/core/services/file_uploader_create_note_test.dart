import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/chunk_urls_models.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/services/file_uploader.dart';
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
  late String newFileId;
  String? mime;
  String? cipher;
  bool? editable;
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
    String? encryptedThumbnail,
    int? fileModifiedAt,
  }) async {
    calls += 1;
    this.newFileId = newFileId;
    this.mime = mime;
    this.cipher = cipher;
    this.editable = editable;
    this.chunks = chunks;
    return newFileId;
  }
}

class _FakeAuthClient extends Fake implements AuthClient {
  @override
  Future<TransferToken> requestTransferToken({
    required String fileId,
    required String action,
  }) async => TransferToken(
    token: 'token',
    expiresAt: 0,
    fileId: fileId,
    action: action,
  );
}

class _NoteFilesClient extends Fake implements FilesClient {
  int createCalls = 0;
  bool? createdEditable;
  String? createdMime;
  String? createdCipher;
  List<String>? createdTokensRoot;
  List<String>? createdTokensFile;
  final List<String> chunkFileIds = [];
  String? hashedFileId;

  /// URLs to hand back when asked for an upload manifest. Empty means the
  /// server will not sign them, which is every local-disk deployment — and
  /// the reason the relaying route below still has to work.
  List<String> uploadUrls = const [];
  Map<int, int>? declaredSizes;
  final List<String> directPuts = [];
  String? finalizedFileId;

  @override
  Future<ChunkUrlsResponse?> fetchUploadUrls({
    required String fileId,
    required String transferToken,
    required Map<int, int> chunkSizes,
  }) async {
    declaredSizes = chunkSizes;
    if (uploadUrls.isEmpty) return null;
    return ChunkUrlsResponse(
      urls: uploadUrls,
      expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    );
  }

  @override
  Future<void> putChunkDirect({
    required String url,
    required Uint8List data,
  }) async {
    directPuts.add(url);
  }

  @override
  Future<void> finalizeDirectUpload({
    required String fileId,
    required String transferToken,
  }) async {
    finalizedFileId = fileId;
  }

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
    createCalls += 1;
    createdEditable = editable;
    createdMime = mime;
    createdCipher = cipher;
    createdTokensRoot = searchTokensRoot;
    createdTokensFile = searchTokensFile;
    return {'id': 'owner-note-id'};
  }

  @override
  Future<Map<String, dynamic>> uploadChunk({
    required String fileId,
    required int chunk,
    required Uint8List data,
    String? checksum,
    String? checksumFunction,
  }) async {
    chunkFileIds.add(fileId);
    return {};
  }

  @override
  Future<void> updateFileHashesWithToken({
    required String fileId,
    required String transferToken,
    required String sha256,
    String? md5,
    String? sha1,
    String? blake2b,
  }) async {
    hashedFileId = fileId;
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._files, this._auth);
  final FilesClient _files;
  final AuthClient _auth;
  @override
  FilesClient get files => _files;
  @override
  AuthClient get auth => _auth;
  @override
  Future<void> ensureFreshSession() async {}
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

  FileUploader build({
    required _NoteFilesClient files,
    required bool shared,
    SharedFolderUpload? upload,
    String defaultCipher = 'aegis128l',
  }) => FileUploader(
    client: _FakeApiClient(files, _FakeAuthClient()),
    fileCrypto: fileCrypto,
    publicKeyPem: publicKeyPem,
    defaultCipher: defaultCipher,
    sharedTarget: _FakeResolver(shared),
    sharedUpload: upload,
  );

  test('a note in a shared folder is created multi-key and chunks target '
      'the minted id', () async {
    final files = _NoteFilesClient();
    final upload = _MockSharedFolderUpload();
    final uploader = build(files: files, shared: true, upload: upload);

    final id = await uploader.createNote(
      'note.md',
      '# Hi\n',
      parentDirId: 'folder-id',
    );

    expect(upload.calls, 1);
    expect(upload.mime, 'text/markdown');
    expect(upload.editable, isTrue);
    expect(files.createCalls, 0, reason: 'owner-only create must not run');
    expect(id, upload.newFileId);
    expect(files.chunkFileIds, isNotEmpty);
    expect(files.chunkFileIds.every((f) => f == upload.newFileId), isTrue);
    expect(files.hashedFileId, upload.newFileId);
  });

  test('a note in an owned folder takes the owner-only create', () async {
    final files = _NoteFilesClient();
    final upload = _MockSharedFolderUpload();
    final uploader = build(files: files, shared: false, upload: upload);

    final id = await uploader.createNote(
      'note.md',
      '# Hi\n',
      parentDirId: 'folder-id',
    );

    expect(upload.calls, 0);
    expect(files.createCalls, 1);
    expect(files.createdEditable, isTrue);
    expect(files.createdMime, 'text/markdown');
    expect(files.createdCipher, 'aegis128l');
    expect(id, 'owner-note-id');
    expect(files.chunkFileIds.every((f) => f == 'owner-note-id'), isTrue);
  });

  test('a note is encrypted with the injected default cipher', () async {
    final files = _NoteFilesClient();
    final upload = _MockSharedFolderUpload();
    final uploader = build(
      files: files,
      shared: false,
      upload: upload,
      defaultCipher: 'aegis256',
    );

    await uploader.createNote('note.md', '# Hi\n', parentDirId: 'folder-id');

    expect(files.createdCipher, 'aegis256');
  });

  test('a shared note carries the injected default cipher', () async {
    final files = _NoteFilesClient();
    final upload = _MockSharedFolderUpload();
    final uploader = build(
      files: files,
      shared: true,
      upload: upload,
      defaultCipher: 'aegis256',
    );

    await uploader.createNote('note.md', '# Hi\n', parentDirId: 'folder-id');

    expect(upload.cipher, 'aegis256');
  });

  test('a shared folder with no upload service fails clearly', () async {
    final files = _NoteFilesClient();
    final uploader = build(files: files, shared: true, upload: null);

    await expectLater(
      uploader.createNote('note.md', '# Hi\n', parentDirId: 'folder-id'),
      throwsA(isA<SharingUnavailableException>()),
    );
    expect(files.createCalls, 0);
    expect(files.chunkFileIds, isEmpty);
  });

  // Saving a note was the last write in the app still going through the
  // server. Everything else had moved to the bucket, and this one kept
  // relaying because it predates the manifest and nobody had looked at it.
  group('note content reaches the bucket', () {
    test(
      'chunks are written straight to the bucket and then committed',
      () async {
        final files = _NoteFilesClient()
          ..uploadUrls = const ['https://bucket.example.com/obj/000000.chunk'];
        final uploader = build(
          files: files,
          shared: false,
          upload: _MockSharedFolderUpload(),
        );

        await uploader.createNote(
          'note.md',
          '# Hi\n',
          parentDirId: 'folder-id',
        );

        expect(files.directPuts, hasLength(1));
        expect(
          files.chunkFileIds,
          isEmpty,
          reason: 'nothing should have relayed',
        );
        expect(
          files.finalizedFileId,
          'owner-note-id',
          reason:
              'a bucket write tells the server nothing until the client does',
        );
      },
    );

    // The server signs each chunk's exact ciphertext length into its URL, so a
    // declared plaintext length would have the bucket reject every chunk.
    test(
      'the declared size is the ciphertext length, not the plaintext one',
      () async {
        final files = _NoteFilesClient()
          ..uploadUrls = const ['https://bucket.example.com/obj/000000.chunk'];
        final uploader = build(
          files: files,
          shared: false,
          upload: _MockSharedFolderUpload(),
        );

        const body = '# Hi\n';
        await uploader.createNote('note.md', body, parentDirId: 'folder-id');

        expect(files.declaredSizes, isNotNull);
        expect(
          files.declaredSizes![0],
          greaterThan(body.length),
          reason: 'every chunk carries its AEAD tag on top of the payload',
        );
      },
    );

    test('a new note is indexed by its body, not just its title', () async {
      final files = _NoteFilesClient();
      final uploader = build(
        files: files,
        shared: false,
        upload: _MockSharedFolderUpload(),
      );

      // The word appears only in the body. Indexing the title alone left it
      // unsearchable until something happened to re-index the note.
      await uploader.createNote(
        'note.md',
        '# Renewal\nThe insurance policy renews in March.\n',
        parentDirId: 'folder-id',
      );

      final expected = fileCrypto
          .tokenizeForSearch('insurance')
          .map((e) => e.split(':').first)
          .toSet();

      final written = files.createdTokensRoot!
          .map((e) => e.split(':').first)
          .toSet();

      expect(expected, isNotEmpty);
      expect(written, containsAll(expected));
      expect(files.createdTokensFile, isNotEmpty);
    });

    test('a server that will not sign the URLs still gets the note', () async {
      final files = _NoteFilesClient();
      final uploader = build(
        files: files,
        shared: false,
        upload: _MockSharedFolderUpload(),
      );

      await uploader.createNote('note.md', '# Hi\n', parentDirId: 'folder-id');

      expect(files.directPuts, isEmpty);
      expect(files.chunkFileIds, isNotEmpty);
      expect(
        files.finalizedFileId,
        isNull,
        reason: 'the relaying route commits itself as its last chunk lands',
      );
    });
  });
}
