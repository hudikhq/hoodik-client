import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/chunk_urls_models.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/services/file_uploader.dart';
import 'package:hoodik_app/core/workers/worker_manager.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../../helpers/test_workers.dart';

class _FakeAuthClient extends Fake implements AuthClient {
  int tokenCalls = 0;
  @override
  Future<TransferToken> requestTransferToken({
    required String fileId,
    required String action,
  }) async {
    tokenCalls += 1;
    return TransferToken(
      token: 'token',
      expiresAt: 0,
      fileId: fileId,
      action: action,
    );
  }
}

class _NoteFilesClient extends Fake implements FilesClient {
  late Map<String, dynamic> metadata;
  final List<String> chunkFileIds = [];
  final List<Uint8List> chunkData = [];
  String? hashedFileId;
  List<String> uploadUrls = const [];

  @override
  Future<Map<String, dynamic>> getFileMetadata(String fileId) async => metadata;

  @override
  Future<ChunkUrlsResponse?> fetchUploadUrls({
    required String fileId,
    required String transferToken,
    required Map<int, int> chunkSizes,
  }) async {
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
  }) async {}

  @override
  Future<void> finalizeDirectUpload({
    required String fileId,
    required String transferToken,
  }) async {}

  @override
  Future<Map<String, dynamic>> uploadChunk({
    required String fileId,
    required int chunk,
    required Uint8List data,
    String? checksum,
    String? checksumFunction,
  }) async {
    chunkFileIds.add(fileId);
    chunkData.add(data);
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
    List<String>? searchTokensRoot,
    List<String>? searchTokensFile,
  }) async {
    hashedFileId = fileId;
  }
}

class _NoteStorageClient extends Fake implements StorageClient {
  int replaceCalls = 0;
  int inFlight = 0;
  int maxInFlight = 0;
  int conflictRemaining = 0;

  /// Awaited on entry, before the conflict check — lets a test park the
  /// first save inside replaceContent while more saves queue behind it.
  Completer<void>? gate;
  final List<bool> forceFlags = [];
  final List<List<String>?> rootTokens = [];
  final List<List<String>?> fileTokens = [];

