import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/shares/controllers/share_to_group_controller.dart';
import 'package:hoodik_app/features/shares/widgets/share_to_group_sheet.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

class _Groups extends Fake implements SharesGroupsClient {
  _Groups(this.response);
  GroupsResponse response;
  @override
  Future<GroupsResponse> listGroups() async => response;
}

class _Api extends Fake implements ApiClient {
  _Api(this._groups);
  final SharesGroupsClient _groups;
  @override
  SharesGroupsClient get shareGroups => _groups;
}

/// Captures the group + role a share-to-group submission routes through,
/// standing in for the real fan-out controller so the widget test asserts
/// routing without doing any crypto.
class _FakeShareToGroup extends ShareToGroupController {
  _FakeShareToGroup(super.ref);

  final calls = <({String groupId, String fileId, ShareRole role})>[];

  @override
  Future<FolderShareOutcome> shareToGroup({
    required String groupId,
    required FileItem file,
    required ShareRole role,
    void Function(int done, int total)? onProgress,
  }) async {
    calls.add((groupId: groupId, fileId: file.id, role: role));
    return const FolderShareOutcome.success();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GroupsResponse groups({
    List<ShareGroup> owned = const [],
    List<ShareGroupAsMember> memberOf = const [],
  }) => GroupsResponse(owned: owned, memberOf: memberOf);

  ShareGroup owned(String id, String name) =>
      ShareGroup(id: id, ownerId: 'me', name: name, createdAt: 0);

  ShareGroupAsMember memberOf(String id, String name, GroupRole role) =>
      ShareGroupAsMember(
        id: id,
        ownerId: 'other',
        ownerEmail: 'x@example.test',
        name: name,
        createdAt: 0,
        addedAt: 0,
        groupRole: role,
      );

  Future<_FakeShareToGroup Function()> pump(
    WidgetTester tester,
    GroupsResponse response,
  ) async {
    late _FakeShareToGroup fake;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_Api(_Groups(response))),
          shareToGroupControllerProvider.overrideWith(
            (ref) => fake = _FakeShareToGroup(ref),
          ),
          shareCapabilitiesProvider.overrideWith(
            (ref) async => Capabilities(
              sharingEnabled: true,
              roles: const [
                ShareRole.reader,
                ShareRole.editor,
                ShareRole.coOwner,
              ],
              editableFolders: false,
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
                  onPressed: () => showShareToGroupSheet(
                    context: context,
                    ref: ref,
                    file: FileItem(
                      id: 'file-1',
                      encryptedName: 'e',
                      mime: 'text/plain',
                      encryptedKey: 'k',
                    ),
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
    return () => fake;
  }

  testWidgets('offers owned groups and editor-of groups, hides reader groups', (
    tester,
  ) async {
    await pump(
      tester,
      groups(
        owned: [owned('g-owned', 'My team')],
        memberOf: [
          memberOf('g-editor', 'Editor group', GroupRole.editor),
          memberOf('g-coowner', 'Co-owner group', GroupRole.coOwner),
          memberOf('g-reader', 'Reader group', GroupRole.reader),
        ],
      ),
    );

    expect(
      find.byKey(const ValueKey('share-to-group-g-owned')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('share-to-group-g-editor')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('share-to-group-g-coowner')),
      findsOneWidget,
    );
    // A group where the caller is only a reader cannot be shared to.
    expect(find.byKey(const ValueKey('share-to-group-g-reader')), findsNothing);
  });

  testWidgets('selecting a group and role routes through the controller', (
    tester,
  ) async {
    final fake = await pump(
      tester,
      groups(owned: [owned('g-owned', 'My team')]),
    );

    await tester.tap(find.byKey(const ValueKey('share-to-group-g-owned')));
    await tester.pump();
    await tester.tap(find.text('Editor'));
    await tester.pump();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    final calls = fake().calls;
    expect(calls, hasLength(1));
    expect(calls.single.groupId, 'g-owned');
    expect(calls.single.fileId, 'file-1');
    expect(calls.single.role, ShareRole.editor);
  });

  testWidgets('with no eligible groups it shows the empty hint and no Share', (
    tester,
  ) async {
    await pump(
      tester,
      groups(
        memberOf: [memberOf('g-reader', 'Reader group', GroupRole.reader)],
      ),
    );

    expect(find.textContaining('not an editor of any group'), findsOneWidget);
  });
}
