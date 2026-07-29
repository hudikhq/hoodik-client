import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/widgets/adaptive.dart';
import 'package:hoodik_app/features/files/controllers/files_action_result.dart';
import 'package:hoodik_app/features/files/controllers/files_upload_controller.dart';
import 'package:hoodik_app/features/shares/screens/folder_members_screen.dart';
import 'package:hoodik_app/features/shares/widgets/folder_member_tile.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../services/folder_membership_test_kit.dart';

class _RosterSharesClient extends Fake implements SharesClient {
  _RosterSharesClient(this.roster);

  /// Mutable so a test can swap the server's answer between loads and prove the
  /// screen re-fetches live rather than serving a cached roster.
  FolderMembersResponse roster;
  int getMembersCalls = 0;

  @override
  Future<FolderMembersResponse> getFolderMembers(String folderId) async {
    getMembersCalls++;
    return roster;
  }

  @override
  Future<Capabilities> getCapabilities() async => Capabilities(
    sharingEnabled: true,
    roles: const [ShareRole.reader, ShareRole.editor, ShareRole.coOwner],
    editableFolders: true,
    shareGroups: false,
    auditLog: false,
    fork: false,
  );
}

class _ThrowingSharesClient extends Fake implements SharesClient {
  _ThrowingSharesClient(this.error);
  final Object error;
  @override
  Future<FolderMembersResponse> getFolderMembers(String folderId) async =>
      throw error;
}

/// Throws on the first load, then serves [roster] — so a test can prove the
/// Retry button re-runs the load and recovers.
class _FlakySharesClient extends Fake implements SharesClient {
  _FlakySharesClient(this.roster);
  final FolderMembersResponse roster;
  int calls = 0;
  @override
  Future<FolderMembersResponse> getFolderMembers(String folderId) async {
    calls++;
    if (calls == 1) {
      throw DioException(
        requestOptions: RequestOptions(path: '/m'),
        type: DioExceptionType.connectionError,
      );
    }
    return roster;
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._shares);
  final SharesClient _shares;
  @override
  SharesClient get shares => _shares;
}

/// Stands in for the real upload controller so the "Add files" affordance can be
/// exercised without a native file picker. Records the folder id it was created
/// for, proving the members screen routes uploads at the folder being managed.
class _RecordingUploadController extends FilesUploadController {
  _RecordingUploadController(super.ref, super.dirId) : recordedDirId = dirId;

  final String? recordedDirId;
  int pickCalls = 0;

