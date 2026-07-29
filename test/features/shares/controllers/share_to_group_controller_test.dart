import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/shares/controllers/share_to_group_controller.dart';
import 'package:hoodik_app/features/shares/services/trusted_fingerprint_dao.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../../../helpers/fakes.dart';
import '../services/folder_membership_test_kit.dart';

const _crypto = CryptoService();

/// Serves the group roster the fan-out reads.
class _Groups extends Fake implements SharesGroupsClient {
  _Groups(this.roster);

  List<GroupMemberWithKey> roster;
  int rosterReads = 0;

  @override
  Future<List<GroupMemberWithKey>> groupMembers(String groupId) async {
    rosterReads++;
    return roster;
  }
}

/// Records every single-share envelope the fan-out posts (one per recipient)
/// and serves the existing-role probe each single-share runs first.
class _Shares extends Fake implements SharesClient {
  _Shares(this.rostersByFolderId);

  final Map<String, FolderMembersResponse> rostersByFolderId;
  final createBodies = <Map<String, dynamic>>[];

  @override
  Future<List<AppShare>> createShare(Map<String, dynamic> envelope) async {
    createBodies.add(envelope);
    return const [];
  }

  @override
  Future<List<AppShare>> getShareRecipients(String fileId) async => const [];

  @override
  Future<FolderMembersResponse> getFolderMembers(String folderId) async {
    final roster = rostersByFolderId[folderId];
    if (roster == null) throw StateError('no roster for $folderId');
    return roster;
  }
}

class _Files extends Fake implements FilesClient {
  _Files(this.childrenByDir);

  final Map<String, List<FileItem>> childrenByDir;

  @override
  Future<StorageResponse> listFiles({
    String? dirId,
    bool? editable,
    String? orderBy,
    String? order,
  }) async {
    return StorageResponse(children: childrenByDir[dirId] ?? const []);
  }
}

class _Api extends Fake implements ApiClient {
  _Api(this._shares, this._groups, this._files);

  final SharesClient _shares;
  final SharesGroupsClient _groups;
  final FilesClient _files;

