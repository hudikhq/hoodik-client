import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/shares/controllers/folder_relocation_controller.dart';
import 'package:hoodik_app/features/shares/controllers/folder_share_controller.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../services/folder_membership_test_kit.dart';

class _CapturingSharesClient extends Fake implements SharesClient {
  _CapturingSharesClient({required this.roster, required this.moveResults});

  FolderMembersResponse roster;
  final List<Object> moveResults;

  int membersFetches = 0;
  final List<Map<String, dynamic>> moveBodies = [];
  (String, Map<String, dynamic>)? evictArgs;

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
  Future<String> evictFromFolder(
    String fileId,
    Map<String, dynamic> body,
  ) async {
    evictArgs = (fileId, body);
    return fileId;
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._shares);
  final SharesClient _shares;
  @override
  SharesClient get shares => _shares;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late MembershipFixture fx;
  late AppDatabase db;
  late ProviderContainer container;
  final fileKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 7));

  setUp(() {
    fx = MembershipFixture();
    db = fx.db;
  });
  tearDown(() {
    container.dispose();
    return fx.dispose();
  });

  ({_CapturingSharesClient shares, ProviderContainer container}) wire({
    required Party signer,
    required FolderMembersResponse roster,
    List<Object>? moveResults,
  }) {
    final shares = _CapturingSharesClient(
      roster: roster,
      moveResults: moveResults ?? ['moved-file-id'],
    );
    container = ProviderContainer(
      overrides: [
        decryptedPrivateKeyProvider.overrideWith(
          (ref) => signer.keyPair.privateKeyPem,
        ),
        activeServerUserIdProvider.overrideWithValue(signer.userId),
        apiClientProvider.overrideWithValue(_FakeApiClient(shares)),
        databaseProvider.overrideWithValue(db),
      ],
    );
    return (shares: shares, container: container);
  }

  /// A file the [owner] holds: its `encrypted_key` is [fileKey] wrapped under
  /// the owner's own pubkey, the form `move-into-shared` unwraps and re-wraps.
  FileItem ownedFile(Party owner) {
    final wrap = FileCrypto(
      privateKeyPem: owner.keyPair.privateKeyPem,
    ).encryptFileKey(fileKey: fileKey, publicKeyPem: owner.pubkey);
    return FileItem(
      id: '00000000-0000-0000-0000-0000000000c4',
      encryptedName: 'e',
      encryptedKey: wrap,
      mime: 'text/plain',
    );
  }

  void expectUnwrapsToFileKey(Map<String, dynamic> entry, Party party) {
    final unwrapped = FileCrypto(
      privateKeyPem: party.keyPair.privateKeyPem,
    ).decryptFileKey(entry['encrypted_key'] as String);
    expect(unwrapped, fileKey);
  }

  group('moveIntoShared', () {
    test('wraps the file key for every destination member', () async {
      final roster = fx.validRoster();
      final w = wire(signer: fx.owner, roster: roster);

      final outcome = await w.container
          .read(folderRelocationControllerProvider)
          .moveIntoShared(
            file: ownedFile(fx.owner),
            destinationFolderId: roster.folderId,
          );
      expect(outcome, isA<FolderShareSuccess>());

      final body = w.shares.moveBodies.single;
      expect(body['file_id'], '00000000-0000-0000-0000-0000000000c4');
      expect(body['destination_folder_id'], roster.folderId);

      final keys = (body['member_keys'] as List).cast<Map<String, dynamic>>();
      final byUser = {for (final k in keys) k['user_id'] as String: k};
      expect(byUser.keys, {fx.owner.userId, fx.alice.userId, fx.bob.userId});
      expectUnwrapsToFileKey(byUser[fx.owner.userId]!, fx.owner);
      expectUnwrapsToFileKey(byUser[fx.alice.userId]!, fx.alice);
      expectUnwrapsToFileKey(byUser[fx.bob.userId]!, fx.bob);

      // is_owner_of_file marks only the caller (the file owner).
      for (final k in keys) {
        expect(k['is_owner_of_file'], k['user_id'] == fx.owner.userId);
      }
    });

    test(
      'echoes the roster snapshot and signs a verifiable audit event',
      () async {
        final roster = fx.validRoster();
        final w = wire(signer: fx.owner, roster: roster);

        await w.container
            .read(folderRelocationControllerProvider)
            .moveIntoShared(
              file: ownedFile(fx.owner),
              destinationFolderId: roster.folderId,
            );
        final body = w.shares.moveBodies.single;

        final snapshot = body['members_list_snapshot'] as Map<String, dynamic>;
        expect(snapshot['members_signed_at'], roster.membersSignedAt);
        expect(snapshot['members_list_signature'], roster.membersListSignature);

        final ok = fx.owner.crypto.verifyAuditEvent(
          input: AuditEventSigInput(
            senderId: fx.owner.userId,
            recipientId: null,
            fileId: '00000000-0000-0000-0000-0000000000c4',
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

    test('409 refreshes the roster and retries once, then succeeds', () async {
      final roster = fx.validRoster();
      final w = wire(
        signer: fx.owner,
        roster: roster,
        moveResults: [
          ShareMembershipChangedError(fx.validRoster()),
          'moved-file-id',
        ],
      );

      final outcome = await w.container
          .read(folderRelocationControllerProvider)
          .moveIntoShared(
            file: ownedFile(fx.owner),
            destinationFolderId: roster.folderId,
          );

      expect(outcome, isA<FolderShareSuccess>());
      expect(w.shares.moveBodies.length, 2);
    });

    test('a second 409 surfaces as a failure', () async {
      final roster = fx.validRoster();
      final w = wire(
        signer: fx.owner,
        roster: roster,
        moveResults: [
          ShareMembershipChangedError(fx.validRoster()),
          ShareMembershipChangedError(fx.validRoster()),
        ],
      );

      final outcome = await w.container
          .read(folderRelocationControllerProvider)
          .moveIntoShared(
            file: ownedFile(fx.owner),
            destinationFolderId: roster.folderId,
          );

      expect(outcome, isA<FolderShareFailure>());
      expect(w.shares.moveBodies.length, 2);
    });

    test('a tampered roster fails with no move', () async {
      final tampered = _signedByNonMember(fx.validRoster());
      final w = wire(signer: fx.owner, roster: tampered);

      final outcome = await w.container
          .read(folderRelocationControllerProvider)
          .moveIntoShared(
            file: ownedFile(fx.owner),
            destinationFolderId: tampered.folderId,
          );

      expect(outcome, isA<FolderShareFailure>());
      expect(w.shares.moveBodies, isEmpty);
    });
  });

  group('evictFromFolder', () {
    test('signs a verifiable evict event naming the file owner', () async {
      final w = wire(signer: fx.owner, roster: fx.validRoster());

      final outcome = await w.container
          .read(folderRelocationControllerProvider)
          .evictFromFolder(
            fileId: '00000000-0000-0000-0000-0000000000c4',
            fileOwnerUserId: fx.alice.userId,
          );
      expect(outcome, isA<FolderShareSuccess>());

      final (fileId, body) = w.shares.evictArgs!;
      expect(fileId, '00000000-0000-0000-0000-0000000000c4');

      final ok = fx.owner.crypto.verifyAuditEvent(
        input: AuditEventSigInput(
          senderId: fx.owner.userId,
          recipientId: fx.alice.userId,
          fileId: '00000000-0000-0000-0000-0000000000c4',
          action: AuditEventAction.sharedFolderEvict,
          shareRoleBefore: null,
          shareRoleAfter: null,
          timestamp: body['timestamp'] as int,
        ),
        signature: body['event_signature'] as String,
        senderPubkey: fx.owner.pubkey,
      );
      expect(ok, isTrue);
    });
  });
}

/// A roster whose list signature claims to be signed by someone who isn't a
/// member, so the verifier rejects it as an unauthorized signer before any key
/// is wrapped — the cheapest tamper that exercises the hard-stop path.
FolderMembersResponse _signedByNonMember(FolderMembersResponse valid) {
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
