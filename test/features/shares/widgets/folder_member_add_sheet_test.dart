import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/shares/widgets/folder_member_add_sheet.dart';
import 'package:hoodik_app/features/shares/widgets/share_fingerprint_tile.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../services/folder_membership_test_kit.dart';

const _crypto = CryptoService();

class _Client extends Fake implements SharesClient {
  _Client(this.roster);
  final FolderMembersResponse roster;
  DiscoveredUser? discoverResult;
  Map<String, dynamic>? createBody;

  @override
  Future<FolderMembersResponse> getFolderMembers(String folderId) async =>
      roster;
  @override
  Future<DiscoveredUser?> discoverUser(String email) async => discoverResult;
  @override
  Future<List<AppShare>> createShare(Map<String, dynamic> envelope) async {
    createBody = envelope;
    return const [];
  }
}

class _Files extends Fake implements FilesClient {
  _Files(this.children);
  final List<FileItem> children;
  @override
  Future<StorageResponse> listFiles({
    String? dirId,
    bool? editable,
    String? orderBy,
    String? order,
  }) async => StorageResponse(children: children);
}

class _Api extends Fake implements ApiClient {
  _Api(this._files, this._shares);
  final FilesClient _files;
  final SharesClient _shares;
  @override
  FilesClient get files => _files;
  @override
  SharesClient get shares => _shares;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late MembershipFixture fx;
  late _Client client;

  setUp(() {
    fx = MembershipFixture();
    client = _Client(
      fx.buildOwnerRoster([(party: fx.alice, role: ShareRole.reader)]),
    );
  });
  tearDown(() async => await fx.dispose());

  String ownWrap() {
    final key = _crypto.generateSymmetricKey();
    return FileCrypto(
      privateKeyPem: fx.owner.keyPair.privateKeyPem,
    ).encryptFileKey(fileKey: key, publicKeyPem: fx.owner.pubkey);
  }

  Future<void> open(WidgetTester tester) async {
    final folder = FileItem(
      id: fx.folderId,
      encryptedName: '',
      encryptedKey: ownWrap(),
      mime: 'dir',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decryptedPrivateKeyProvider.overrideWith(
            (ref) => fx.owner.keyPair.privateKeyPem,
          ),
          activeServerUserIdProvider.overrideWithValue(fx.owner.userId),
          apiClientProvider.overrideWithValue(_Api(_Files(const []), client)),
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
              shareGroups: false,
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
                  onPressed: () => showFolderMemberAddSheet(
                    context: context,
                    ref: ref,
                    folder: folder,
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

  testWidgets('discover then add submits the folder share envelope', (
    tester,
  ) async {
    client.discoverResult = DiscoveredUser(
      userId: fx.bob.userId,
      email: 'bob@example.test',
      pubkey: fx.bob.pubkey,
      fingerprint: fx.bob.fingerprint,
    );
    await open(tester);
    await discover(tester, 'bob@example.test');

    expect(find.byType(ShareFingerprintTile), findsOneWidget);
    await tester.ensureVisible(find.text('Add'));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(client.createBody, isNotNull);
    expect(
      (client.createBody!)['members_list_signature'],
      isNotNull,
      reason: 'a folder share carries the signed post-add roster',
    );
  });

  testWidgets('a server key/fingerprint mismatch hard-stops the add', (
    tester,
  ) async {
    client.discoverResult = DiscoveredUser(
      userId: fx.bob.userId,
      email: 'bob@example.test',
      pubkey: fx.bob.pubkey,
      fingerprint: 'deadbeef',
    );
    await open(tester);
    await discover(tester, 'bob@example.test');

    expect(find.byType(ShareFingerprintTile), findsNothing);
    expect(find.textContaining('do not match'), findsOneWidget);
  });

  testWidgets('shows the "allow them to add files" affordance, reflecting the '
      'picked role', (tester) async {
    client.discoverResult = DiscoveredUser(
      userId: fx.bob.userId,
      email: 'bob@example.test',
      pubkey: fx.bob.pubkey,
      fingerprint: fx.bob.fingerprint,
    );
    await open(tester);
    await discover(tester, 'bob@example.test');

    // Default role is Reader → view-only, so the caption points at the
    // roles that can add files.
    expect(find.text('Pick Editor or Co-owner to enable'), findsOneWidget);
    expect(find.text('Allow them to add new files'), findsNothing);

    // Promoting to Editor flips the caption — Editor/Co-owner may add files.
    await tester.tap(find.text('Editor'));
    await tester.pumpAndSettle();
    expect(find.text('Allow them to add new files'), findsOneWidget);
    expect(find.text('Pick Editor or Co-owner to enable'), findsNothing);
  });
}
