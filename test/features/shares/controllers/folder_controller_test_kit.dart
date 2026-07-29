import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';

import '../services/folder_membership_test_kit.dart';

const _crypto = CryptoService();

class FakeFilesClient extends Fake implements FilesClient {
  FakeFilesClient(this.tree, {this.metadata = const {}});
  final Map<String, List<FileItem>> tree;

  /// fileId → raw metadata JSON, served by [getFileMetadata]. Used when a thin
  /// root folder arrives without its own `encrypted_key` and the subtree walk
  /// must recover it.
  final Map<String, Map<String, dynamic>> metadata;

  @override
  Future<StorageResponse> listFiles({
    String? dirId,
    bool? editable,
    String? orderBy,
    String? order,
  }) async => StorageResponse(children: tree[dirId] ?? const []);

  @override
  Future<Map<String, dynamic>> getFileMetadata(String fileId) async {
    final m = metadata[fileId];
    if (m == null) {
      throw StateError('FakeFilesClient: no metadata for $fileId');
    }
    return m;
  }
}

class CapturingSharesClient extends Fake implements SharesClient {
  CapturingSharesClient(this.roster);
  FolderMembersResponse roster;
  Map<String, dynamic>? createBody;
  (String, String, Map<String, dynamic>)? revokeArgs;

  @override
  Future<FolderMembersResponse> getFolderMembers(String folderId) async =>
      roster;

  @override
  Future<List<AppShare>> createShare(Map<String, dynamic> envelope) async {
    createBody = envelope;
    return const [];
  }

  @override
  Future<void> revokeShare(
    String fileId,
    String userId,
    Map<String, dynamic> body,
  ) async {
    revokeArgs = (fileId, userId, body);
  }
}

class FakeApiClient extends Fake implements ApiClient {
  FakeApiClient(this._files, this._shares);
  final FilesClient _files;
  final SharesClient _shares;
  @override
  FilesClient get files => _files;
  @override
  SharesClient get shares => _shares;
}

/// Re-encode the recipient's `MemberSigPayloadV1` exactly as the server does
/// (recipient's pubkey DER + fingerprint + role + signed_at) and verify the
/// supplied σ against the named signer — the byte-for-byte mirror of the
/// server's per-member check in `share.rs`.
bool memberSigVerifies({
  required Party recipient,
  required ShareRole role,
  required int signedAt,
  required String signature,
  required String signerPubkey,
}) {
  return recipient.crypto.verifyMemberSignature(
    userId: recipient.userId,
    pubkeyPem: recipient.pubkey,
    pubkeyFingerprintHex: recipient.fingerprint,
    shareRole: role,
    signedAt: signedAt,
    signature: signature,
    signerPubkey: signerPubkey,
  );
}

/// Wrap a fresh symmetric key under [owner]'s own pubkey — the form the server
/// stores in `user_files.encrypted_key` for a file the owner holds.
String ownWrap(Party owner) {
  final key = _crypto.generateSymmetricKey();
  return FileCrypto(
    privateKeyPem: owner.keyPair.privateKeyPem,
  ).encryptFileKey(fileKey: key, publicKeyPem: owner.pubkey);
}

/// One child file under the folder the signer can re-wrap. The server includes
/// the root folder in the subtree, so it too must be re-wrappable.
Map<String, List<FileItem>> folderTree(String folderId, Party owner) {
  return {
    folderId: [
      FileItem(
        id: '00000000-0000-0000-0000-0000000000a2',
        encryptedName: 'e',
        encryptedKey: ownWrap(owner),
        mime: 'text/plain',
      ),
    ],
  };
}

/// Wire a [ProviderContainer] so [FolderShareController] resolves real crypto
/// for [signer], a capturing shares client over [roster], and the given
/// subtree. Returns the capturing client for envelope assertions; the caller
/// owns disposal of the returned container.
({CapturingSharesClient shares, ProviderContainer container}) wireController({
  required Party signer,
  required FolderMembersResponse roster,
  required Map<String, List<FileItem>> tree,
  required AppDatabase db,
  Map<String, Map<String, dynamic>> metadata = const {},
}) {
  final shares = CapturingSharesClient(roster);
  final api = FakeApiClient(FakeFilesClient(tree, metadata: metadata), shares);
  final container = ProviderContainer(
    overrides: [
      decryptedPrivateKeyProvider.overrideWith(
        (ref) => signer.keyPair.privateKeyPem,
      ),
      activeServerUserIdProvider.overrideWithValue(signer.userId),
      apiClientProvider.overrideWithValue(api),
      databaseProvider.overrideWithValue(db),
    ],
  );
  return (shares: shares, container: container);
}