  @override
  Future<Map<String, dynamic>> replaceContent({
    required String fileId,
    required int size,
    required int chunks,
    String? encryptedName,
    String? encryptedThumbnail,
    List<String>? searchTokensRoot,
    List<String>? searchTokensFile,
    bool force = false,
  }) async {
    replaceCalls += 1;
    forceFlags.add(force);
    rootTokens.add(searchTokensRoot);
    fileTokens.add(searchTokensFile);
    inFlight += 1;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      final held = gate;
      if (held != null) await held.future;
      if (conflictRemaining > 0) {
        conflictRemaining -= 1;
        throw DioException(
          requestOptions: RequestOptions(path: '/api/storage/$fileId/content'),
          response: Response(
            requestOptions: RequestOptions(
              path: '/api/storage/$fileId/content',
            ),
            statusCode: 409,
            data: const {
              'message': 'another_edit_is_in_progress',
              'context': null,
            },
          ),
          type: DioExceptionType.badResponse,
        );
      }
      return {};
    } finally {
      inFlight -= 1;
    }
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._files, this._auth, this._storage);
  final FilesClient _files;
  final AuthClient _auth;
  final StorageClient _storage;
  @override
  FilesClient get files => _files;
  @override
  AuthClient get auth => _auth;
  @override
  StorageClient get storage => _storage;
  @override
  Future<void> ensureFreshSession() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkerManager workers;
  setUpAll(() async {
    await RustLib.init();
    workers = await startTestWorkers();
  });
  tearDownAll(() => workers.dispose());

  late FileCrypto fileCrypto;
  late String publicKeyPem;
  late Uint8List fileKey;
  late String encryptedKey;
  const fileId = 'note-id';

  setUp(() {
    final kp = rust.generateRsaKeypair();
    fileCrypto = FileCrypto(privateKeyPem: kp.privateKeyPem);
    publicKeyPem = kp.publicKeyPem;
    fileKey = fileCrypto.generateFileKey();
    encryptedKey = fileCrypto.encryptFileKey(
      fileKey: fileKey,
      publicKeyPem: publicKeyPem,
    );
  });

  ({
    FileUploader uploader,
    _NoteFilesClient files,
    _NoteStorageClient storage,
    _FakeAuthClient auth,
  })
  build({bool withWorkers = true}) {
    final files = _NoteFilesClient()
      ..metadata = {
        'id': fileId,
        'encrypted_name': fileCrypto.encryptFileName(
          name: 'note.md',
          fileKey: fileKey,
          cipher: 'aegis128l',
        ),
        'encrypted_key': encryptedKey,
        'mime': 'text/markdown',
        'cipher': 'aegis128l',
        'editable': true,
        'is_owner': true,
        'finished_upload_at': 1,
      };
    final storage = _NoteStorageClient();
    final auth = _FakeAuthClient();
    final uploader = FileUploader(
      client: _FakeApiClient(files, auth, storage),
      fileCrypto: fileCrypto,
      publicKeyPem: publicKeyPem,
      workerManager: withWorkers ? workers : null,
    );
    return (uploader: uploader, files: files, storage: storage, auth: auth);
  }

  String decryptBody(Uint8List chunk) => utf8.decode(
    fileCrypto.decryptChunk(
      data: chunk,
      fileKey: fileKey,
      cipher: 'aegis128l',
      chunkIndex: 0,
    ),
  );

  test(
    'overlapping saves coalesce: never concurrent, newest body wins',
    () async {
      final built = build();
      built.storage.gate = Completer<void>();

      final first = built.uploader.updateNoteContent(fileId, 'first body');
      final second = built.uploader.updateNoteContent(fileId, 'second body');
      final third = built.uploader.updateNoteContent(fileId, 'third body');
      // Let the first save reach the PUT before releasing it.
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (built.storage.replaceCalls == 0) {
        if (DateTime.now().isAfter(deadline)) {
          fail('replaceContent was never entered');
        }
        await Future<void>.delayed(Duration.zero);
      }
      expect(built.storage.replaceCalls, 1);
      built.storage.gate!.complete();
      await Future.wait([first, second, third]);

      // The second and third bodies coalesced into one follow-up save.
      expect(built.storage.replaceCalls, 2);
      expect(built.storage.maxInFlight, 1);
      expect(built.files.chunkFileIds, hasLength(2));
      expect(decryptBody(built.files.chunkData.first), 'first body');
      expect(decryptBody(built.files.chunkData.last), 'third body');

      // Every save carries search tokens for the body it actually wrote —
      // the coalesced save indexes the coalesced text, not the original.
      expect(
        built.storage.fileTokens.last,
        fileCrypto.tokenizeForSearchWithFileKey(fileKey, 'third body'),
      );
      expect(
        built.storage.rootTokens.last,
        fileCrypto.tokenizeForSearch('third body'),
      );
    },
  );

  test('a 409 is retried once with force and the save completes', () async {
    final built = build();
    built.storage.conflictRemaining = 1;

    await built.uploader.updateNoteContent(fileId, 'body');

    expect(built.storage.forceFlags, [false, true]);
    expect(built.files.chunkFileIds, hasLength(1));
    expect(decryptBody(built.files.chunkData.single), 'body');
    expect(built.files.hashedFileId, fileId);
    // The forced retry re-sends the same tokens the first attempt carried.
    final expectedTokens = fileCrypto.tokenizeForSearchWithFileKey(
      fileKey,
      'body',
    );
    expect(built.storage.fileTokens, [expectedTokens, expectedTokens]);
    expect(built.storage.rootTokens.last, isNotEmpty);
  });

  test('a 409 that survives the forced retry becomes SaveConflictException '
      'and does not start the encrypt upload', () async {
    final built = build();
    built.storage.conflictRemaining = 2;

    await expectLater(
      built.uploader.updateNoteContent(fileId, 'body'),
      throwsA(isA<SaveConflictException>()),
    );
    expect(built.storage.forceFlags, [false, true]);
    expect(built.files.chunkFileIds, isEmpty);
    expect(built.auth.tokenCalls, 0);
    expect(built.files.hashedFileId, isNull);
  });

  test('a failed save does not drop the body queued behind it', () async {
    final built = build();
    built.storage.gate = Completer<void>();
    built.storage.conflictRemaining = 2;

    final first = built.uploader.updateNoteContent(fileId, 'doomed body');
    final second = built.uploader.updateNoteContent(fileId, 'queued body');
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (built.storage.replaceCalls == 0) {
      if (DateTime.now().isAfter(deadline)) {
        fail('replaceContent was never entered');
      }
      await Future<void>.delayed(Duration.zero);
    }
    built.storage.gate!.complete();

    await expectLater(first, throwsA(isA<SaveConflictException>()));
    await second;

    expect(built.storage.forceFlags, [false, true, false]);
    expect(built.files.chunkFileIds, hasLength(1));
    expect(decryptBody(built.files.chunkData.single), 'queued body');
  });

  test('an explicit force save takes over on the first attempt', () async {
    final built = build();

    await built.uploader.updateNoteContent(fileId, 'body', force: true);

    expect(built.storage.forceFlags, [true]);
    expect(built.files.chunkFileIds, hasLength(1));
    expect(built.auth.tokenCalls, 1);
    expect(built.files.hashedFileId, fileId);
  });

  test('a save without a live encrypt worker fails instead of encrypting '
      'in-process', () async {
    final built = build(withWorkers: false);

    await expectLater(
      built.uploader.updateNoteContent(fileId, 'body'),
      throwsA(isA<Exception>()),
    );
    // Failing fast matters: a PUT would allocate a pending version the
    // dead encrypt path could never finish.
    expect(built.storage.replaceCalls, 0);
    expect(built.files.chunkFileIds, isEmpty);
  });
}