  @override
  SharesClient get shares => _shares;
  @override
  SharesGroupsClient get shareGroups => _groups;
  @override
  FilesClient get files => _files;
}

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

  /// Wrap a fresh file key under [owner]'s own pubkey — the form a file the
  /// caller owns carries in its `encrypted_key`.
  ({String wrap, List<int> key}) ownWrap(Party owner) {
    final key = _crypto.generateSymmetricKey();
    final wrap = FileCrypto(
      privateKeyPem: owner.keyPair.privateKeyPem,
    ).encryptFileKey(fileKey: key, publicKeyPem: owner.pubkey);
    return (wrap: wrap, key: key);
  }

  GroupMemberWithKey memberKey(
    Party p, {
    GroupRole role = GroupRole.reader,
    String? fingerprint,
  }) => GroupMemberWithKey(
    userId: p.userId,
    email: '${p.userId}@example.test',
    pubkey: p.pubkey,
    fingerprint: fingerprint ?? p.fingerprint,
    groupRole: role,
  );

  ({_Groups groups, _Shares shares, _Files files}) wire({
    required Party signer,
    required List<GroupMemberWithKey> roster,
    Map<String, FolderMembersResponse> rosters = const {},
    Map<String, List<FileItem>> children = const {},
  }) {
    final groups = _Groups(roster);
    final shares = _Shares(rosters);
    final files = _Files(children);
    container = ProviderContainer(
      overrides: [
        decryptedPrivateKeyProvider.overrideWith(
          (ref) => signer.keyPair.privateKeyPem,
        ),
        activeServerUserIdProvider.overrideWithValue(signer.userId),
        apiClientProvider.overrideWithValue(_Api(shares, groups, files)),
        databaseProvider.overrideWithValue(db),
        // The single-share path the fan-out reuses reads the cached file key
        // from `filesNotifierProvider`; stub its platform deps so the host
        // test never hits a channel.
        connectivityProvider.overrideWith(
          (ref) => FakeConnectivityService(fakeOnline: true),
        ),
        workerManagerProvider.overrideWithValue(null),
      ],
    );
    return (groups: groups, shares: shares, files: files);
  }

  FileItem ownedFile(String id, String wrap) => FileItem(
    id: id,
    encryptedName: 'e',
    mime: 'text/plain',
    encryptedKey: wrap,
  );

  /// A row the caller holds as a co-owner rather than owns: [wrap] is the file
  /// key under the caller's own pubkey, and [ownerEmail] names the true owner so
  /// the fan-out can drop them.
  FileItem coOwnedFile(String id, String wrap, String ownerEmail) => FileItem(
    id: id,
    encryptedName: 'e',
    mime: 'text/plain',
    encryptedKey: wrap,
    isOwner: false,
    shareRole: ShareRole.coOwner,
    ownerEmail: ownerEmail,
  );

  String emailOf(Party p) => '${p.userId}@example.test';

  String groupId() => uuid(0x6E);

  group('shareToGroup fan-out', () {
    test('fans one file out to every member except the caller; each member '
        'gets a single-share whose wrap unwraps to the file key', () async {
      final file = ownWrap(fx.owner);
      // Roster carries the caller (owner) plus alice + bob — the caller must be
      // dropped so the share-to-self/owner-row rejection never fires.
      final w = wire(
        signer: fx.owner,
        roster: [
          memberKey(fx.owner),
          memberKey(fx.alice),
          memberKey(fx.bob, role: GroupRole.editor),
        ],
      );

      final outcome = await container
          .read(shareToGroupControllerProvider)
          .shareToGroup(
            groupId: groupId(),
            file: ownedFile(uuid(0xF1), file.wrap),
            role: ShareRole.editor,
          );
      expect(outcome, isA<FolderShareSuccess>());

      // One single-share per remaining recipient (alice, bob) — never the
      // caller.
      expect(w.shares.createBodies, hasLength(2));
      for (final recipient in [fx.alice, fx.bob]) {
        final body = w.shares.createBodies.firstWhere((b) {
          final entry = (b['entries'] as List).single as Map;
          final wrap = entry['encrypted_key'] as String;
          try {
            return _crypto.rsaDecrypt(
                  ciphertextBase64: wrap,
                  privateKeyPem: recipient.keyPair.privateKeyPem,
                ) ==
                _hex(file.key);
          } catch (_) {
            return false;
          }
        });
        final entry = (body['entries'] as List).single as Map;
        expect(entry['file_id'], uuid(0xF1));
      }

      // Trust-on-first-use recorded both recipients on success.
      for (final m in [fx.alice, fx.bob]) {
        final trusted = await db.getTrustedFingerprint(
          fx.owner.userId,
          m.userId,
        );
        expect(trusted?.fingerprint, m.fingerprint);
      }
    });

    test('reports per-recipient progress as done/total', () async {
      final file = ownWrap(fx.owner);
      final w = wire(
        signer: fx.owner,
        roster: [memberKey(fx.owner), memberKey(fx.alice), memberKey(fx.bob)],
      );

      final updates = <({int done, int total})>[];
      await container
          .read(shareToGroupControllerProvider)
          .shareToGroup(
            groupId: groupId(),
            file: ownedFile(uuid(0xF1), file.wrap),
            role: ShareRole.reader,
            onProgress: (done, total) =>
                updates.add((done: done, total: total)),
          );

      // total = 2 (alice + bob, caller excluded); progress walks 0 → 2.
      expect(updates.first, (done: 0, total: 2));
      expect(updates.last, (done: 2, total: 2));
      expect(w.shares.createBodies, hasLength(2));
    });

    test('a folder fans out via the folder single-share path: every recipient '
        'gets the whole subtree and a member-list signature', () async {
      final folderWrap = ownWrap(fx.owner);
      final childWrap = ownWrap(fx.owner);
      final folder = FileItem(
        id: fx.folderId,
        encryptedName: 'e',
        mime: 'dir',
        encryptedKey: folderWrap.wrap,
      );
      final w = wire(
        signer: fx.owner,
        roster: [memberKey(fx.owner), memberKey(fx.alice), memberKey(fx.bob)],
        rosters: {fx.folderId: fx.buildOwnerRoster(const [])},
        children: {
          fx.folderId: [ownedFile(uuid(0xC1), childWrap.wrap)],
        },
      );

      final outcome = await container
          .read(shareToGroupControllerProvider)
          .shareToGroup(
            groupId: groupId(),
            file: folder,
            role: ShareRole.editor,
          );
      expect(outcome, isA<FolderShareSuccess>());

      expect(w.shares.createBodies, hasLength(2));
      for (final body in w.shares.createBodies) {
        // Subtree = folder + child.
        final entries = (body['entries'] as List).cast<Map>();
        expect(entries.map((e) => e['file_id']).toSet(), {
          fx.folderId,
          uuid(0xC1),
        });
        // Folder shares carry the post-share member-list signature.
        expect(body.containsKey('members_list_signature'), isTrue);
      }
    });

    test('a roster key/fingerprint mismatch hard-stops before any wrap with '
        'zero shares', () async {
      final file = ownWrap(fx.owner);
      // Alice's row claims bob's fingerprint — the returned pubkey does not
      // hash to the claimed fingerprint, so the fan-out must refuse.
      final w = wire(
        signer: fx.owner,
        roster: [
          memberKey(fx.owner),
          memberKey(fx.alice, fingerprint: fx.bob.fingerprint),
        ],
      );

      final outcome = await container
          .read(shareToGroupControllerProvider)
          .shareToGroup(
            groupId: groupId(),
            file: ownedFile(uuid(0xF1), file.wrap),
            role: ShareRole.reader,
          );

      expect(outcome, isA<FolderShareFailure>());
      expect(w.shares.createBodies, isEmpty);
    });

    test('a changed trusted fingerprint hard-stops that fan-out with zero '
        'shares', () async {
      final file = ownWrap(fx.owner);
      // Alice was previously trusted at a DIFFERENT fingerprint; her current
      // key no longer matches, so the reconciliation hard-stops before any
      // wrap — never silently wrapping under a key the caller didn't verify.
      await db.upsertTrustedFingerprint(
        ownerUserId: fx.owner.userId,
        userId: fx.alice.userId,
        fingerprint: fx.bob.fingerprint,
      );
      final w = wire(
        signer: fx.owner,
        roster: [memberKey(fx.owner), memberKey(fx.alice)],
      );

      final outcome = await container
          .read(shareToGroupControllerProvider)
          .shareToGroup(
            groupId: groupId(),
            file: ownedFile(uuid(0xF1), file.wrap),
            role: ShareRole.reader,
          );

      expect(outcome, isA<FolderShareFailure>());
      expect(w.shares.createBodies, isEmpty);
    });

    test(
      'a roster of only the caller is a failure, not a silent no-op',
      () async {
        final file = ownWrap(fx.owner);
        final w = wire(signer: fx.owner, roster: [memberKey(fx.owner)]);

        final outcome = await container
            .read(shareToGroupControllerProvider)
            .shareToGroup(
              groupId: groupId(),
              file: ownedFile(uuid(0xF1), file.wrap),
              role: ShareRole.reader,
            );

        expect(outcome, isA<FolderShareFailure>());
        expect((outcome as FolderShareFailure).message, isNotEmpty);
        expect(w.shares.createBodies, isEmpty);
      },
    );

    test('a co-owner re-sharing a file whose owner is in the roster drops the '
        'owner from the fan-out — no share back to the owner', () async {
      // Caller (alice) is a co-owner, not the owner: her row carries the file
      // key under her own key, and the owner sits in the group roster. The
      // owner already holds the file, so the fan-out must skip them and reach
      // only bob.
      final file = ownWrap(fx.alice);
      final w = wire(
        signer: fx.alice,
        roster: [memberKey(fx.alice), memberKey(fx.owner), memberKey(fx.bob)],
      );

      final outcome = await container
          .read(shareToGroupControllerProvider)
          .shareToGroup(
            groupId: groupId(),
            file: coOwnedFile(uuid(0xF1), file.wrap, emailOf(fx.owner)),
            role: ShareRole.reader,
          );

      expect(outcome, isA<FolderShareSuccess>());
      expect(w.shares.createBodies, hasLength(1));
      final entry =
          (w.shares.createBodies.single['entries'] as List).single as Map;
      final wrap = entry['encrypted_key'] as String;
      expect(
        _crypto.rsaDecrypt(
          ciphertextBase64: wrap,
          privateKeyPem: fx.bob.keyPair.privateKeyPem,
        ),
        _hex(file.key),
      );
    });

    test('a previously-seen matching fingerprint passes the TOFU check and '
        'shares', () async {
      final file = ownWrap(fx.owner);
      await db.upsertTrustedFingerprint(
        ownerUserId: fx.owner.userId,
        userId: fx.alice.userId,
        fingerprint: fx.alice.fingerprint,
      );
      final w = wire(
        signer: fx.owner,
        roster: [memberKey(fx.owner), memberKey(fx.alice)],
      );

      final outcome = await container
          .read(shareToGroupControllerProvider)
          .shareToGroup(
            groupId: groupId(),
            file: ownedFile(uuid(0xF1), file.wrap),
            role: ShareRole.reader,
          );

      expect(outcome, isA<FolderShareSuccess>());
      expect(w.shares.createBodies, hasLength(1));
    });
  });
}

String _hex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
