import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/shares/controllers/folder_share_controller.dart';
import 'package:hoodik_app/features/shares/services/move_into_shared_cascade.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import 'folder_membership_test_kit.dart';
import 'move_cascade_test_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late MembershipFixture fx;
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    fx = MembershipFixture();
    db = fx.db;
  });
  tearDown(() {
    container.dispose();
    return fx.dispose();
  });

  CascadeHarness wire({
    required Party signer,
    required FolderMembersResponse roster,
    required Map<String, List<FileItem>> tree,
    List<Object>? moveResults,
  }) {
    final h = wireCascade(
      fx: fx,
      db: db,
      signer: signer,
      roster: roster,
      tree: tree,
      moveResults: moveResults,
    );
    container = h.c;
    return h;
  }

  group('moveFolderIntoShared', () {
    test('builds one entry per node, each wrapped for every member', () async {
      final roster = fx.validRoster();
      final root = ownedNode(fx.owner, uuid(0xA0), mime: 'dir');
      final sub = ownedNode(fx.owner, uuid(0xA1), mime: 'dir');
      final fileA = ownedNode(fx.owner, uuid(0xA2));
      final fileB = ownedNode(fx.owner, uuid(0xB1));
      final w = wire(
        signer: fx.owner,
        roster: roster,
        tree: {
          root.item.id: [sub.item, fileA.item],
          sub.item.id: [fileB.item],
        },
      );

      final outcome = await w.c
          .read(moveIntoSharedCascadeProvider)
          .moveFolderIntoShared(
            folder: root.item,
            destinationFolderId: roster.folderId,
          );
      expect(outcome, isA<FolderShareSuccess>());

      final body = w.shares.moveBodies.single;
      expect(body['file_id'], root.item.id);
      expect(body['destination_folder_id'], roster.folderId);

      final entries = (body['entries'] as List).cast<Map<String, dynamic>>();
      expect(
        entries.map((e) => e['file_id'] as String).toSet(),
        {root.item.id, sub.item.id, fileA.item.id, fileB.item.id},
        reason: 'the server requires an entry for the root plus every node',
      );

      // Every entry carries one wrap per member, and each unwraps to that
      // node's own key — the full entries × members matrix.
      final keyByNode = {
        root.item.id: root.key,
        sub.item.id: sub.key,
        fileA.item.id: fileA.key,
        fileB.item.id: fileB.key,
      };
      for (final entry in entries) {
        final keys = (entry['member_keys'] as List)
            .cast<Map<String, dynamic>>();
        final byUser = {for (final k in keys) k['user_id'] as String: k};
        expect(byUser.keys, {fx.owner.userId, fx.alice.userId, fx.bob.userId});
        final expectedKey = keyByNode[entry['file_id'] as String]!;
        for (final party in [fx.owner, fx.alice, fx.bob]) {
          final unwrapped = FileCrypto(
            privateKeyPem: party.keyPair.privateKeyPem,
          ).decryptFileKey(byUser[party.userId]!['encrypted_key'] as String);
          expect(unwrapped, expectedKey);
          // is_owner_of_file marks only the caller (the file owner).
          expect(
            byUser[party.userId]!['is_owner_of_file'],
            party.userId == fx.owner.userId,
          );
        }
      }
    });

    test(
      'echoes the roster snapshot and signs a verifiable upload event',
      () async {
        final roster = fx.validRoster();
        final root = ownedNode(fx.owner, uuid(0xA0), mime: 'dir');
        final fileA = ownedNode(fx.owner, uuid(0xA2));
        final w = wire(
          signer: fx.owner,
          roster: roster,
          tree: {
            root.item.id: [fileA.item],
          },
        );

        await w.c
            .read(moveIntoSharedCascadeProvider)
            .moveFolderIntoShared(
              folder: root.item,
              destinationFolderId: roster.folderId,
            );
        final body = w.shares.moveBodies.single;

        final snapshot = body['members_list_snapshot'] as Map<String, dynamic>;
        expect(snapshot['members_signed_at'], roster.membersSignedAt);
        expect(snapshot['members_list_signature'], roster.membersListSignature);

        // The audit event is bound to the moved root and verifies against the
        // caller's pubkey — the canonical the server reconstructs.
        final ok = fx.owner.crypto.verifyAuditEvent(
          input: AuditEventSigInput(
            senderId: fx.owner.userId,
            recipientId: null,
            fileId: root.item.id,
            action: AuditEventAction.sharedFolderUpload,
            shareRoleBefore: null,
            shareRoleAfter: null,
            timestamp: body['timestamp'] as int,
          ),
          signature: body['event_signature'] as String,
          senderPubkey: fx.owner.pubkey,
        );
        expect(ok, isTrue);
      },
    );

    test('confirm gate aborts before any wrap when it returns false', () async {
      final roster = fx.validRoster();
      final root = ownedNode(fx.owner, uuid(0xA0), mime: 'dir');
      final fileA = ownedNode(fx.owner, uuid(0xA2));
      final w = wire(
        signer: fx.owner,
        roster: roster,
        tree: {
          root.item.id: [fileA.item],
        },
      );

      MoveCascadePreview? seen;
      final outcome = await w.c
          .read(moveIntoSharedCascadeProvider)
          .moveFolderIntoShared(
            folder: root.item,
            destinationFolderId: roster.folderId,
            confirm: (preview) async {
              seen = preview;
              return false;
            },
          );

      expect(outcome, isA<FolderShareFailure>());
      expect((outcome as FolderShareFailure).message, isEmpty);
      expect(w.shares.moveBodies, isEmpty, reason: 'nothing is sent on cancel');
      // The preview counts descendants (excludes the moved root).
      expect(seen!.itemCount, 1);
    });

    test(
      'preview members match the fan-out: dest roster minus the mover',
      () async {
        // Alice (a roster member, not the folder owner) moves her own folder into
        // the folder Owner shares with Alice and Bob. The keys fan out to every
        // roster member; the preview shows who actually receives them — Owner and
        // Bob — and never the mover (Alice).
        final roster = fx.validRoster();
        final root = ownedNode(fx.alice, uuid(0xA0), mime: 'dir');
        final fileA = ownedNode(fx.alice, uuid(0xA2));
        final w = wire(
          signer: fx.alice,
          roster: roster,
          tree: {
            root.item.id: [fileA.item],
          },
        );

        MoveCascadePreview? seen;
        await w.c
            .read(moveIntoSharedCascadeProvider)
            .moveFolderIntoShared(
              folder: root.item,
              destinationFolderId: roster.folderId,
              confirm: (preview) async {
                seen = preview;
                return true;
              },
            );

        final previewed = seen!.members.map((m) => m.userId).toSet();
        final fannedOut =
            (w.shares.moveBodies.single['entries'] as List)
                    .cast<Map<String, dynamic>>()
                    .first['member_keys']
                as List;
        final recipients = fannedOut
            .cast<Map<String, dynamic>>()
            .map((k) => k['user_id'] as String)
            .where((id) => id != fx.alice.userId)
            .toSet();

        expect(previewed, {fx.owner.userId, fx.bob.userId});
        expect(
          previewed,
          recipients,
          reason: 'the preview lists exactly who the cascade wraps keys for',
        );
      },
    );

    test('409 refreshes the roster and retries the cascade once', () async {
      final roster = fx.validRoster();
      final root = ownedNode(fx.owner, uuid(0xA0), mime: 'dir');
      final fileA = ownedNode(fx.owner, uuid(0xA2));
      final w = wire(
        signer: fx.owner,
        roster: roster,
        tree: {
          root.item.id: [fileA.item],
        },
        moveResults: [
          ShareMembershipChangedError(fx.validRoster()),
          'moved-file-id',
        ],
      );

      final outcome = await w.c
          .read(moveIntoSharedCascadeProvider)
          .moveFolderIntoShared(
            folder: root.item,
            destinationFolderId: roster.folderId,
          );

      expect(outcome, isA<FolderShareSuccess>());
      expect(w.shares.moveBodies.length, 2, reason: 'one retry after the 409');
    });

    test('a second 409 surfaces as a failure', () async {
      final roster = fx.validRoster();
      final root = ownedNode(fx.owner, uuid(0xA0), mime: 'dir');
      final fileA = ownedNode(fx.owner, uuid(0xA2));
      final w = wire(
        signer: fx.owner,
        roster: roster,
        tree: {
          root.item.id: [fileA.item],
        },
        moveResults: [
          ShareMembershipChangedError(fx.validRoster()),
          ShareMembershipChangedError(fx.validRoster()),
        ],
      );

      final outcome = await w.c
          .read(moveIntoSharedCascadeProvider)
          .moveFolderIntoShared(
            folder: root.item,
            destinationFolderId: roster.folderId,
          );

      expect(outcome, isA<FolderShareFailure>());
      expect(w.shares.moveBodies.length, 2);
    });

    test('a tampered roster hard-stops before any wrap', () async {
      final tampered = signedByNonMember(fx.validRoster());
      final root = ownedNode(fx.owner, uuid(0xA0), mime: 'dir');
      final fileA = ownedNode(fx.owner, uuid(0xA2));
      final w = wire(
        signer: fx.owner,
        roster: tampered,
        tree: {
          root.item.id: [fileA.item],
        },
      );

      final outcome = await w.c
          .read(moveIntoSharedCascadeProvider)
          .moveFolderIntoShared(
            folder: root.item,
            destinationFolderId: tampered.folderId,
          );

      expect(outcome, isA<FolderShareFailure>());
      expect(w.shares.moveBodies, isEmpty);
    });
  });

  group('moveOutOfShared', () {
    test(
      'builds a no-wrap body and signs a verifiable move-out event',
      () async {
        final roster = fx.validRoster();
        final file = ownedNode(fx.owner, uuid(0xC4));
        final w = wire(signer: fx.owner, roster: roster, tree: const {});

        final outcome = await w.c
            .read(moveIntoSharedCascadeProvider)
            .moveOutOfShared(file: file.item, destinationFolderId: uuid(0xD0));
        expect(outcome, isA<FolderShareSuccess>());

        final body = w.shares.moveOutBodies.single;
        expect(body['file_id'], file.item.id);
        expect(body['destination_folder_id'], uuid(0xD0));
        expect(
          body.containsKey('entries') || body.containsKey('member_keys'),
          isFalse,
          reason:
              'move-out carries no key wraps — the owner already holds them',
        );

        final ok = fx.owner.crypto.verifyAuditEvent(
          input: AuditEventSigInput(
            senderId: fx.owner.userId,
            recipientId: null,
            fileId: file.item.id,
            action: AuditEventAction.sharedFolderMoveOut,
            shareRoleBefore: null,
            shareRoleAfter: null,
            timestamp: body['timestamp'] as int,
          ),
          signature: body['event_signature'] as String,
          senderPubkey: fx.owner.pubkey,
        );
        expect(ok, isTrue);
      },
    );

    test(
      'omits destination_folder_id when moving out to the drive root',
      () async {
        final file = ownedNode(fx.owner, uuid(0xC4));
        final w = wire(
          signer: fx.owner,
          roster: fx.validRoster(),
          tree: const {},
        );

        await w.c
            .read(moveIntoSharedCascadeProvider)
            .moveOutOfShared(file: file.item, destinationFolderId: null);

        final body = w.shares.moveOutBodies.single;
        expect(
          body.containsKey('destination_folder_id'),
          isFalse,
          reason:
              'a null destination is the root; the key is dropped from the body',
        );
      },
    );

    test('a non-owner is refused without hitting the endpoint', () async {
      // The file row claims a non-owner caller; move-out is owner-only.
      final notOwned = FileItem(
        id: uuid(0xC4),
        encryptedName: 'e',
        mime: 'text/plain',
        isOwner: false,
      );
      final w = wire(
        signer: fx.owner,
        roster: fx.validRoster(),
        tree: const {},
      );

      final outcome = await w.c
          .read(moveIntoSharedCascadeProvider)
          .moveOutOfShared(file: notOwned, destinationFolderId: null);

      expect(outcome, isA<FolderShareFailure>());
      expect(w.shares.moveOutBodies, isEmpty);
    });
  });
}
