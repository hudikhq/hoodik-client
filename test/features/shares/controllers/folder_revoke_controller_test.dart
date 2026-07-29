import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/shares/controllers/folder_share_controller.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../services/folder_membership_test_kit.dart';
import 'folder_controller_test_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late MembershipFixture fx;
  late AppDatabase db;
  ProviderContainer? container;

  setUp(() {
    fx = MembershipFixture();
    db = fx.db;
  });
  tearDown(() {
    container?.dispose();
    container = null;
    return fx.dispose();
  });

  group('revokeMember envelope', () {
    test('co-owner revoke signs the cascaded post-revoke roster', () async {
      // owner + alice(co-owner, by owner) + bob(reader, by alice).
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
      final roster = buildResponse(
        owner: fx.owner,
        members: [ownerMember(fx.owner), aliceMember, bobByAlice],
        listSigner: fx.owner,
        signedAt: signedAt,
      );
      final w = wireController(
        signer: fx.owner,
        roster: roster,
        tree: const {},
        db: db,
      );
      container = w.container;
      final folder = FileItem(id: fx.folderId, encryptedName: '', mime: 'dir');

      final outcome = await w.container
          .read(folderShareControllerProvider)
          .revokeMember(folder: folder, roster: roster, member: aliceMember);
      expect(outcome, isA<FolderShareSuccess>());

      final (fileId, userId, revokeBody) = w.shares.revokeArgs!;
      expect(fileId, fx.folderId);
      expect(userId, fx.alice.userId);

      // The signed post-revoke roster is owner-only (alice + bob both gone).
      final listSig = revokeBody['members_list_signature'] as Map;
      final expected = FolderMemberList(
        folderId: fx.folderId,
        folderOwnerId: fx.owner.userId,
        members: [
          FolderMemberListMember(
            userId: fx.owner.userId,
            pubkeyFingerprintHex: fx.owner.fingerprint,
            shareRole: ShareRole.reader,
            isOwner: true,
            signedByUserId: fx.owner.userId,
          ),
        ],
        membersSignedAt: listSig['signed_at'] as int,
      );
      expect(
        fx.owner.crypto.verifyFolderMemberListSignature(
          list: expected,
          signature: listSig['signature'] as String,
          signerPubkey: fx.owner.pubkey,
        ),
        isTrue,
      );
    });

    test('the owner row cannot be revoked', () async {
      final roster = fx.buildOwnerRoster([
        (party: fx.alice, role: ShareRole.reader),
      ]);
      final w = wireController(
        signer: fx.owner,
        roster: roster,
        tree: const {},
        db: db,
      );
      container = w.container;
      final folder = FileItem(id: fx.folderId, encryptedName: '', mime: 'dir');
      final ownerRow = roster.members.firstWhere((m) => m.isOwner);

      final outcome = await w.container
          .read(folderShareControllerProvider)
          .revokeMember(folder: folder, roster: roster, member: ownerRow);
      expect(outcome, isA<FolderShareFailure>());
      expect(w.shares.revokeArgs, isNull);
    });
  });

  group('cascadeImpact', () {
    test('counts only the members a co-owner signed', () {
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
      final roster = buildResponse(
        owner: fx.owner,
        members: [ownerMember(fx.owner), aliceMember, bobByAlice],
        listSigner: fx.owner,
        signedAt: signedAt,
      );
      expect(FolderShareController.cascadeImpact(roster, aliceMember), 1);
      expect(FolderShareController.cascadeImpact(roster, bobByAlice), 0);
    });
  });
}
