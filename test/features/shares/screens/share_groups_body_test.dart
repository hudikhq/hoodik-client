import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/shares/screens/share_groups_body.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

class _Groups extends Fake implements SharesGroupsClient {
  _Groups(this.response);
  GroupsResponse response;
  final deleted = <String>[];
  final removed = <(String, String)>[];
  final rolesSet = <(String, String, GroupRole)>[];

  @override
  Future<GroupsResponse> listGroups() async => response;

  @override
  Future<void> deleteGroup(String groupId) async => deleted.add(groupId);

  @override
  Future<void> removeGroupMember(String groupId, String userId) async =>
      removed.add((groupId, userId));

  @override
  Future<void> setGroupMemberRole(
    String groupId,
    String userId,
    SetGroupMemberRoleBody body,
  ) async => rolesSet.add((groupId, userId, body.groupRole));
}

class _Api extends Fake implements ApiClient {
  _Api(this._groups);
  final SharesGroupsClient _groups;
  @override
  SharesGroupsClient get shareGroups => _groups;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ShareGroup ownedGroup({List<ShareGroupMember> members = const []}) =>
      ShareGroup(
        id: 'g1',
        ownerId: 'me',
        name: 'Marketing',
        createdAt: 0,
        members: members,
      );

  ShareGroupMember member(
    String id,
    String email, {
    GroupRole role = GroupRole.reader,
  }) => ShareGroupMember(
    userId: id,
    email: email,
    fingerprint: 'abcd1234abcd1234',
    addedAt: 0,
    groupRole: role,
  );

  Future<void> pumpBody(WidgetTester tester, _Groups groups) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(_Api(groups))],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ShareGroupsBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders owned and member-of groups', (tester) async {
    final groups = _Groups(
      GroupsResponse(
        owned: [
          ownedGroup(members: [member('u2', 'alice@example.test')]),
        ],
        memberOf: [
          ShareGroupAsMember(
            id: 'g2',
            ownerId: 'other',
            ownerEmail: 'carol@example.test',
            name: 'Friends',
            createdAt: 0,
            addedAt: 0,
            groupRole: GroupRole.reader,
          ),
        ],
      ),
    );
    await pumpBody(tester, groups);

    expect(find.text('Marketing'), findsOneWidget);
    expect(find.text('alice@example.test'), findsOneWidget);
    expect(find.text('1 member'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.textContaining('carol@example.test'), findsOneWidget);
  });

  testWidgets('shows the empty states when there are no groups', (
    tester,
  ) async {
    final groups = _Groups(GroupsResponse(owned: const [], memberOf: const []));
    await pumpBody(tester, groups);

    expect(find.byKey(const ValueKey('owned-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-of-empty')), findsOneWidget);
  });

  testWidgets('deleting a group confirms then calls the client', (
    tester,
  ) async {
    final groups = _Groups(
      GroupsResponse(owned: [ownedGroup()], memberOf: const []),
    );
    await pumpBody(tester, groups);

    await tester.tap(find.byTooltip('Delete group'));
    await tester.pumpAndSettle();
    expect(find.text('Delete group?'), findsOneWidget);

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(groups.deleted, ['g1']);
  });

  testWidgets('removing a member confirms then calls the client', (
    tester,
  ) async {
    final groups = _Groups(
      GroupsResponse(
        owned: [
          ownedGroup(members: [member('u2', 'alice@example.test')]),
        ],
        memberOf: const [],
      ),
    );
    await pumpBody(tester, groups);

    await tester.tap(find.byTooltip('Remove member'));
    await tester.pumpAndSettle();
    expect(find.text('Remove member?'), findsOneWidget);

    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(groups.removed, [('g1', 'u2')]);
  });

  testWidgets('a member row shows the group-role chip for its role', (
    tester,
  ) async {
    final groups = _Groups(
      GroupsResponse(
        owned: [
          ownedGroup(
            members: [
              member('u2', 'alice@example.test', role: GroupRole.editor),
            ],
          ),
        ],
        memberOf: const [],
      ),
    );
    await pumpBody(tester, groups);

    expect(
      find.byKey(const ValueKey('group-role-chip-editor')),
      findsOneWidget,
    );
  });

  testWidgets('setting a member role calls the client with the picked role', (
    tester,
  ) async {
    final groups = _Groups(
      GroupsResponse(
        owned: [
          ownedGroup(
            members: [
              member('u2', 'alice@example.test', role: GroupRole.reader),
            ],
          ),
        ],
        memberOf: const [],
      ),
    );
    await pumpBody(tester, groups);

    await tester.tap(find.byTooltip('Set group role'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('set-group-role-co-owner')));
    await tester.pumpAndSettle();

    expect(groups.rolesSet, [('g1', 'u2', GroupRole.coOwner)]);
  });

  ShareGroupAsMember memberOfGroup({
    required String name,
    required GroupRole role,
  }) => ShareGroupAsMember(
    id: 'g-$name',
    ownerId: 'other',
    ownerEmail: 'carol@example.test',
    name: name,
    createdAt: 0,
    addedAt: 0,
    groupRole: role,
  );

  testWidgets('a reader member-of group shows no manage action', (
    tester,
  ) async {
    final groups = _Groups(
      GroupsResponse(
        owned: const [],
        memberOf: [memberOfGroup(name: 'Reader group', role: GroupRole.reader)],
      ),
    );
    await pumpBody(tester, groups);

    expect(find.text('Reader group'), findsOneWidget);
    expect(find.byTooltip('Add member'), findsNothing);
    expect(find.byTooltip('Rename group'), findsNothing);
  });

  testWidgets('an editor member-of group shows no manage action', (
    tester,
  ) async {
    final groups = _Groups(
      GroupsResponse(
        owned: const [],
        memberOf: [memberOfGroup(name: 'Editor group', role: GroupRole.editor)],
      ),
    );
    await pumpBody(tester, groups);

    expect(find.byTooltip('Add member'), findsNothing);
    expect(find.byTooltip('Rename group'), findsNothing);
  });

  testWidgets('a co-owner member-of group exposes add-member but not rename', (
    tester,
  ) async {
    final groups = _Groups(
      GroupsResponse(
        owned: const [],
        memberOf: [
          memberOfGroup(name: 'Co-owned group', role: GroupRole.coOwner),
        ],
      ),
    );
    await pumpBody(tester, groups);

    expect(find.byTooltip('Add member'), findsOneWidget);
    // Rename is owner-only — a member-of viewer (even a co-owner) never owns
    // the group, so the rename affordance must not appear here.
    expect(find.byTooltip('Rename group'), findsNothing);
  });
}
