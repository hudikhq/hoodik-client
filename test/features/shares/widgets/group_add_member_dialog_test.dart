import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/shares/widgets/group_add_member_dialog.dart';
import 'package:hoodik_app/features/shares/widgets/group_role_selector.dart';
import 'package:hoodik_app/features/shares/widgets/share_fingerprint_tile.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../services/folder_membership_test_kit.dart';

class _Shares extends Fake implements SharesClient {
  DiscoveredUser? discoverResult;

  @override
  Future<DiscoveredUser?> discoverUser(String email) async => discoverResult;
}

class _Groups extends Fake implements SharesGroupsClient {
  final bodies = <AddGroupMemberBody>[];

  @override
  Future<void> addGroupMember(String groupId, AddGroupMemberBody body) async {
    bodies.add(body);
  }
}

class _Api extends Fake implements ApiClient {
  _Api(this._shares, this._groups);
  final SharesClient _shares;
  final SharesGroupsClient _groups;
  @override
  SharesClient get shares => _shares;
  @override
  SharesGroupsClient get shareGroups => _groups;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late MembershipFixture fx;
  late _Shares shares;
  late _Groups groups;

  setUp(() {
    fx = MembershipFixture();
    shares = _Shares();
    groups = _Groups();
  });
  tearDown(() async => await fx.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decryptedPrivateKeyProvider.overrideWith(
            (ref) => fx.owner.keyPair.privateKeyPem,
          ),
          activeServerUserIdProvider.overrideWithValue(fx.owner.userId),
          apiClientProvider.overrideWithValue(_Api(shares, groups)),
          databaseProvider.overrideWithValue(fx.db),
          shareCapabilitiesProvider.overrideWith(
            (ref) async => Capabilities(
              sharingEnabled: true,
              roles: const [
                ShareRole.reader,
                ShareRole.editor,
                ShareRole.coOwner,
              ],
              editableFolders: true,
              shareGroups: true,
              auditLog: false,
              fork: false,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showGroupAddMemberDialog(
                    context: context,
                    ref: ref,
                    groupId: uuid(0x6E),
                    groupName: 'Marketing',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> discover(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(EditableText), email);
    await tester.tap(find.text('Find user'));
    await tester.pumpAndSettle();
  }

  testWidgets('discover then add submits only the plain roster body at the '
      'picked group role — no wraps or signatures', (tester) async {
    shares.discoverResult = DiscoveredUser(
      userId: fx.bob.userId,
      email: 'bob@example.test',
      pubkey: fx.bob.pubkey,
      fingerprint: fx.bob.fingerprint,
    );
    await open(tester);
    await discover(tester, 'bob@example.test');

    expect(find.byType(ShareFingerprintTile), findsOneWidget);
    expect(find.byType(GroupRoleSelector), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('group-role-editor')));
    await tester.pump();
    await tester.tap(find.text('Add member'));
    await tester.pumpAndSettle();

    final body = groups.bodies.single;
    expect(body.userId, fx.bob.userId);
    expect(body.pubkeyFingerprint, fx.bob.fingerprint);
    expect(body.groupRole, GroupRole.editor);
    expect(body.nonce, isNotEmpty);
    expect(body.toJson().keys.toSet(), {
      'user_id',
      'pubkey_fingerprint',
      'group_role',
      'timestamp',
      'nonce',
    });
  });

  testWidgets('a server key/fingerprint mismatch hard-stops the add', (
    tester,
  ) async {
    shares.discoverResult = DiscoveredUser(
      userId: fx.bob.userId,
      email: 'bob@example.test',
      pubkey: fx.bob.pubkey,
      fingerprint: 'deadbeef',
    );
    await open(tester);
    await discover(tester, 'bob@example.test');

    expect(find.byType(ShareFingerprintTile), findsNothing);
    expect(find.textContaining('do not match'), findsOneWidget);
    expect(groups.bodies, isEmpty);
  });

  testWidgets('an unknown email surfaces the not-found message', (
    tester,
  ) async {
    shares.discoverResult = null;
    await open(tester);
    await discover(tester, 'nobody@example.test');

    expect(find.byType(ShareFingerprintTile), findsNothing);
    expect(find.textContaining('No Hoodik user'), findsOneWidget);
  });
}
