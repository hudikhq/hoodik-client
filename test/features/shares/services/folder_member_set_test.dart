import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/features/shares/services/folder_member_set.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import 'folder_membership_test_kit.dart';

/// Independently reconstruct the canonical `FolderMemberListV1` the server
/// builds in `prospective_from_db` for the given prospective rows, exactly as
/// `members_list_sig.rs` does: one member per row, `signed_by` defaulting to the
/// folder owner when absent, sorted by user_id inside the FFI encoder. This is
/// the byte-for-byte oracle the client's signature must verify against.
FolderMemberList serverReconstruction({
  required String folderId,
  required String ownerId,
  required List<
    ({
      String userId,
      String fpHex,
      ShareRole role,
      bool isOwner,
      String? signedBy,
    })
  >
  rows,
  required int signedAt,
}) {
  return FolderMemberList(
    folderId: folderId,
    folderOwnerId: ownerId,
    members: rows
        .map(
          (r) => FolderMemberListMember(
            userId: r.userId,
            pubkeyFingerprintHex: r.fpHex,
            shareRole: r.role,
            isOwner: r.isOwner,
            signedByUserId: r.signedBy ?? ownerId,
          ),
        )
        .toList(),
    membersSignedAt: signedAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late MembershipFixture fx;
  setUp(() => fx = MembershipFixture());
  tearDown(() async => await fx.dispose());

  group('afterGrant — server-parity', () {
    test('owner grants a new reader: signed list verifies against the server '
        'reconstruction', () {
      // Roster before: owner + alice(reader, signed by owner). Bob is new.
      final current = fx.buildOwnerRoster([
        (party: fx.alice, role: ShareRole.reader),
      ]);

      final members = FolderMemberSet.afterGrant(
        current: current,
        targetUserId: fx.bob.userId,
        targetFingerprintHex: fx.bob.fingerprint,
        newRole: ShareRole.editor,
        signerUserId: fx.owner.userId,
      );
      final snapshot = fx.membership.signMemberList(
        folderId: fx.folderId,
        folderOwnerId: fx.owner.userId,
        members: members,
        signedByUserId: fx.owner.userId,
        signedAt: signedAt,
      );

      // The server commits: owner, alice(reader, by owner), bob(editor, by
      // owner — its new shared_by_user_id is the caller). Reconstruct that and
      // verify the client's signature covers exactly those bytes.
      final expected = serverReconstruction(
        folderId: fx.folderId,
        ownerId: fx.owner.userId,
        rows: [
          (
            userId: fx.owner.userId,
            fpHex: fx.owner.fingerprint,
            role: ShareRole.reader,
            isOwner: true,
            signedBy: fx.owner.userId,
          ),
          (
            userId: fx.alice.userId,
            fpHex: fx.alice.fingerprint,
            role: ShareRole.reader,
            isOwner: false,
            signedBy: fx.owner.userId,
          ),
          (
            userId: fx.bob.userId,
            fpHex: fx.bob.fingerprint,
            role: ShareRole.editor,
            isOwner: false,
            signedBy: fx.owner.userId,
          ),
        ],
        signedAt: signedAt,
      );
      expect(
        fx.owner.crypto.verifyFolderMemberListSignature(
          list: expected,
          signature: snapshot.signature,
          signerPubkey: fx.owner.pubkey,
        ),
        isTrue,
        reason:
            'client signature must verify against the server reconstruction',
      );
      // The new member is attributed to the acting signer.
      final bobRow = members.firstWhere((m) => m.userId == fx.bob.userId);
      expect(bobRow.signedByUserId, fx.owner.userId);
    });

    test('co-owner reshare: new member attributed to the co-owner, list signed '
        'by the co-owner verifies', () {
      // owner + alice(co-owner, signed by owner). Alice reshares to bob.
      final current = fx.buildOwnerRoster([
        (party: fx.alice, role: ShareRole.coOwner),
      ]);

      final members = FolderMemberSet.afterGrant(
        current: current,
        targetUserId: fx.bob.userId,
        targetFingerprintHex: fx.bob.fingerprint,
        newRole: ShareRole.reader,
        signerUserId: fx.alice.userId,
      );
      // The co-owner signs the roster with her own key.
      final aliceMembership = fx.membershipFor(fx.alice);
      final snapshot = aliceMembership.signMemberList(
        folderId: fx.folderId,
        folderOwnerId: fx.owner.userId,
        members: members,
        signedByUserId: fx.alice.userId,
        signedAt: signedAt,
      );

      final expected = serverReconstruction(
        folderId: fx.folderId,
        ownerId: fx.owner.userId,
        rows: [
          (
            userId: fx.owner.userId,
            fpHex: fx.owner.fingerprint,
            role: ShareRole.reader,
            isOwner: true,
            signedBy: fx.owner.userId,
          ),
          (
            userId: fx.alice.userId,
            fpHex: fx.alice.fingerprint,
            role: ShareRole.coOwner,
            isOwner: false,
            signedBy: fx.owner.userId,
          ),
          (
            userId: fx.bob.userId,
            fpHex: fx.bob.fingerprint,
            role: ShareRole.reader,
            isOwner: false,
            signedBy: fx.alice.userId,
          ),
        ],
        signedAt: signedAt,
      );
      expect(
        fx.alice.crypto.verifyFolderMemberListSignature(
          list: expected,
          signature: snapshot.signature,
          signerPubkey: fx.alice.pubkey,
        ),
        isTrue,
      );
      expect(
        members.firstWhere((m) => m.userId == fx.bob.userId).signedByUserId,
        fx.alice.userId,
      );
    });

    test('role-change keeps one row for the target at the new role', () {
      final current = fx.buildOwnerRoster([
        (party: fx.alice, role: ShareRole.reader),
      ]);
      final members = FolderMemberSet.afterGrant(
        current: current,
        targetUserId: fx.alice.userId,
        targetFingerprintHex: fx.alice.fingerprint,
        newRole: ShareRole.coOwner,
        signerUserId: fx.owner.userId,
      );
      final aliceRows = members.where((m) => m.userId == fx.alice.userId);
      expect(aliceRows.length, 1, reason: 'no duplicate row on role-change');
      expect(aliceRows.single.shareRole, ShareRole.coOwner);
      // Owner + alice only — the role-change adds no member.
      expect(members.length, 2);
    });
  });

  group('afterRevoke — cascade parity', () {
    test('revoking a reader drops only that member', () {
      final current = fx.buildOwnerRoster([
        (party: fx.alice, role: ShareRole.reader),
        (party: fx.bob, role: ShareRole.editor),
      ]);
      final alice = current.members.firstWhere(
        (m) => m.userId == fx.alice.userId,
      );
      final remaining = FolderMemberSet.afterRevoke(
        current: current,
        revoked: alice,
      );
      expect(remaining.map((m) => m.userId).toSet(), {
        fx.owner.userId,
        fx.bob.userId,
      });
    });

    test('revoking a co-owner cascade-drops every member they signed', () {
      // owner + alice(co-owner, by owner) + bob(reader, by ALICE) +
      // carol(reader, by owner). Revoking alice must also drop bob, never carol.
      final carol = Party(uuid(0x44));
      final aliceMember = signedMember(
        party: fx.alice,
        role: ShareRole.coOwner,
        isOwner: false,
        signer: fx.owner,
        addedAt: signedAt - 100,
      );
      final bobByAlice = signedMember(
        party: fx.bob,
        role: ShareRole.reader,
        isOwner: false,
        signer: fx.alice,
        addedAt: signedAt - 50,
      );
      final carolByOwner = signedMember(
        party: carol,
        role: ShareRole.reader,
        isOwner: false,
        signer: fx.owner,
        addedAt: signedAt - 25,
      );
      final current = buildResponse(
        owner: fx.owner,
        members: [ownerMember(fx.owner), aliceMember, bobByAlice, carolByOwner],
        listSigner: fx.owner,
        signedAt: signedAt,
      );

      final remaining = FolderMemberSet.afterRevoke(
        current: current,
        revoked: aliceMember,
      );
      expect(
        remaining.map((m) => m.userId).toSet(),
        {fx.owner.userId, carol.userId},
        reason: 'alice (co-owner) and bob (signed by alice) drop; carol stays',
      );
    });

    test('post-revoke list verifies against the server reconstruction', () {
      final current = fx.buildOwnerRoster([
        (party: fx.alice, role: ShareRole.reader),
        (party: fx.bob, role: ShareRole.editor),
      ]);
      final bob = current.members.firstWhere((m) => m.userId == fx.bob.userId);
      final members = FolderMemberSet.afterRevoke(
        current: current,
        revoked: bob,
      );
      final snapshot = fx.membership.signMemberList(
        folderId: fx.folderId,
        folderOwnerId: fx.owner.userId,
        members: members,
        signedByUserId: fx.owner.userId,
        signedAt: signedAt,
      );
      final expected = serverReconstruction(
        folderId: fx.folderId,
        ownerId: fx.owner.userId,
        rows: [
          (
            userId: fx.owner.userId,
            fpHex: fx.owner.fingerprint,
            role: ShareRole.reader,
            isOwner: true,
            signedBy: fx.owner.userId,
          ),
          (
            userId: fx.alice.userId,
            fpHex: fx.alice.fingerprint,
            role: ShareRole.reader,
            isOwner: false,
            signedBy: fx.owner.userId,
          ),
        ],
        signedAt: signedAt,
      );
      expect(
        fx.owner.crypto.verifyFolderMemberListSignature(
          list: expected,
          signature: snapshot.signature,
          signerPubkey: fx.owner.pubkey,
        ),
        isTrue,
      );
    });
  });

  group('afterGroupShare — share-to-group server-parity', () {
    test('appends the whole group at the share role, signed by the caller, '
        'verifying against the server reconstruction', () {
      // Folder shared with no one yet; the owner shares it to a group whose
      // members are alice and bob. Both land at editor, signed by the owner.
      final current = fx.buildOwnerRoster(const []);

      final members = FolderMemberSet.afterGroupShare(
        current: current,
        granted: [
          (userId: fx.alice.userId, fingerprintHex: fx.alice.fingerprint),
          (userId: fx.bob.userId, fingerprintHex: fx.bob.fingerprint),
        ],
        newRole: ShareRole.editor,
        signerUserId: fx.owner.userId,
      );
      final snapshot = fx.membership.signMemberList(
        folderId: fx.folderId,
        folderOwnerId: fx.owner.userId,
        members: members,
        signedByUserId: fx.owner.userId,
        signedAt: signedAt,
      );

      final expected = serverReconstruction(
        folderId: fx.folderId,
        ownerId: fx.owner.userId,
        rows: [
          (
            userId: fx.owner.userId,
            fpHex: fx.owner.fingerprint,
            role: ShareRole.reader,
            isOwner: true,
            signedBy: fx.owner.userId,
          ),
          (
            userId: fx.alice.userId,
            fpHex: fx.alice.fingerprint,
            role: ShareRole.editor,
            isOwner: false,
            signedBy: fx.owner.userId,
          ),
          (
            userId: fx.bob.userId,
            fpHex: fx.bob.fingerprint,
            role: ShareRole.editor,
            isOwner: false,
            signedBy: fx.owner.userId,
          ),
        ],
        signedAt: signedAt,
      );
      expect(
        fx.owner.crypto.verifyFolderMemberListSignature(
          list: expected,
          signature: snapshot.signature,
          signerPubkey: fx.owner.pubkey,
        ),
        isTrue,
      );
    });

    test('a group member who already holds the folder is re-appended at the '
        'group share role, not carried forward at the old one', () {
      // Folder currently shared with alice(reader). The group share grants
      // alice and bob at editor — alice must end up at editor exactly once.
      final current = fx.buildOwnerRoster([
        (party: fx.alice, role: ShareRole.reader),
      ]);

      final members = FolderMemberSet.afterGroupShare(
        current: current,
        granted: [
          (userId: fx.alice.userId, fingerprintHex: fx.alice.fingerprint),
          (userId: fx.bob.userId, fingerprintHex: fx.bob.fingerprint),
        ],
        newRole: ShareRole.editor,
        signerUserId: fx.owner.userId,
      );

      final aliceRows = members.where((m) => m.userId == fx.alice.userId);
      expect(aliceRows, hasLength(1));
      expect(aliceRows.single.shareRole, ShareRole.editor);

      final expected = serverReconstruction(
        folderId: fx.folderId,
        ownerId: fx.owner.userId,
        rows: [
          (
            userId: fx.owner.userId,
            fpHex: fx.owner.fingerprint,
            role: ShareRole.reader,
            isOwner: true,
            signedBy: fx.owner.userId,
          ),
          (
            userId: fx.alice.userId,
            fpHex: fx.alice.fingerprint,
            role: ShareRole.editor,
            isOwner: false,
            signedBy: fx.owner.userId,
          ),
          (
            userId: fx.bob.userId,
            fpHex: fx.bob.fingerprint,
            role: ShareRole.editor,
            isOwner: false,
            signedBy: fx.owner.userId,
          ),
        ],
        signedAt: signedAt,
      );
      final snapshot = fx.membership.signMemberList(
        folderId: fx.folderId,
        folderOwnerId: fx.owner.userId,
        members: members,
        signedByUserId: fx.owner.userId,
        signedAt: signedAt,
      );
      expect(
        fx.owner.crypto.verifyFolderMemberListSignature(
          list: expected,
          signature: snapshot.signature,
          signerPubkey: fx.owner.pubkey,
        ),
        isTrue,
      );
    });
  });
}
