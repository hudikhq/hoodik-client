import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/services/file_downloader.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/files/providers/files_notifier.dart';
import 'package:hoodik_app/features/files/providers/files_state.dart';

/// Shared fakes + helpers for the fork-controller tests. Kept in a non-`_test`
/// file so the two `_test.dart` suites stay under the new-file line ceiling
/// while reusing one set of scaffolding.

/// Captures the fork body the controller posts and scripts the returned id.
/// `quotaExceeded` flips `forkFile` to throw the typed 409 so the quota path
/// can be exercised without a real server.
class RecordingSharesClient extends Fake implements SharesClient {
  Map<String, dynamic>? forkBody;
  String? forkedSourceId;
  String returnedId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  bool quotaExceeded = false;

  @override
  Future<String> forkFile(
    String sourceFileId,
    Map<String, dynamic> body,
  ) async {
    forkedSourceId = sourceFileId;
    forkBody = body;
    if (quotaExceeded) {
      throw const ForkQuotaExceededError();
    }
    return returnedId;
  }
}

/// Records the re-encrypted chunks the controller uploads and the finalizing
/// hash, so a test can prove the chunk tail ran against the returned id with
/// the new key.
class RecordingFilesClient extends Fake implements FilesClient {
  final List<Uint8List> uploadedChunks = [];
  final List<String> uploadedToFileIds = [];
  String? finalizedSha256;
  String? finalizedFileId;
  Map<String, dynamic> metadata = const {};

  @override
  Future<Map<String, dynamic>> uploadChunk({
    required String fileId,
    required int chunk,
    required Uint8List data,
    String? checksum,
    String? checksumFunction,
  }) async {
    uploadedToFileIds.add(fileId);
    uploadedChunks.add(data);
    return const {};
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
    finalizedFileId = fileId;
    finalizedSha256 = sha256;
  }

  @override
  Future<Map<String, dynamic>> getFileMetadata(String fileId) async => {
    'id': fileId,
    ...metadata,
  };
}

class FakeForkAuthClient extends Fake implements AuthClient {
  @override
  Future<TransferToken> requestTransferToken({
    required String fileId,
    required String action,
  }) async => TransferToken(
    token: 'transfer-token',
    expiresAt: 0,
    fileId: fileId,
    action: action,
  );
}

class FakeForkApiClient extends Fake implements ApiClient {
  FakeForkApiClient(this._shares, this._files, this._auth);

  final SharesClient _shares;
  final FilesClient _files;
  final AuthClient _auth;

  @override
  SharesClient get shares => _shares;

  @override
  FilesClient get files => _files;

  @override
  AuthClient get auth => _auth;
}

/// Returns a fixed plaintext for any [downloadFile] call so the controller's
/// re-key + re-upload runs deterministically without a transport.
class FakeForkDownloader extends Fake implements FileDownloader {
  FakeForkDownloader(this.plaintext);

  final Uint8List plaintext;
  FileItem? requested;
  Uint8List? requestedKey;

  @override
  Future<Uint8List> downloadFile(
    FileItem file, {
    required Uint8List fileKey,
    void Function(double progress)? onProgress,
    String? displayName,
    bool showInTransfers = true,
  }) async {
    requested = file;
    requestedKey = fileKey;
    return plaintext;
  }
}

/// Seeds the per-dir [FilesState] with the source's decrypted name + key so the
/// controller re-encrypts the *true* plaintext name (production opens a fork
/// from a populated "Shared with me" listing where both are already decrypted).
class SeededFilesNotifier extends FilesNotifier {
  SeededFilesNotifier(this._seed);

  final FilesState _seed;

  @override
  FilesState build(String? arg) => _seed;
}

Account forkAccount(String pubkey) => Account(
  id: 'acct',
  serverId: 'srv',
  userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  email: 'caller@example.com',
  fingerprint: null,
  publicKey: pubkey,
  encryptedPrivateKey: null,
  pinEncryptedPrivateKey: null,
  biometricPin: null,
  quota: null,
  role: null,
  isActive: true,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  lastUsedAt: null,
  cacheLimitBytes: null,
  headerJwt: null,
  headerRefreshToken: null,
);

/// Recover the unix-second timestamp the controller stamped into a signature by
/// replaying the small request-handling window — the controller's internal
/// `now` can only differ from the test's by the time it took to sign. Returns
/// the timestamp that makes the signature verify, or null if none in the
/// window do. Mirrors the helper in `files_share_controller_test.dart`.
int? findVerifyingTimestamp({
  required String signature,
  required AuditEventSigInput Function(int timestamp) build,
  required String senderPubkey,
  required String verifierKey,
}) {
  final verifier = ShareCrypto(privateKeyPem: verifierKey);
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  for (var t = now + 1; t >= now - 5; t--) {
    final ok = verifier.verifyAuditEvent(
      input: build(t),
      signature: signature,
      senderPubkey: senderPubkey,
    );
    if (ok) return t;
  }
  return null;
}
