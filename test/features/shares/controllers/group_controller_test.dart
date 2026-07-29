import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/shares/controllers/group_controller.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../services/folder_membership_test_kit.dart';

/// Captures the add-member body the controller posts so the test can assert it
/// carries only the plain roster fields — no wraps, no signatures.
class _CapturingGroupsClient extends Fake implements SharesGroupsClient {
  final bodies = <AddGroupMemberBody>[];
  bool throwOnAdd = false;

  @override
  Future<void> addGroupMember(String groupId, AddGroupMemberBody body) async {
    if (throwOnAdd) throw Exception('server rejected');
    bodies.add(body);
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._groups);

  final SharesGroupsClient _groups;

  @override
  SharesGroupsClient get shareGroups => _groups;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late MembershipFixture fx;
  late AppDatabase db;
  late ProviderContainer container;
  late _CapturingGroupsClient groups;

  setUp(() {
    fx = MembershipFixture();
    db = fx.db;
    groups = _CapturingGroupsClient();
    container = ProviderContainer(
      overrides: [
        decryptedPrivateKeyProvider.overrideWith(
          (ref) => fx.owner.keyPair.privateKeyPem,
        ),
        activeServerUserIdProvider.overrideWithValue(fx.owner.userId),
        apiClientProvider.overrideWithValue(_FakeApiClient(groups)),
        databaseProvider.overrideWithValue(db),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    return fx.dispose();
  });

  DiscoveredUser discovered(Party party) => DiscoveredUser(
    userId: party.userId,
    email: '${party.userId}@example.test',
    pubkey: party.pubkey,
    fingerprint: party.fingerprint,
  );

  String groupId() => uuid(0x6E);

  group('addMember', () {
    test('posts only the plain roster body — identity, group role, and a '
        'timestamp + nonce; no wraps or signatures', () async {
      final outcome = await container
          .read(groupControllerProvider)
          .addMember(
            groupId: groupId(),
            recipient: discovered(fx.alice),
            groupRole: GroupRole.editor,
          );
      expect(outcome, isA<FolderShareSuccess>());

      final body = groups.bodies.single;
      expect(body.userId, fx.alice.userId);
      expect(body.pubkeyFingerprint, fx.alice.fingerprint);
      expect(body.groupRole, GroupRole.editor);
      expect(body.nonce, isNotEmpty);
      expect(body.timestamp, greaterThan(0));

      // The body serializes to exactly the five wire fields the server expects
      // — nothing crypto-shaped leaks through.
      expect(body.toJson().keys.toSet(), {
        'user_id',
        'pubkey_fingerprint',
        'group_role',
        'timestamp',
        'nonce',
      });
    });

    test('two sequential adds for the same recipient carry different nonces — '
        'the replay guard is fresh per call', () async {
      final controller = container.read(groupControllerProvider);
      await controller.addMember(
        groupId: groupId(),
        recipient: discovered(fx.alice),
        groupRole: GroupRole.reader,
      );
      await controller.addMember(
        groupId: groupId(),
        recipient: discovered(fx.alice),
        groupRole: GroupRole.reader,
      );

      expect(groups.bodies, hasLength(2));
      expect(groups.bodies[0].nonce, isNot(groups.bodies[1].nonce));
    });

    test('refuses to add the caller to their own group', () async {
      final outcome = await container
          .read(groupControllerProvider)
          .addMember(
            groupId: groupId(),
            recipient: discovered(fx.owner),
            groupRole: GroupRole.reader,
          );

      expect(outcome, isA<FolderShareFailure>());
      expect(groups.bodies, isEmpty);
    });

    test('a server rejection surfaces as a failure outcome', () async {
      groups.throwOnAdd = true;

      final outcome = await container
          .read(groupControllerProvider)
          .addMember(
            groupId: groupId(),
            recipient: discovered(fx.bob),
            groupRole: GroupRole.reader,
          );

      expect(outcome, isA<FolderShareFailure>());
      expect(groups.bodies, isEmpty);
    });
  });
}
