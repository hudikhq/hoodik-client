import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';

import 'folder_membership_test_kit.dart';

/// Serves the moved folder's subtree from an in-memory dir-id → children map so
/// [FolderShareSubtree] can walk it. The cascade only calls [listFiles]; the
/// roots in these tests all carry their own `encrypted_key`, so the metadata
/// fallback in `_rootWithKey` never fires.
class FakeFilesClient extends Fake implements FilesClient {
  FakeFilesClient(this.tree);

  final Map<String, List<FileItem>> tree;

  @override
  Future<StorageResponse> listFiles({
    String? dirId,
    bool? editable,
    String? orderBy,
    String? order,
  }) async {
    return StorageResponse(children: tree[dirId] ?? const []);
  }
}

/// Captures the cascade/move-out bodies and replays a scripted sequence of
/// `moveIntoShared` results so the 409-retry path can be exercised.
class CapturingSharesClient extends Fake implements SharesClient {
  CapturingSharesClient({required this.roster, required this.moveResults});

  FolderMembersResponse roster;
  final List<Object> moveResults;

  int membersFetches = 0;
  final List<Map<String, dynamic>> moveBodies = [];
  final List<Map<String, dynamic>> moveOutBodies = [];

  @override
  Future<FolderMembersResponse> getFolderMembers(String folderId) async {
    membersFetches += 1;
    return roster;
  }

  @override
  Future<String> moveIntoShared(Map<String, dynamic> body) async {
    moveBodies.add(body);
    final next = moveResults.removeAt(0);
    if (next is Exception) throw next;
    return next as String;
  }

  @override
  Future<String> moveOutOfShared(Map<String, dynamic> body) async {
    moveOutBodies.add(body);
    return body['file_id'] as String;
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

/// A wired cascade harness: the capturing shares client, the subtree files
/// client, and a container with the crypto/membership providers overridden for
/// [signer].
typedef CascadeHarness = ({
  CapturingSharesClient shares,
  FakeFilesClient files,
  ProviderContainer c,
});

CascadeHarness wireCascade({
  required MembershipFixture fx,
  required AppDatabase db,
  required Party signer,
  required FolderMembersResponse roster,
  required Map<String, List<FileItem>> tree,
  List<Object>? moveResults,
}) {
  final shares = CapturingSharesClient(
    roster: roster,
    moveResults: moveResults ?? ['moved-file-id'],
  );
  final files = FakeFilesClient(tree);
  final container = ProviderContainer(
    overrides: [
      decryptedPrivateKeyProvider.overrideWith(
        (ref) => signer.keyPair.privateKeyPem,
      ),
      activeServerUserIdProvider.overrideWithValue(signer.userId),
      apiClientProvider.overrideWithValue(FakeApiClient(files, shares)),
      databaseProvider.overrideWithValue(db),
      folderMembershipProvider.overrideWithValue(fx.membership),
    ],
  );
  return (shares: shares, files: files, c: container);
}

/// A node the owner holds: a fresh symmetric key wrapped under the owner's own
/// pubkey, paired with the raw bytes so each member's re-wrap can be checked to
/// round-trip back to the same key.
({FileItem item, Uint8List key}) ownedNode(
  Party owner,
  String id, {
  String mime = 'text/plain',
}) {
  final key = cryptoService.generateSymmetricKey();
  final wrap = FileCrypto(
    privateKeyPem: owner.keyPair.privateKeyPem,
  ).encryptFileKey(fileKey: key, publicKeyPem: owner.pubkey);
  return (
    item: FileItem(id: id, encryptedName: 'e', encryptedKey: wrap, mime: mime),
    key: key,
  );
}

/// A roster whose list signature names a non-member as the signer, so the
/// verifier rejects it as unauthorized before any key is wrapped — the cheapest
/// tamper that proves the hard-stop runs ahead of the cascade.
FolderMembersResponse signedByNonMember(FolderMembersResponse valid) {
  return FolderMembersResponse(
    folderId: valid.folderId,
    folderOwnerId: valid.folderOwnerId,
    folderOwnerPubkeyFingerprint: valid.folderOwnerPubkeyFingerprint,
    signatureAlgorithm: valid.signatureAlgorithm,
    members: valid.members,
    membersSignedAt: valid.membersSignedAt,
    membersListSignature: valid.membersListSignature,
    membersListSignedByUserId: uuid(0x99),
  );
}
