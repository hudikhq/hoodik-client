import 'package:drift/native.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/shares/services/folder_membership.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;

const signedAt = 1736000000;

String uuid(int byte) {
  final hex = byte.toRadixString(16).padLeft(2, '0') * 16;
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

const cryptoService = CryptoService();

/// One participant in a test roster: a real RSA keypair plus the fixed UUID the
/// owner/server would assign. The fingerprint is derived from the public key so
/// it matches what the verifier recomputes.
class Party {
  Party(this.userId) : keyPair = rust.generateRsaKeypair();

  final String userId;
  final rust.RsaKeyPair keyPair;

  String get pubkey => keyPair.publicKeyPem;
  ShareCrypto get crypto => ShareCrypto(privateKeyPem: keyPair.privateKeyPem);
  String get fingerprint =>
      cryptoService.rsaFingerprintPublic(publicKeyPem: keyPair.publicKeyPem);
}

/// Build a [FolderMember] and sign its per-member σ with [signer], mirroring
/// what the granter produces at grant time (`signedAt == addedAt`).
FolderMember signedMember({
  required Party party,
  required ShareRole role,
  required bool isOwner,
  required Party signer,
  required int addedAt,
}) {
  final signature = signer.crypto.signMember(
    userId: party.userId,
    pubkeyPem: party.pubkey,
    pubkeyFingerprintHex: party.fingerprint,
    shareRole: role,
    signedAt: addedAt,
  );
  return FolderMember(
    userId: party.userId,
    email: '${party.userId}@example.test',
    pubkey: party.pubkey,
    pubkeyFingerprint: party.fingerprint,
    shareRole: role,
    isOwner: isOwner,
    addedAt: addedAt,
    signedByUserId: signer.userId,
    memberSignature: signature,
  );
}

/// The owner row has no granter: null σ, null addedAt, self-referential
/// signedByUserId — exactly what the server emits for `is_owner` rows.
FolderMember ownerMember(Party owner) {
  return FolderMember(
    userId: owner.userId,
    email: '${owner.userId}@example.test',
    pubkey: owner.pubkey,
    pubkeyFingerprint: owner.fingerprint,
    shareRole: ShareRole.reader,
    isOwner: true,
    addedAt: null,
    signedByUserId: null,
    memberSignature: null,
  );
}

FolderMemberListMember toListMember(FolderMember m, String ownerId) {
  return FolderMemberListMember(
    userId: m.userId,
    pubkeyFingerprintHex: m.pubkeyFingerprint,
    shareRole: m.shareRole,
    isOwner: m.isOwner,
    signedByUserId: m.signedByUserId ?? ownerId,
  );
}

/// Assemble a [FolderMembersResponse] whose `members_list_signature` is
/// produced by [listSigner] over the exact [FolderMemberList] the verifier
/// re-encodes. Members are sorted by user_id, matching the server.
FolderMembersResponse buildResponse({
  required Party owner,
  required List<FolderMember> members,
  required Party listSigner,
  required int signedAt,
}) {
  final sorted = [...members]..sort((a, b) => a.userId.compareTo(b.userId));
  final signed = listSigner.crypto.signFolderMemberList(
    FolderMemberList(
      folderId: uuid(0xF0),
      folderOwnerId: owner.userId,
      members: sorted.map((m) => toListMember(m, owner.userId)).toList(),
      membersSignedAt: signedAt,
    ),
  );
  return FolderMembersResponse(
    folderId: uuid(0xF0),
    folderOwnerId: owner.userId,
    folderOwnerPubkeyFingerprint: owner.fingerprint,
    signatureAlgorithm: 'rsa-pss-sha256',
    members: sorted,
    membersSignedAt: signedAt,
    membersListSignature: signed.signature,
    membersListSignedByUserId: listSigner.userId,
  );
}

/// Three fresh parties, an in-memory Drift database, and a [FolderMembership]
/// wired to the owner — the per-test fixture both suites share.
class MembershipFixture {
  MembershipFixture()
    : owner = Party(uuid(0x11)),
      alice = Party(uuid(0x22)),
      bob = Party(uuid(0x33)),
      db = AppDatabase.forTesting(NativeDatabase.memory()) {
    membership = FolderMembership(
      crypto: owner.crypto,
      db: db,
      ownerUserId: owner.userId,
    );
  }

  final Party owner;
  final Party alice;
  final Party bob;
  final AppDatabase db;
  late final FolderMembership membership;

  /// The fixed folder id every roster in these suites uses.
  String get folderId => uuid(0xF0);

  /// A [FolderMembership] acting as [party] — used to sign a roster as a
  /// co-owner reshare rather than as the owner.
  FolderMembership membershipFor(Party party) =>
      FolderMembership(crypto: party.crypto, db: db, ownerUserId: party.userId);

  /// Owner + the given members, each directly granted (and σ-signed) by the
  /// owner at a distinct `added_at`. The list signature is the owner's.
  FolderMembersResponse buildOwnerRoster(
    List<({Party party, ShareRole role})> members,
  ) {
    final rows = <FolderMember>[ownerMember(owner)];
    var offset = 100;
    for (final m in members) {
      rows.add(
        signedMember(
          party: m.party,
          role: m.role,
          isOwner: false,
          signer: owner,
          addedAt: signedAt - offset,
        ),
      );
      offset -= 10;
    }
    return buildResponse(
      owner: owner,
      members: rows,
      listSigner: owner,
      signedAt: signedAt,
    );
  }

  /// Owner + two reader members, all directly granted by the owner.
  FolderMembersResponse validRoster() {
    final members = [
      ownerMember(owner),
      signedMember(
        party: alice,
        role: ShareRole.reader,
        isOwner: false,
        signer: owner,
        addedAt: signedAt - 100,
      ),
      signedMember(
        party: bob,
        role: ShareRole.editor,
        isOwner: false,
        signer: owner,
        addedAt: signedAt - 50,
      ),
    ];
    return buildResponse(
      owner: owner,
      members: members,
      listSigner: owner,
      signedAt: signedAt,
    );
  }

  Future<void> dispose() => db.close();
}
