import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/shares/controllers/folder_share_controller.dart';
import 'package:hoodik_app/features/shares/services/trusted_fingerprint_dao.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../services/folder_membership_test_kit.dart';
import 'folder_controller_test_kit.dart';

const _crypto = CryptoService();

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

  group('shareFolder envelope', () {
    test(
      're-sharing an existing member at their current role is a no-op',
      () async {
        final roster = fx.buildOwnerRoster([
          (party: fx.alice, role: ShareRole.reader),
        ]);
        final w = wireController(
          signer: fx.owner,
          roster: roster,
          tree: folderTree(fx.folderId, fx.owner),
          db: db,
        );
        container = w.container;
        final folder = FileItem(
          id: fx.folderId,
          encryptedName: '',
          encryptedKey: ownWrap(fx.owner),
          mime: 'dir',
        );
        final recipient = DiscoveredUser(
          userId: fx.alice.userId,
          email: 'alice@example.test',
          pubkey: fx.alice.pubkey,
          fingerprint: fx.alice.fingerprint,
        );

        final outcome = await w.container
            .read(folderShareControllerProvider)
            .shareFolder(
              folder: folder,
              recipient: recipient,
              role: ShareRole.reader,
            );

        expect(outcome, isA<FolderShareSuccess>());
        expect(
          w.shares.createBody,
          isNull,
          reason:
              'a same-role re-share must not POST: the server skips the row and '
              'would reject the predicted grant audit action as a role_change',
        );
      },
    );

    test('first share of a never-shared folder succeeds with no prior '
        'list signature', () async {
      // A folder shared for the first time has only the owner row and no
      // members_list_signature — exactly what the server returns. The grant
      // must create the first signed roster, not refuse on a missing prior
      // signature (regression: this hard-stopped the first folder share).
      final roster = FolderMembersResponse(
        folderId: fx.folderId,
        folderOwnerId: fx.owner.userId,
        folderOwnerPubkeyFingerprint: fx.owner.fingerprint,
        signatureAlgorithm: 'rsa-pss-sha256',
        members: [ownerMember(fx.owner)],
        membersSignedAt: null,
        membersListSignature: null,
        membersListSignedByUserId: null,
      );
      final w = wireController(
        signer: fx.owner,
        roster: roster,
        tree: folderTree(fx.folderId, fx.owner),
        db: db,
      );
      container = w.container;
      final folder = FileItem(
        id: fx.folderId,
        encryptedName: '',
        encryptedKey: ownWrap(fx.owner),
        mime: 'dir',
      );
      final recipient = DiscoveredUser(
        userId: fx.bob.userId,
        email: 'bob@example.test',
        pubkey: fx.bob.pubkey,
        fingerprint: fx.bob.fingerprint,
      );

      final outcome = await w.container
          .read(folderShareControllerProvider)
          .shareFolder(
            folder: folder,
            recipient: recipient,
            role: ShareRole.reader,
          );
      expect(outcome, isA<FolderShareSuccess>());

      // The POST carries a freshly-signed roster: owner + the new recipient.
      final listSig = w.shares.createBody!['members_list_signature'] as Map;
      expect(listSig['signed_by_user_id'], fx.owner.userId);
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
          FolderMemberListMember(
            userId: fx.bob.userId,
            pubkeyFingerprintHex: fx.bob.fingerprint,
            shareRole: ShareRole.reader,
            isOwner: false,
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

    test('a thin folder FileItem (no key) recovers the root key via '
        'metadata', () async {
      // The members screen reaches shareFolder with a folder reconstructed
      // from just its route id — no encrypted_key. The subtree walk must
      // recover the root's key from metadata, or the first folder share fails
      // with "no key to re-wrap" (regression).
      final roster = FolderMembersResponse(
        folderId: fx.folderId,
        folderOwnerId: fx.owner.userId,
        folderOwnerPubkeyFingerprint: fx.owner.fingerprint,
        signatureAlgorithm: 'rsa-pss-sha256',
        members: [ownerMember(fx.owner)],
        membersSignedAt: null,
        membersListSignature: null,
        membersListSignedByUserId: null,
      );
      final w = wireController(
        signer: fx.owner,
        roster: roster,
        tree: const {}, // empty folder — only the root needs re-wrapping
        metadata: {
          fx.folderId: {
            'id': fx.folderId,
            'mime': 'dir',
            'encrypted_name': '',
            'encrypted_key': ownWrap(fx.owner),
          },
        },
        db: db,
      );
      container = w.container;
      // Thin folder, exactly as the members-screen route reconstructs it.
      final folder = FileItem(id: fx.folderId, encryptedName: '', mime: 'dir');
      final recipient = DiscoveredUser(
        userId: fx.bob.userId,
        email: 'bob@example.test',
        pubkey: fx.bob.pubkey,
        fingerprint: fx.bob.fingerprint,
      );

      final outcome = await w.container
          .read(folderShareControllerProvider)
          .shareFolder(
            folder: folder,
            recipient: recipient,
            role: ShareRole.reader,
          );
      expect(outcome, isA<FolderShareSuccess>());

      // The root folder's key is re-wrapped into entries and bob can unwrap it.
      final entries = (w.shares.createBody!['entries'] as List).cast<Map>();
      expect(entries.single['file_id'], fx.folderId);
      final unwrapped = _crypto.rsaDecrypt(
        ciphertextBase64: entries.single['encrypted_key'] as String,
        privateKeyPem: fx.bob.keyPair.privateKeyPem,
      );
      expect(unwrapped, isNotEmpty);
    });

    test(
      'owner grant: every signature verifies and the action is grant',
      () async {
        final roster = fx.buildOwnerRoster([
          (party: fx.alice, role: ShareRole.reader),
        ]);
        final w = wireController(
          signer: fx.owner,
          roster: roster,
          tree: folderTree(fx.folderId, fx.owner),
          db: db,
        );
        container = w.container;
        final folder = FileItem(
          id: fx.folderId,
          encryptedName: '',
          encryptedKey: ownWrap(fx.owner),
          mime: 'dir',
        );
        final recipient = DiscoveredUser(
          userId: fx.bob.userId,
          email: 'bob@example.test',
          pubkey: fx.bob.pubkey,
          fingerprint: fx.bob.fingerprint,
        );

        final outcome = await w.container
            .read(folderShareControllerProvider)
            .shareFolder(
              folder: folder,
              recipient: recipient,
              role: ShareRole.editor,
            );
        expect(outcome, isA<FolderShareSuccess>());

        final body = w.shares.createBody!;
        expect(
          body.keys,
          containsAll([
            'payload_der',
            'signature',
            'entries',
            'event_signature',
            'member_signature',
            'member_signed_at',
            'members_list_signature',
          ]),
        );

        // entries cover the whole subtree (root folder + one child), and the
        // recipient can unwrap each.
        final entries = (body['entries'] as List).cast<Map>();
        expect(entries.length, 2);
        for (final e in entries) {
          final unwrapped = _crypto.rsaDecrypt(
            ciphertextBase64: e['encrypted_key'] as String,
            privateKeyPem: fx.bob.keyPair.privateKeyPem,
          );
          expect(unwrapped, isNotEmpty);
        }

        // member σ verifies against the owner (acting signer) for the editor role.
        final signedAtUsed = body['member_signed_at'] as int;
        expect(
          memberSigVerifies(
            recipient: fx.bob,
            role: ShareRole.editor,
            signedAt: signedAtUsed,
            signature: body['member_signature'] as String,
            signerPubkey: fx.owner.pubkey,
          ),
          isTrue,
        );

        // members_list signature verifies against the post-add server set.
        final listSig = body['members_list_signature'] as Map;
        expect(listSig['signed_by_user_id'], fx.owner.userId);
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
            FolderMemberListMember(
              userId: fx.alice.userId,
              pubkeyFingerprintHex: fx.alice.fingerprint,
              shareRole: ShareRole.reader,
              isOwner: false,
              signedByUserId: fx.owner.userId,
            ),
            FolderMemberListMember(
              userId: fx.bob.userId,
              pubkeyFingerprintHex: fx.bob.fingerprint,
              shareRole: ShareRole.editor,
              isOwner: false,
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

        // The recipient is recorded as trusted on success.
        final trusted = await db.getTrustedFingerprint(
          fx.owner.userId,
          fx.bob.userId,
        );
        expect(trusted?.fingerprint, fx.bob.fingerprint);
      },
    );

    test('co-owner reshare: audit event signs as shared_by_co_owner and the '
        'member σ verifies against the co-owner', () async {
      // owner + alice(co-owner). Alice reshares to bob. Alice is the caller.
      final roster = fx.buildOwnerRoster([
        (party: fx.alice, role: ShareRole.coOwner),
      ]);
      final w = wireController(
        signer: fx.alice,
        roster: roster,
        tree: folderTree(fx.folderId, fx.alice),
        db: db,
      );
      container = w.container;
      final folder = FileItem(
        id: fx.folderId,
        encryptedName: '',
        encryptedKey: ownWrap(fx.alice),
        mime: 'dir',
        isOwner: false,
        shareRole: ShareRole.coOwner,
      );
      final recipient = DiscoveredUser(
        userId: fx.bob.userId,
        email: 'bob@example.test',
        pubkey: fx.bob.pubkey,
        fingerprint: fx.bob.fingerprint,
      );

      final outcome = await w.container
          .read(folderShareControllerProvider)
          .shareFolder(
            folder: folder,
            recipient: recipient,
            role: ShareRole.reader,
          );
      expect(outcome, isA<FolderShareSuccess>());

      final body = w.shares.createBody!;
      // member σ verifies against alice (the reshaping co-owner).
      expect(
        memberSigVerifies(
          recipient: fx.bob,
          role: ShareRole.reader,
          signedAt: body['member_signed_at'] as int,
          signature: body['member_signature'] as String,
          signerPubkey: fx.alice.pubkey,
        ),
        isTrue,
      );
      expect(
        (body['members_list_signature'] as Map)['signed_by_user_id'],
        fx.alice.userId,
      );
    });
  });
}
