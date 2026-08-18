import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/shares_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/services/shared_folder_upload.dart';
import 'package:hoodik_app/features/shares/services/folder_membership.dart';
import 'package:hoodik_app/features/shares/services/trusted_fingerprint_dao.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../../features/shares/services/folder_membership_test_kit.dart';

/// Mock [SharesClient] that captures the posted body and scripts the
/// `getFolderMembers` / `uploadMultikey` responses. `membersQueue` is drained
/// one entry per call so a 409-then-success path can serve a fresh roster on
/// the retry; `uploadResults` likewise lets a test throw on the first POST and
/// return on the second.
class _MockSharesClient extends Fake implements SharesClient {
  _MockSharesClient({required this.membersQueue, required this.uploadResults});

  final List<FolderMembersResponse> membersQueue;
  final List<Object> uploadResults;

  final List<Map<String, dynamic>> postedBodies = [];
  int membersFetches = 0;

  @override
  Future<FolderMembersResponse> getFolderMembers(String folderId) async {
    membersFetches += 1;
    return membersQueue.removeAt(0);
  }

  @override
  Future<String> uploadMultikey(Map<String, dynamic> body) async {
    postedBodies.add(body);
    final next = uploadResults.removeAt(0);
    if (next is Exception) throw next;
    return next as String;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late MembershipFixture fx;
  final fileKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
  const newFileId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  const folderId =
      'f0f0f0f0-f0f0-f0f0-f0f0-f0f0f0f0f0f0'; // matches uuid(0xF0) in the kit

  setUp(() => fx = MembershipFixture());
  tearDown(() async => await fx.dispose());

  SharedFolderUpload build(_MockSharesClient client) {
    return SharedFolderUpload(
      client: client,
      folderMembership: fx.membership,
      shareCrypto: fx.owner.crypto,
      callerUserId: fx.owner.userId,
    );
  }

  Future<String> run(
    SharedFolderUpload uploader, {
    List<String>? searchTokensRoot,
    List<String>? searchTokensFile,
    String? cipher,
  }) {
    return uploader.uploadIntoSharedFolder(
      folderId: folderId,
      newFileId: newFileId,
      fileKey: fileKey,
      nameHash: 'name-hash',
      encryptedName: 'enc-name',
      mime: 'text/plain',
      chunks: 3,
      size: 4096,
      sha256: 'deadbeef',
      cipher: cipher,
      searchTokensRoot: searchTokensRoot,
      searchTokensFile: searchTokensFile,
    );
  }

  /// Unwrap one member-key entry with that party's private key, asserting it
  /// recovers the exact [fileKey] the uploader wrapped.
  void expectUnwrapsToFileKey(Map<String, dynamic> entry, Party party) {
    final fileCrypto = FileCrypto(privateKeyPem: party.keyPair.privateKeyPem);
    final unwrapped = fileCrypto.decryptFileKey(
      entry['encrypted_key'] as String,
    );
    expect(unwrapped, fileKey);
  }

  test(
    'posts one wrapped key per member, each unwrapping to the file key',
    () async {
      final client = _MockSharesClient(
        membersQueue: [fx.validRoster()],
        uploadResults: ['server-file-id'],
      );

      final result = await run(build(client));

      expect(result, 'server-file-id');
      final body = client.postedBodies.single;
      expect(body['new_file_id'], newFileId);
      expect(body['parent_file_id'], folderId);

      final keys = (body['member_keys'] as List).cast<Map<String, dynamic>>();
      expect(keys.length, 3);
      final byUser = {for (final k in keys) k['user_id'] as String: k};
      expect(byUser.keys, {fx.owner.userId, fx.alice.userId, fx.bob.userId});
      expectUnwrapsToFileKey(byUser[fx.owner.userId]!, fx.owner);
      expectUnwrapsToFileKey(byUser[fx.alice.userId]!, fx.alice);
      expectUnwrapsToFileKey(byUser[fx.bob.userId]!, fx.bob);
    },
  );

  test(
    'snapshot echoes the roster signature, and the event signature verifies',
    () async {
      final roster = fx.validRoster();
      final client = _MockSharesClient(
        membersQueue: [roster],
        uploadResults: ['server-file-id'],
      );

      await run(build(client));
      final body = client.postedBodies.single;

      final snapshot = body['members_list_snapshot'] as Map<String, dynamic>;
      expect(snapshot['members_signed_at'], roster.membersSignedAt);
      expect(snapshot['members_list_signature'], roster.membersListSignature);

      final ok = fx.owner.crypto.verifyAuditEvent(
        input: AuditEventSigInput(
          senderId: fx.owner.userId,
          recipientId: null,
          fileId: newFileId,
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

  test('is_owner_of_file is true only for the caller', () async {
    final client = _MockSharesClient(
      membersQueue: [fx.validRoster()],
      uploadResults: ['server-file-id'],
    );

    await run(build(client));
    final keys = (client.postedBodies.single['member_keys'] as List)
        .cast<Map<String, dynamic>>();
    for (final k in keys) {
      final isOwner = k['is_owner_of_file'] as bool;
      expect(isOwner, k['user_id'] == fx.owner.userId);
    }
  });

  test('omits null optionals but includes provided ones', () async {
    final client = _MockSharesClient(
      membersQueue: [fx.validRoster()],
      uploadResults: ['server-file-id'],
    );

    await run(
      build(client),
      searchTokensRoot: ['t1', 't2'],
      cipher: 'aegis128l',
    );
    final body = client.postedBodies.single;

    expect(body.containsKey('encrypted_thumbnail'), isFalse);
    expect(body.containsKey('file_modified_at'), isFalse);
    expect(body['cipher'], 'aegis128l');
    expect(body['search_tokens_root'], ['t1', 't2']);
  });

  test('409 refreshes the roster and retries once, then succeeds', () async {
    final fresh = fx.validRoster();
    final client = _MockSharesClient(
      membersQueue: [fx.validRoster()],
      uploadResults: [ShareMembershipChangedError(fresh), 'retried-file-id'],
    );

    final result = await run(build(client));

    expect(result, 'retried-file-id');
    expect(client.postedBodies.length, 2);
    // The fresh roster came from the conflict body, not a second fetch.
    expect(client.membersFetches, 1);
  });

  test('a second 409 propagates', () async {
    final client = _MockSharesClient(
      membersQueue: [fx.validRoster()],
      uploadResults: [
        ShareMembershipChangedError(fx.validRoster()),
        ShareMembershipChangedError(fx.validRoster()),
      ],
    );

    await expectLater(
      run(build(client)),
      throwsA(isA<ShareMembershipChangedError>()),
    );
    expect(client.postedBodies.length, 2);
  });

  test('a tampered roster propagates with no upload', () async {
    final tampered = _rosterWithUnsignedList(fx);
    final client = _MockSharesClient(
      membersQueue: [tampered],
      uploadResults: const [],
    );

    await expectLater(
      run(build(client)),
      throwsA(isA<FolderMemberListInvalid>()),
    );
    expect(client.postedBodies, isEmpty);
  });

  test('a changed fingerprint propagates with no upload', () async {
    await fx.db.upsertTrustedFingerprint(
      ownerUserId: fx.owner.userId,
      userId: fx.alice.userId,
      fingerprint: fx.bob.fingerprint, // stale, differs from alice's
    );
    final client = _MockSharesClient(
      membersQueue: [fx.validRoster()],
      uploadResults: const [],
    );

    await expectLater(
      run(build(client)),
      throwsA(isA<FolderMemberFingerprintChanged>()),
    );
    expect(client.postedBodies, isEmpty);
  });
}

/// A roster whose canonical member-list signature is replaced by a signature
/// over a *different* list (owner-only), so the verifier's list-signature check
/// fails the way server tampering would.
FolderMembersResponse _rosterWithUnsignedList(MembershipFixture fx) {
  final valid = fx.validRoster();
  const crypto = CryptoService();
  final wrongList = FolderMemberList(
    folderId: valid.folderId,
    folderOwnerId: valid.folderOwnerId,
    members: [
      FolderMemberListMember(
        userId: fx.owner.userId,
        pubkeyFingerprintHex: crypto.rsaFingerprintPublic(
          publicKeyPem: fx.owner.pubkey,
        ),
        shareRole: ShareRole.reader,
        isOwner: true,
        signedByUserId: fx.owner.userId,
      ),
    ],
    membersSignedAt: valid.membersSignedAt ?? 0,
  );
  final wrongSig = fx.owner.crypto.signFolderMemberList(wrongList);
  return FolderMembersResponse(
    folderId: valid.folderId,
    folderOwnerId: valid.folderOwnerId,
    folderOwnerPubkeyFingerprint: valid.folderOwnerPubkeyFingerprint,
    signatureAlgorithm: valid.signatureAlgorithm,
    members: valid.members,
    membersSignedAt: valid.membersSignedAt,
    membersListSignature: wrongSig.signature,
    membersListSignedByUserId: valid.membersListSignedByUserId,
  );
}
