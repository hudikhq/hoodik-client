import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/shares/providers/folder_members_notifier.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../services/folder_membership_test_kit.dart';

/// Flip one byte of a base64 blob so it decodes to a different value — used to
/// corrupt a signature without changing its length or base64 validity.
String _flipBase64(String b64) {
  final bytes = Uint8List.fromList(base64.decode(b64));
  bytes[0] ^= 0xff;
  return base64.encode(bytes);
}

class _RosterSharesClient extends Fake implements SharesClient {
  _RosterSharesClient(this.roster);
  FolderMembersResponse roster;
  @override
  Future<FolderMembersResponse> getFolderMembers(String folderId) async =>
      roster;
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
  ProviderContainer? container;

  setUp(() => fx = MembershipFixture());
  tearDown(() {
    container?.dispose();
    return fx.dispose();
  });

  ProviderContainer wire(FolderMembersResponse roster, {Party? caller}) {
    container = ProviderContainer(
      overrides: [
        decryptedPrivateKeyProvider.overrideWith(
          (ref) => (caller ?? fx.owner).keyPair.privateKeyPem,
        ),
        activeServerUserIdProvider.overrideWithValue(
          (caller ?? fx.owner).userId,
        ),
        apiClientProvider.overrideWithValue(
          _FakeApiClient(_RosterSharesClient(roster)),
        ),
        databaseProvider.overrideWithValue(fx.db),
      ],
    );
    return container!;
  }

  test('a verified roster marks every member verified', () async {
    final c = wire(fx.validRoster());
    final state = await c.read(
      folderMembersNotifierProvider(fx.folderId).future,
    );
    expect(
      state.signatureStatus.values.every(
        (s) => s == MemberSignatureStatus.verified,
      ),
      isTrue,
    );
    expect(state.callerCanReshare, isTrue, reason: 'owner can reshare');
  });

  test('a roster with no list signature is classified legacy', () async {
    final base = fx.validRoster();
    final unsigned = FolderMembersResponse(
      folderId: base.folderId,
      folderOwnerId: base.folderOwnerId,
      folderOwnerPubkeyFingerprint: base.folderOwnerPubkeyFingerprint,
      signatureAlgorithm: base.signatureAlgorithm,
      members: base.members,
      membersSignedAt: null,
      membersListSignature: null,
      membersListSignedByUserId: null,
    );
    final c = wire(unsigned);
    final state = await c.read(
      folderMembersNotifierProvider(fx.folderId).future,
    );
    expect(
      state.signatureStatus.values.every(
        (s) => s == MemberSignatureStatus.legacy,
      ),
      isTrue,
    );
  });

  test('an invalid per-member signature pins failed to that one row', () async {
    // alice's fingerprint still matches her pubkey (so the list signature, which
    // covers fingerprints, still verifies), but her per-member σ is corrupted.
    // The verifier throws `memberSignatureInvalid` carrying her user_id, so she
    // alone is marked failed while everyone else stays verified.
    final base = fx.validRoster();
    final aliceSig = base.members
        .firstWhere((m) => m.userId == fx.alice.userId)
        .memberSignature!;
    final tampered = <FolderMember>[
      for (final m in base.members)
        if (m.userId == fx.alice.userId)
          FolderMember(
            userId: m.userId,
            email: m.email,
            pubkey: m.pubkey,
            pubkeyFingerprint: m.pubkeyFingerprint,
            shareRole: m.shareRole,
            isOwner: m.isOwner,
            addedAt: m.addedAt,
            signedByUserId: m.signedByUserId,
            memberSignature: _flipBase64(aliceSig),
          )
        else
          m,
    ];
    final response = FolderMembersResponse(
      folderId: base.folderId,
      folderOwnerId: base.folderOwnerId,
      folderOwnerPubkeyFingerprint: base.folderOwnerPubkeyFingerprint,
      signatureAlgorithm: base.signatureAlgorithm,
      members: tampered,
      membersSignedAt: base.membersSignedAt,
      membersListSignature: base.membersListSignature,
      membersListSignedByUserId: base.membersListSignedByUserId,
    );
    final c = wire(response);
    final state = await c.read(
      folderMembersNotifierProvider(fx.folderId).future,
    );
    expect(
      state.signatureStatus[fx.alice.userId],
      MemberSignatureStatus.failed,
    );
    expect(
      state.signatureStatus[fx.owner.userId],
      MemberSignatureStatus.verified,
    );
  });

  test('a reader caller cannot reshare', () async {
    final roster = fx.buildOwnerRoster([
      (party: fx.alice, role: ShareRole.reader),
    ]);
    final c = wire(roster, caller: fx.alice);
    final state = await c.read(
      folderMembersNotifierProvider(fx.folderId).future,
    );
    expect(state.callerCanReshare, isFalse);
  });

  test('a co-owner caller can reshare', () async {
    final roster = fx.buildOwnerRoster([
      (party: fx.alice, role: ShareRole.coOwner),
    ]);
    final c = wire(roster, caller: fx.alice);
    final state = await c.read(
      folderMembersNotifierProvider(fx.folderId).future,
    );
    expect(state.callerCanReshare, isTrue);
  });
}
