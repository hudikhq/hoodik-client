import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/features/shares/services/folder_membership.dart';
import 'package:hoodik_app/features/shares/services/trusted_fingerprint_dao.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import 'folder_membership_test_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late MembershipFixture fx;

  setUp(() => fx = MembershipFixture());
  tearDown(() async => await fx.dispose());

  group('reconcileFingerprints', () {
    test('an absent peer is recorded silently (TOFU)', () async {
      final members = fx.membership.verifyFolderMemberList(fx.validRoster());
      await fx.membership.reconcileFingerprints(members);

      final recorded = await fx.db.getTrustedFingerprint(
        fx.owner.userId,
        fx.alice.userId,
      );
      expect(recorded, isNotNull);
      expect(recorded!.fingerprint, fx.alice.fingerprint);
      // The caller's own row is never recorded.
      expect(
        await fx.db.getTrustedFingerprint(fx.owner.userId, fx.owner.userId),
        isNull,
      );
    });

    test('a matching cached fingerprint passes', () async {
      await fx.db.upsertTrustedFingerprint(
        ownerUserId: fx.owner.userId,
        userId: fx.alice.userId,
        fingerprint: fx.alice.fingerprint,
      );
      final members = fx.membership.verifyFolderMemberList(fx.validRoster());
      await expectLater(
        fx.membership.reconcileFingerprints(members),
        completes,
      );
    });

    test('a changed cached fingerprint throws', () async {
      await fx.db.upsertTrustedFingerprint(
        ownerUserId: fx.owner.userId,
        userId: fx.alice.userId,
        fingerprint: fx.bob.fingerprint, // stale, different value
      );
      final members = fx.membership.verifyFolderMemberList(fx.validRoster());
      await expectLater(
        fx.membership.reconcileFingerprints(members),
        throwsA(
          isA<FolderMemberFingerprintChanged>()
              .having((e) => e.member.userId, 'member.userId', fx.alice.userId)
              .having((e) => e.observed, 'observed', fx.alice.fingerprint),
        ),
      );
    });
  });

  group('signMemberList', () {
    test('round-trips through verifyFolderMemberListSignature', () {
      final members = [
        toListMember(ownerMember(fx.owner), fx.owner.userId),
        FolderMemberListMember(
          userId: fx.alice.userId,
          pubkeyFingerprintHex: fx.alice.fingerprint,
          shareRole: ShareRole.coOwner,
          isOwner: false,
          signedByUserId: fx.owner.userId,
        ),
      ];
      final snapshot = fx.membership.signMemberList(
        folderId: uuid(0xF0),
        folderOwnerId: fx.owner.userId,
        members: members,
        signedByUserId: fx.owner.userId,
        signedAt: signedAt,
      );

      expect(snapshot.signedByUserId, fx.owner.userId);
      expect(snapshot.signedAt, signedAt);
      expect(
        fx.owner.crypto.verifyFolderMemberListSignature(
          list: FolderMemberList(
            folderId: uuid(0xF0),
            folderOwnerId: fx.owner.userId,
            members: members,
            membersSignedAt: signedAt,
          ),
          signature: snapshot.signature,
          signerPubkey: fx.owner.pubkey,
        ),
        isTrue,
      );
    });
  });
}
