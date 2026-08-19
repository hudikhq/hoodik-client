import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/chunk_urls_models.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/services/file_operations.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

/// Records the `encrypted_key` the owner-only create/upload paths post so a
/// test can round-trip it back through the account's own key.
class _CapturingFilesClient extends Fake implements FilesClient {
  String? dirEncryptedKey;
  String? fileEncryptedKey;

  /// This suite is about key wrapping, not transport. Answering "no URLs"
  /// keeps the note on the relaying route, which is what a local-disk
  /// deployment does and what these assertions were written against.
  @override
  Future<ChunkUrlsResponse?> fetchUploadUrls({
    required String fileId,
    required String transferToken,
    required Map<int, int> chunkSizes,
  }) async => null;

  @override
  Future<Map<String, dynamic>> createDirectory({
    required String encryptedKey,
    required String nameHash,
    required String encryptedName,
    String? parentDirId,
    String? cipher,
    List<String>? searchTokensRoot,
    List<String>? searchTokensFile,
  }) async {
    dirEncryptedKey = encryptedKey;
    return {'id': 'dir-id'};
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
    fileEncryptedKey = encryptedKey;
    return {'id': 'file-id'};
  }

  @override
  Future<Map<String, dynamic>> uploadChunk({
    required String fileId,
    required int chunk,
    required Uint8List data,
    String? checksum,
    String? checksumFunction,
  }) async => {};

  @override
  Future<void> updateFileHashesWithToken({
    required String fileId,
    required String transferToken,
    required String sha256,
    String? md5,
    String? sha1,
    String? blake2b,
  }) async {}
}

class _FakeAuthClient extends Fake implements AuthClient {
  @override
  Future<TransferToken> requestTransferToken({
    required String fileId,
    required String action,
  }) async =>
      TransferToken(token: 't', expiresAt: 0, fileId: fileId, action: action);
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._files);

  final FilesClient _files;
  final AuthClient _auth = _FakeAuthClient();

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

  const crypto = CryptoService();
  late _CapturingFilesClient files;

  setUp(() => files = _CapturingFilesClient());

  FileOperations build({
    required String privateKeyPem,
    required String publicKeyPem,
    String? wrappingPrivateKeyPem,
    String? wrappingPublicKeyPem,
  }) => FileOperations(
    client: _FakeApiClient(files),
    privateKeyPem: privateKeyPem,
    publicKeyPem: publicKeyPem,
    wrappingPrivateKeyPem: wrappingPrivateKeyPem,
    wrappingPublicKeyPem: wrappingPublicKeyPem,
    crypto: crypto,
  );

  group('curve25519 account', () {
    late FileOperations ops;
    late ({String privatePem, String publicPem}) wrapping;

    setUp(() {
      final identity = crypto.generateEd25519KeyPair();
      final x = crypto.generateWrappingKeyPair();
      wrapping = (privatePem: x.privatePem, publicPem: x.publicPem);
      ops = build(
        privateKeyPem: identity.privatePem,
        publicKeyPem: identity.publicPem,
        wrappingPrivateKeyPem: x.privatePem,
        wrappingPublicKeyPem: x.publicPem,
      );
    });

    test(
      'createFolder wraps the folder key to the hybrid wrapping key and round-trips',
      () async {
        await ops.createFolder('docs');
        final wrap = files.dirEncryptedKey!;

        // The wrap is a hybrid wrap blob, not RSA ciphertext: the wrapping
        // private key recovers the generated folder key, and the ops decrypt
        // path agrees. Before the fix createFolder threw here (RSA branch fed the
        // Ed25519 identity PEM).
        final original = crypto.wrappingUnwrap(
          blob: wrap,
          privatePem: wrapping.privatePem,
        );
        expect(ops.decryptFileKey(wrap), equals(original));
      },
    );

    test(
      'createNote wraps the note key to the hybrid wrapping key and round-trips',
      () async {
        await ops.createNote('note.md', '# hello');
        final wrap = files.fileEncryptedKey!;

        final original = crypto.wrappingUnwrap(
          blob: wrap,
          privatePem: wrapping.privatePem,
        );
        expect(ops.decryptFileKey(wrap), equals(original));
      },
    );
  });

  group('legacy RSA account', () {
    late FileOperations ops;
    late rust.RsaKeyPair kp;

    setUp(() {
      kp = rust.generateRsaKeypair();
      ops = build(
        privateKeyPem: kp.privateKeyPem,
        publicKeyPem: kp.publicKeyPem,
      );
    });

    test('createFolder still wraps with RSA and round-trips', () async {
      await ops.createFolder('docs');
      final wrap = files.dirEncryptedKey!;

      // RSA path is byte-identical to before: the plaintext is the hex-encoded
      // key, and a hybrid unwrap can't touch it.
      final original = crypto.hexDecode(
        crypto.rsaDecrypt(
          ciphertextBase64: wrap,
          privateKeyPem: kp.privateKeyPem,
        ),
      );
      expect(ops.decryptFileKey(wrap), equals(original));
      final stray = crypto.generateWrappingKeyPair();
      expect(
        () => crypto.wrappingUnwrap(blob: wrap, privatePem: stray.privatePem),
        throwsA(anything),
      );
    });

    test('createNote still wraps with RSA and round-trips', () async {
      await ops.createNote('note.md', '# hello');
      final wrap = files.fileEncryptedKey!;

      final original = crypto.hexDecode(
        crypto.rsaDecrypt(
          ciphertextBase64: wrap,
          privateKeyPem: kp.privateKeyPem,
        ),
      );
      expect(ops.decryptFileKey(wrap), equals(original));
    });
  });
}