  @override
  Future<FilesActionResult?> pickAndUploadFiles() async {
    pickCalls++;
    return const FilesActionResult.success('uploaded');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late MembershipFixture fx;
  setUp(() => fx = MembershipFixture());
  tearDown(() async => await fx.dispose());

  Future<void> pump(
    WidgetTester tester,
    FolderMembersResponse roster, {
    required Party caller,
    void Function(_RecordingUploadController)? onUploadController,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decryptedPrivateKeyProvider.overrideWith(
            (ref) => caller.keyPair.privateKeyPem,
          ),
          activeServerUserIdProvider.overrideWithValue(caller.userId),
          apiClientProvider.overrideWithValue(
            _FakeApiClient(_RosterSharesClient(roster)),
          ),
          databaseProvider.overrideWithValue(fx.db),
          if (onUploadController != null)
            filesUploadControllerProvider(fx.folderId).overrideWith((ref) {
              final c = _RecordingUploadController(ref, fx.folderId);
              onUploadController(c);
              return c;
            }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FolderMembersScreen(folderId: fx.folderId, folderName: 'Docs'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the folder name and a row per member', (tester) async {
    final roster = fx.buildOwnerRoster([
      (party: fx.alice, role: ShareRole.reader),
      (party: fx.bob, role: ShareRole.editor),
    ]);
    await pump(tester, roster, caller: fx.owner);

    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('Members (3)'), findsOneWidget);
    expect(find.byType(FolderMemberTile), findsNWidgets(3));
    expect(find.text('${fx.alice.userId}@example.test'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
  });

  testWidgets('the owner sees Add member and per-member controls', (
    tester,
  ) async {
    final roster = fx.buildOwnerRoster([
      (party: fx.alice, role: ShareRole.reader),
    ]);
    await pump(tester, roster, caller: fx.owner);

    expect(find.text('Add member'), findsOneWidget);
    // The owner's own row and the owner badge are not mutable; alice's row is.
    expect(find.byTooltip('Revoke'), findsOneWidget);
    expect(find.byTooltip('Change role'), findsOneWidget);
  });

  testWidgets('a reader member sees the roster but no mutation controls', (
    tester,
  ) async {
    final roster = fx.buildOwnerRoster([
      (party: fx.alice, role: ShareRole.reader),
    ]);
    await pump(tester, roster, caller: fx.alice);

    expect(find.byType(FolderMemberTile), findsNWidgets(2));
    expect(find.text('Add member'), findsNothing);
    expect(find.text('Add files'), findsNothing);
    expect(find.byTooltip('Revoke'), findsNothing);
    expect(find.byTooltip('Change role'), findsNothing);
  });

  testWidgets('the owner can add files, routed at the managed folder', (
    tester,
  ) async {
    final roster = fx.buildOwnerRoster([
      (party: fx.alice, role: ShareRole.editor),
    ]);
    _RecordingUploadController? uploads;
    await pump(
      tester,
      roster,
      caller: fx.owner,
      onUploadController: (c) => uploads = c,
    );

    expect(find.text('Add files'), findsOneWidget);

    await tester.tap(find.text('Add files'));
    await tester.pumpAndSettle();

    expect(uploads, isNotNull);
    expect(uploads!.recordedDirId, fx.folderId);
    expect(
      uploads!.pickCalls,
      1,
      reason: 'tapping Add files invokes the existing upload-into-folder path',
    );
  });

  testWidgets('a co-owner can also add files', (tester) async {
    // The co-owner reaches the members screen and can drop files in, the same
    // people-can-upload parity the web grants Editor/Co-owner roles.
    final coOwnerRoster = buildResponse(
      owner: fx.owner,
      members: [
        ownerMember(fx.owner),
        signedMember(
          party: fx.alice,
          role: ShareRole.coOwner,
          isOwner: false,
          signer: fx.owner,
          addedAt: signedAt - 100,
        ),
      ],
      listSigner: fx.owner,
      signedAt: signedAt,
    );
    await pump(tester, coOwnerRoster, caller: fx.alice);

    expect(find.text('Add files'), findsOneWidget);
  });

  testWidgets('a verified roster shows verified signature badges', (
    tester,
  ) async {
    final roster = fx.buildOwnerRoster([
      (party: fx.alice, role: ShareRole.reader),
    ]);
    await pump(tester, roster, caller: fx.owner);

    // The two non-owner rows... here only alice. Her verified badge shows.
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
  });

  testWidgets('a lost-access roster surfaces the access message', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decryptedPrivateKeyProvider.overrideWith(
            (ref) => fx.owner.keyPair.privateKeyPem,
          ),
          activeServerUserIdProvider.overrideWithValue(fx.owner.userId),
          apiClientProvider.overrideWithValue(
            _FakeApiClient(_NotAMemberClient()),
          ),
          databaseProvider.overrideWithValue(fx.db),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FolderMembersScreen(folderId: fx.folderId, folderName: 'Docs'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('no longer have access'), findsOneWidget);
  });

  testWidgets('reloads live on reopen, discarding the roster from the last '
      'visit', (tester) async {
    // First visit's roster: owner + alice.
    final client = _RosterSharesClient(
      fx.buildOwnerRoster([(party: fx.alice, role: ShareRole.reader)]),
    );
    final container = ProviderContainer(
      overrides: [
        decryptedPrivateKeyProvider.overrideWith(
          (ref) => fx.owner.keyPair.privateKeyPem,
        ),
        activeServerUserIdProvider.overrideWithValue(fx.owner.userId),
        apiClientProvider.overrideWithValue(_FakeApiClient(client)),
        databaseProvider.overrideWithValue(fx.db),
      ],
    );
    addTearDown(container.dispose);

    Widget host(Widget child) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

    await tester.pumpWidget(
      host(FolderMembersScreen(folderId: fx.folderId, folderName: 'Docs')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Members (2)'), findsOneWidget);
    expect(client.getMembersCalls, 1);

    // Leave the screen: its watch is the only listener, so autoDispose drops
    // the cached roster.
    await tester.pumpWidget(host(const Scaffold()));
    await tester.pumpAndSettle();

    // The server now has a third member; a stale cache would never show it.
    client.roster = fx.buildOwnerRoster([
      (party: fx.alice, role: ShareRole.reader),
      (party: fx.bob, role: ShareRole.editor),
    ]);

    await tester.pumpWidget(
      host(FolderMembersScreen(folderId: fx.folderId, folderName: 'Docs')),
    );
    await tester.pumpAndSettle();

    expect(client.getMembersCalls, 2, reason: 'reopen must re-fetch live');
    expect(find.text('Members (3)'), findsOneWidget);
    expect(find.text('Members (2)'), findsNothing);
  });

  testWidgets('a connectivity error shows the offline message and Retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decryptedPrivateKeyProvider.overrideWith(
            (ref) => fx.owner.keyPair.privateKeyPem,
          ),
          activeServerUserIdProvider.overrideWithValue(fx.owner.userId),
          apiClientProvider.overrideWithValue(
            _FakeApiClient(
              _ThrowingSharesClient(
                DioException(
                  requestOptions: RequestOptions(
                    path: '/api/shares/folder/x/members',
                  ),
                  type: DioExceptionType.connectionError,
                ),
              ),
            ),
          ),
          databaseProvider.overrideWithValue(fx.db),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FolderMembersScreen(folderId: fx.folderId, folderName: 'Docs'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('try again once you are'), findsOneWidget);
    expect(find.widgetWithText(AdaptiveButton, 'Retry'), findsOneWidget);
  });

  testWidgets('a non-connectivity error shows the neutral message and Retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decryptedPrivateKeyProvider.overrideWith(
            (ref) => fx.owner.keyPair.privateKeyPem,
          ),
          activeServerUserIdProvider.overrideWithValue(fx.owner.userId),
          apiClientProvider.overrideWithValue(
            _FakeApiClient(_ThrowingSharesClient(StateError('bad payload'))),
          ),
          databaseProvider.overrideWithValue(fx.db),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FolderMembersScreen(folderId: fx.folderId, folderName: 'Docs'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load the member list.'), findsOneWidget);
    expect(find.textContaining('try again once you are'), findsNothing);
    expect(find.widgetWithText(AdaptiveButton, 'Retry'), findsOneWidget);
  });

  testWidgets('tapping Retry re-loads and recovers from a transient failure', (
    tester,
  ) async {
    final client = _FlakySharesClient(
      fx.buildOwnerRoster([(party: fx.alice, role: ShareRole.reader)]),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decryptedPrivateKeyProvider.overrideWith(
            (ref) => fx.owner.keyPair.privateKeyPem,
          ),
          activeServerUserIdProvider.overrideWithValue(fx.owner.userId),
          apiClientProvider.overrideWithValue(_FakeApiClient(client)),
          databaseProvider.overrideWithValue(fx.db),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FolderMembersScreen(folderId: fx.folderId, folderName: 'Docs'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AdaptiveButton, 'Retry'), findsOneWidget);

    await tester.tap(find.widgetWithText(AdaptiveButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(client.calls, 2);
    expect(find.text('Members (2)'), findsOneWidget);
  });
}

class _NotAMemberClient extends Fake implements SharesClient {
  @override
  Future<FolderMembersResponse> getFolderMembers(String folderId) async =>
      throw NotAFolderMemberException(folderId);
}
