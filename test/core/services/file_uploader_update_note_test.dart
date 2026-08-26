import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/chunk_urls_models.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/services/file_uploader.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

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
  bool forceSeen = false;
  int conflictRemaining = 0;
  Completer<void>? hold;
  final List<bool> forceFlags = [];

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
    if (force) forceSeen = true;
    if (conflictRemaining > 0) {
      conflictRemaining -= 1;
      throw DioException(
        requestOptions: RequestOptions(path: '/api/storage/$fileId/content'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/storage/$fileId/content'),
          statusCode: 409,
          data: const {
            'message': 'another_edit_is_in_progress',
            'context': null,
          },
        ),
        type: DioExceptionType.badResponse,
      );
    }
    inFlight += 1;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    final held = hold;
    if (held != null) await held.future;
    inFlight -= 1;
    return {};
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
  setUpAll(() async => await RustLib.init());

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
  build() {
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
    );
    return (uploader: uploader, files: files, storage: storage, auth: auth);
  }

  test(
    'two overlapping saves issue one replaceContent and one upload',
    () async {
      final built = build();
      built.storage.hold = Completer<void>();

      final first = built.uploader.updateNoteContent(fileId, 'first body');
      final second = built.uploader.updateNoteContent(fileId, 'second body');
      // Let both callers enter the serializer before the PUT proceeds.
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (built.storage.replaceCalls == 0) {
        if (DateTime.now().isAfter(deadline)) {
          fail('replaceContent was never entered');
        }
        await Future<void>.delayed(Duration.zero);
      }
      expect(built.storage.replaceCalls, 1);
      built.storage.hold!.complete();
      await Future.wait([first, second]);

      expect(built.storage.replaceCalls, 1);
      expect(built.storage.maxInFlight, 1);
      expect(built.files.chunkFileIds, hasLength(1));
      expect(built.auth.tokenCalls, 1);
    },
  );

  test('409 another_edit_is_in_progress becomes SaveConflictException '
      'and does not start the encrypt upload', () async {
    final built = build();
    built.storage.conflictRemaining = 1;

    await expectLater(
      built.uploader.updateNoteContent(fileId, 'body'),
      throwsA(isA<SaveConflictException>()),
    );
    expect(built.files.chunkFileIds, isEmpty);
    expect(built.auth.tokenCalls, 0);
    expect(built.files.hashedFileId, isNull);
  });

  test('overwrite after a failed save completes the encrypt upload', () async {
    final built = build();
    built.storage.conflictRemaining = 1;

    await expectLater(
      built.uploader.updateNoteContent(fileId, 'body'),
      throwsA(isA<SaveConflictException>()),
    );
    expect(built.files.chunkFileIds, isEmpty);

    await built.uploader.updateNoteContent(fileId, 'body', force: true);

    expect(built.storage.forceSeen, isTrue);
    expect(built.storage.forceFlags.last, isTrue);
    expect(built.files.chunkFileIds, hasLength(1));
    expect(built.auth.tokenCalls, 1);
    expect(built.files.hashedFileId, fileId);
  });
}
