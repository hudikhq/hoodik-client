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
  final GroupsResponse response;
  @override
  Future<GroupsResponse> listGroups() async => response;
}

class _Api extends Fake implements ApiClient {
  _Api(this._groups);
  final SharesGroupsClient _groups;
  @override
  SharesGroupsClient get shareGroups => _groups;
}

class _SuccessShareToGroup extends ShareToGroupController {
  _SuccessShareToGroup(super.ref);

  @override
  Future<FolderShareOutcome> shareToGroup({
    required String groupId,
    required FileItem file,
    required ShareRole role,
    void Function(int done, int total)? onProgress,
  }) async => const FolderShareOutcome.success();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a successful fan-out fires onShared so the opener can refresh', (
    tester,
  ) async {
    var refreshed = false;
    final response = GroupsResponse(
      owned: [
        ShareGroup(id: 'g-owned', ownerId: 'me', name: 'My team', createdAt: 0),
      ],
      memberOf: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_Api(_Groups(response))),
          shareToGroupControllerProvider.overrideWith(
            (ref) => _SuccessShareToGroup(ref),
          ),
          shareCapabilitiesProvider.overrideWith(
            (ref) async => Capabilities(
              sharingEnabled: true,
              roles: const [ShareRole.reader, ShareRole.editor],
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
                    onShared: () => refreshed = true,
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

    await tester.tap(find.byKey(const ValueKey('share-to-group-g-owned')));
    await tester.pump();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(refreshed, isTrue);
  });
}
