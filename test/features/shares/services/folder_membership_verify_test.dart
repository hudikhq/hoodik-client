import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/features/shares/services/folder_membership.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import 'folder_membership_test_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late MembershipFixture fx;

  setUp(() => fx = MembershipFixture());
  tearDown(() async => await fx.dispose());

  group('verifyFolderMemberList', () {
    test('a validly-signed roster verifies and returns the members', () {
      final response = fx.validRoster();
      final verified = fx.membership.verifyFolderMemberList(response);
      expect(verified, hasLength(3));
      expect(
        verified.map((m) => m.userId),
        containsAll([fx.owner.userId, fx.alice.userId, fx.bob.userId]),
      );
    });

    test('a legacy null per-member σ is tolerated', () {
      final members = [
        ownerMember(fx.owner),
        FolderMember(
          userId: fx.alice.userId,
          email: 'a@example.test',
          pubkey: fx.alice.pubkey,
          pubkeyFingerprint: fx.alice.fingerprint,
          shareRole: ShareRole.reader,
          isOwner: false,
          addedAt: signedAt - 100,
          signedByUserId: fx.owner.userId,
          memberSignature: null,
        ),
      ];
      final response = buildResponse(
        owner: fx.owner,
        members: members,
        listSigner: fx.owner,
        signedAt: signedAt,
      );
      expect(fx.membership.verifyFolderMemberList(response), hasLength(2));
    });

    test('a co-owner-signed roster verifies (signer promotion)', () {
      // Owner grants alice co-owner; alice re-shares to bob and signs both
      // bob's σ and the whole list.
      final aliceMember = signedMember(
        party: fx.alice,
        role: ShareRole.coOwner,
        isOwner: false,
        signer: fx.owner,
        addedAt: signedAt - 200,
      );
      final bobMember = signedMember(
        party: fx.bob,
        role: ShareRole.reader,
        isOwner: false,
        signer: fx.alice,
        addedAt: signedAt - 50,
      );
      final response = buildResponse(
        owner: fx.owner,
        members: [ownerMember(fx.owner), aliceMember, bobMember],
        listSigner: fx.alice,
        signedAt: signedAt,
      );
      final verified = fx.membership.verifyFolderMemberList(response);
      expect(verified, hasLength(3));
    });

    // Role, fingerprint, and userId are all covered by the owner's list
    // signature, so tampering any of them breaks the list signature before the
    // per-member σ loop runs — exactly the web verifier's ordering
    // (editable.ts: list-signature check at :298-309 precedes Pass 2 at
    // :316-356). The reason asserted is therefore `listSignatureInvalid`; the
    // contract that matters is the HARD STOP. The per-member σ as a second line
    // of defense is exercised by the "valid list signature but tampered role"
    // and "forged per-member σ" tests below.
    test('a tampered member role is rejected (list signature first)', () {
      final response = fx.validRoster();
      final idx = response.members.indexWhere((m) => m.userId == fx.bob.userId);
      response.members[idx] = FolderMember(
        userId: fx.bob.userId,
        email: response.members[idx].email,
        pubkey: fx.bob.pubkey,
        pubkeyFingerprint: fx.bob.fingerprint,
        // Promote bob from editor to co-owner without a fresh σ.
        shareRole: ShareRole.coOwner,
        isOwner: false,
        addedAt: response.members[idx].addedAt,
        signedByUserId: fx.owner.userId,
        memberSignature: response.members[idx].memberSignature,
      );
      expect(
        () => fx.membership.verifyFolderMemberList(response),
        throwsA(
          isA<FolderMemberListInvalid>().having(
            (e) => e.reason,
            'reason',
            FolderMemberListInvalidReason.listSignatureInvalid,
          ),
        ),
      );
    });

    test('a tampered member fingerprint is rejected', () {
      final response = fx.validRoster();
      final idx = response.members.indexWhere(
        (m) => m.userId == fx.alice.userId,
      );
      response.members[idx] = FolderMember(
        userId: fx.alice.userId,
        email: response.members[idx].email,
        pubkey: fx.alice.pubkey,
        // Fingerprint no longer matches the pubkey.
        pubkeyFingerprint: fx.bob.fingerprint,
        shareRole: response.members[idx].shareRole,
        isOwner: false,
        addedAt: response.members[idx].addedAt,
        signedByUserId: fx.owner.userId,
        memberSignature: response.members[idx].memberSignature,
      );
      expect(
        () => fx.membership.verifyFolderMemberList(response),
        throwsA(
          isA<FolderMemberListInvalid>().having(
            (e) => e.reason,
            'reason',
            FolderMemberListInvalidReason.listSignatureInvalid,
          ),
        ),
      );
    });

    test('a swapped member userId is rejected', () {
      final response = fx.validRoster();
      final idx = response.members.indexWhere(
        (m) => m.userId == fx.alice.userId,
      );
      // Re-label alice's row as a fourth, unsigned user.
      response.members[idx] = FolderMember(
        userId: uuid(0x44),
        email: response.members[idx].email,
        pubkey: fx.alice.pubkey,
        pubkeyFingerprint: fx.alice.fingerprint,
        shareRole: response.members[idx].shareRole,
        isOwner: false,
        addedAt: response.members[idx].addedAt,
        signedByUserId: fx.owner.userId,
        memberSignature: response.members[idx].memberSignature,
      );
      expect(
        () => fx.membership.verifyFolderMemberList(response),
        throwsA(
          isA<FolderMemberListInvalid>().having(
            (e) => e.reason,
            'reason',
            FolderMemberListInvalidReason.listSignatureInvalid,
          ),
        ),
      );
    });

    test('a tampered role under a valid list signature fails per-member σ', () {
      // The attacker re-signs the list over the tampered roster (so the list
      // signature passes), but cannot forge bob's per-member σ over the new
      // role — the granter never signed co-owner for bob. Pass 2 is the
      // backstop that catches it.
      final bobTampered = FolderMember(
        userId: fx.bob.userId,
        email: 'b@example.test',
        pubkey: fx.bob.pubkey,
        pubkeyFingerprint: fx.bob.fingerprint,
        shareRole: ShareRole.coOwner,
        isOwner: false,
        addedAt: signedAt - 50,
        signedByUserId: fx.owner.userId,
        // σ produced by the owner over bob's *original* editor role.
        memberSignature: fx.owner.crypto.signMember(
          userId: fx.bob.userId,
          pubkeyPem: fx.bob.pubkey,
          pubkeyFingerprintHex: fx.bob.fingerprint,
          shareRole: ShareRole.editor,
          signedAt: signedAt - 50,
        ),
      );
      final response = buildResponse(
        owner: fx.owner,
        members: [ownerMember(fx.owner), bobTampered],
        listSigner: fx.owner,
        signedAt: signedAt,
      );
      expect(
        () => fx.membership.verifyFolderMemberList(response),
        throwsA(
          isA<FolderMemberListInvalid>().having(
            (e) => e.reason,
            'reason',
            FolderMemberListInvalidReason.memberSignatureInvalid,
          ),
        ),
      );
    });

    test('a corrupted members_list_signature is rejected', () {
      final response = fx.validRoster();
      final sig = response.membersListSignature!;
      final corrupted = '${sig.substring(0, sig.length - 4)}AAAA';
      final tampered = FolderMembersResponse(
        folderId: response.folderId,
        folderOwnerId: response.folderOwnerId,
        folderOwnerPubkeyFingerprint: response.folderOwnerPubkeyFingerprint,
        signatureAlgorithm: response.signatureAlgorithm,
        members: response.members,
        membersSignedAt: response.membersSignedAt,
        membersListSignature: corrupted,
        membersListSignedByUserId: response.membersListSignedByUserId,
      );
      expect(
        () => fx.membership.verifyFolderMemberList(tampered),
        throwsA(
          isA<FolderMemberListInvalid>().having(
            (e) => e.reason,
            'reason',
            FolderMemberListInvalidReason.listSignatureInvalid,
          ),
        ),
      );
    });

    test('a missing members_list_signature is rejected', () {
      final response = fx.validRoster();
      final stripped = FolderMembersResponse(
        folderId: response.folderId,
        folderOwnerId: response.folderOwnerId,
        folderOwnerPubkeyFingerprint: response.folderOwnerPubkeyFingerprint,
        signatureAlgorithm: response.signatureAlgorithm,
        members: response.members,
        membersSignedAt: response.membersSignedAt,
        membersListSignature: null,
        membersListSignedByUserId: null,
      );
      expect(
        () => fx.membership.verifyFolderMemberList(stripped),
        throwsA(
          isA<FolderMemberListInvalid>().having(
            (e) => e.reason,
            'reason',
            FolderMemberListInvalidReason.listSignatureMissing,
          ),
        ),
      );
    });

    test('a list signed by an unauthorized signer is rejected', () {
      // bob is only an editor — not the owner and not a verified co-owner — so
      // a list he signs must be rejected even though his signature is valid.
      final response = buildResponse(
        owner: fx.owner,
        members: [
          ownerMember(fx.owner),
          signedMember(
            party: fx.bob,
            role: ShareRole.editor,
            isOwner: false,
            signer: fx.owner,
            addedAt: signedAt - 50,
          ),
        ],
        listSigner: fx.bob,
        signedAt: signedAt,
      );
      expect(
        () => fx.membership.verifyFolderMemberList(response),
        throwsA(
          isA<FolderMemberListInvalid>().having(
            (e) => e.reason,
            'reason',
            FolderMemberListInvalidReason.listSignatureUnauthorizedSigner,
          ),
        ),
      );
    });

    test('a forged per-member σ is rejected', () {
      // bob's row carries a signature, but it was produced by alice — who is
      // only a reader here, not a delegated signer — so it cannot verify
      // against the owner the row claims signed it.
      final bobMember = signedMember(
        party: fx.bob,
        role: ShareRole.reader,
        isOwner: false,
        signer: fx.alice,
        addedAt: signedAt - 50,
      );
      final forged = FolderMember(
        userId: bobMember.userId,
        email: bobMember.email,
        pubkey: bobMember.pubkey,
        pubkeyFingerprint: bobMember.pubkeyFingerprint,
        shareRole: bobMember.shareRole,
        isOwner: false,
        addedAt: bobMember.addedAt,
        // Claim the owner signed it, but the σ is alice's.
        signedByUserId: fx.owner.userId,
        memberSignature: bobMember.memberSignature,
      );
      final response = buildResponse(
        owner: fx.owner,
        members: [ownerMember(fx.owner), forged],
        listSigner: fx.owner,
        signedAt: signedAt,
      );
      expect(
        () => fx.membership.verifyFolderMemberList(response),
        throwsA(
          isA<FolderMemberListInvalid>().having(
            (e) => e.reason,
            'reason',
            FolderMemberListInvalidReason.memberSignatureInvalid,
          ),
        ),
      );
    });

    test('a roster without the owner row is rejected', () {
      final response = buildResponse(
        owner: fx.owner,
        members: [
          signedMember(
            party: fx.alice,
            role: ShareRole.reader,
            isOwner: false,
            signer: fx.owner,
            addedAt: signedAt - 100,
          ),
        ],
        listSigner: fx.owner,
        signedAt: signedAt,
      );
      expect(
        () => fx.membership.verifyFolderMemberList(response),
        throwsA(
          isA<FolderMemberListInvalid>().having(
            (e) => e.reason,
            'reason',
            FolderMemberListInvalidReason.ownerMissing,
          ),
        ),
      );
    });
  });
}
