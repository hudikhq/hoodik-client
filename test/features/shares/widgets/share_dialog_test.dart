import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/shares/services/trusted_fingerprint_dao.dart';
import 'package:hoodik_app/features/shares/widgets/share_dialog.dart';
import 'package:hoodik_app/features/shares/widgets/share_fingerprint_tile.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../../../helpers/fakes.dart';
import '../shares_test_fakes.dart';

const _crypto = CryptoService();
const _senderId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late rust.RsaKeyPair sender;
  late rust.RsaKeyPair recipientKp;
  late DiscoveredUser recipient;
  late FakeSharesClient sharesClient;
  late AppDatabase db;
  late FileItem ownedFile;

  setUp(() {
    sender = rust.generateRsaKeypair();
    recipientKp = rust.generateRsaKeypair();
    recipient = DiscoveredUser(
      userId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      email: 'recipient@example.com',
      pubkey: recipientKp.publicKeyPem,
      fingerprint: recipientKp.fingerprint,
    );
    sharesClient = FakeSharesClient();
    db = AppDatabase.forTesting(NativeDatabase.memory());

    final fileKey = _crypto.generateSymmetricKey();
    final wrap = FileCrypto(
      privateKeyPem: sender.privateKeyPem,
    ).encryptFileKey(fileKey: fileKey, publicKeyPem: sender.publicKeyPem);
    ownedFile = FileItem(
      id: '11111111-1111-1111-1111-111111111111',
      encryptedName: 'enc',
      encryptedKey: wrap,
      mime: 'text/plain',
      finishedUploadAt: 1,
    );
  });

  tearDown(() async => await db.close());

  Future<void> pumpDialog(
    WidgetTester tester, {
    bool sharingEnabled = true,
    bool shareGroups = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decryptedPrivateKeyProvider.overrideWith(
            (ref) => sender.privateKeyPem,
          ),
          activeServerUserIdProvider.overrideWithValue(_senderId),
          apiClientProvider.overrideWithValue(FakeApiClient(sharesClient)),
          databaseProvider.overrideWithValue(db),
          shareCapabilitiesProvider.overrideWith(
            (ref) async => Capabilities(
              sharingEnabled: sharingEnabled,
              roles: const [
                ShareRole.reader,
                ShareRole.editor,
                ShareRole.coOwner,
              ],
              editableFolders: false,
              shareGroups: shareGroups,
              auditLog: false,
              fork: false,
            ),
          ),
          connectivityProvider.overrideWith((ref) => FakeConnectivityService()),
          workerManagerProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showShareDialog(
                      context: context,
                      ref: ref,
                      dirId: null,
                      file: ownedFile,
                    ),
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> discover(WidgetTester tester, String email) async {
    // The email field is an AdaptiveTextField — Material or Cupertino depending
    // on the host platform — so target the EditableText they both wrap.
    await tester.enterText(find.byType(EditableText), email);
    await tester.tap(find.text('Find user'));
    await tester.pumpAndSettle();
  }

  bool shareEnabled(WidgetTester tester) {
    final button = tester.widget<TextButton>(
      find.ancestor(of: find.text('Share'), matching: find.byType(TextButton)),
    );
    return button.onPressed != null;
  }

  group('discover states', () {
    testWidgets('a found recipient renders the fingerprint tile', (
      tester,
    ) async {
      sharesClient.discoverResult = recipient;
      await pumpDialog(tester);
      await discover(tester, recipient.email);

      expect(find.byType(ShareFingerprintTile), findsOneWidget);
      expect(find.text(recipient.email), findsWidgets);
    });

    testWidgets('a 404 lookup shows the not-found message', (tester) async {
      sharesClient.discoverResult = null;
      await pumpDialog(tester);
      await discover(tester, 'nobody@example.com');

      expect(find.text('No Hoodik user with that email.'), findsOneWidget);
      expect(find.byType(ShareFingerprintTile), findsNothing);
    });

    testWidgets('discovering yourself shows the self message', (tester) async {
      sharesClient.discoverError = DiscoverException(
        DiscoverErrorKind.cannotDiscoverSelf,
      );
      await pumpDialog(tester);
      await discover(tester, 'me@example.com');

      expect(find.text("You can't share with yourself."), findsOneWidget);
    });

    testWidgets('a rate-limited lookup shows the throttle message', (
      tester,
    ) async {
      sharesClient.discoverError = DiscoverException(
        DiscoverErrorKind.rateLimited,
      );
      await pumpDialog(tester);
      await discover(tester, 'spam@example.com');

      expect(find.text('Too many lookups, try again shortly.'), findsOneWidget);
    });

    testWidgets('a key/fingerprint mismatch from the server hard-stops', (
      tester,
    ) async {
      // Server claims a fingerprint that does not match the pubkey it sent.
      sharesClient.discoverResult = DiscoveredUser(
        userId: recipient.userId,
        email: recipient.email,
        pubkey: recipientKp.publicKeyPem,
        fingerprint: 'deadbeef',
      );
      await pumpDialog(tester);
      await discover(tester, recipient.email);

      expect(find.byType(ShareFingerprintTile), findsNothing);
      expect(find.textContaining('do not match'), findsOneWidget);
    });
  });

  group('TOFU', () {
    testWidgets('first sight allows sharing and records the fingerprint', (
      tester,
    ) async {
      sharesClient.discoverResult = recipient;
      await pumpDialog(tester);
      await discover(tester, recipient.email);

      expect(shareEnabled(tester), isTrue);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(sharesClient.createBody, isNotNull);
      final row = await db.getTrustedFingerprint(_senderId, recipient.userId);
      expect(row?.fingerprint, recipient.fingerprint);
    });

    testWidgets('a matching stored fingerprint shows the verified state', (
      tester,
    ) async {
      await db.upsertTrustedFingerprint(
        ownerUserId: _senderId,
        userId: recipient.userId,
        fingerprint: recipient.fingerprint,
      );
      sharesClient.discoverResult = recipient;
      await pumpDialog(tester);
      await discover(tester, recipient.email);

      expect(find.textContaining('Verified'), findsOneWidget);
      expect(shareEnabled(tester), isTrue);
    });

    testWidgets('a DIFFERENT stored fingerprint blocks submit until the user '
        'acknowledges the change', (tester) async {
      await db.upsertTrustedFingerprint(
        ownerUserId: _senderId,
        userId: recipient.userId,
        fingerprint: 'an-old-fingerprint-we-trusted-before',
      );
      sharesClient.discoverResult = recipient;
      await pumpDialog(tester);
      await discover(tester, recipient.email);

      // Loud mismatch surface, and Share disabled until the checkbox is ticked.
      expect(find.textContaining('fingerprint changed'), findsOneWidget);
      expect(shareEnabled(tester), isFalse);

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(shareEnabled(tester), isTrue);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(
        sharesClient.createBody,
        isNotNull,
        reason: 'an acknowledged mismatch may proceed',
      );
    });
  });

  group('role + submit', () {
    testWidgets('selecting Editor shares at that role via the controller', (
      tester,
    ) async {
      sharesClient.discoverResult = recipient;
      await pumpDialog(tester);
      await discover(tester, recipient.email);

      await tester.ensureVisible(find.text('Editor'));
      await tester.tap(find.text('Editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      final body = sharesClient.createBody!;
      expect(body.keys.toSet(), {
        'payload_der',
        'signature',
        'entries',
        'event_signature',
      });
      // The wrapped key in the envelope is the editor grant for this recipient.
      final entry = (body['entries'] as List).single as Map;
      final unwrapped = _crypto.rsaDecrypt(
        ciphertextBase64: entry['encrypted_key'] as String,
        privateKeyPem: recipientKp.privateKeyPem,
      );
      expect(Uint8List.fromList(_crypto.hexDecode(unwrapped)), isNotEmpty);
    });

    testWidgets('a server rejection surfaces and keeps the dialog open', (
      tester,
    ) async {
      sharesClient.discoverResult = recipient;
      sharesClient.throwOnCreate = true;
      await pumpDialog(tester);
      await discover(tester, recipient.email);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      // Dialog stays up (still shows the recipient tile) on failure.
      expect(find.byType(ShareFingerprintTile), findsOneWidget);
    });

    testWidgets('a successful share reloads the roster and clears the add '
        'form without closing the dialog', (tester) async {
      sharesClient.discoverResult = recipient;
      // The roster is empty until the grant lands, then the server returns the
      // freshly added recipient — the dialog must reload to surface it.
      sharesClient.recipientsAfterCreate = [
        AppShare(
          fileId: ownedFile.id,
          recipientId: recipient.userId,
          recipientEmail: recipient.email,
          recipientPubkeyFingerprint: recipient.fingerprint,
          shareRole: ShareRole.reader,
          createdAt: 1,
        ),
      ];
      await pumpDialog(tester);
      await discover(tester, recipient.email);

      expect(find.text('No one has access yet.'), findsOneWidget);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      // Dialog stays open: the add form reset (no fingerprint tile) and the
      // reloaded roster now lists the new recipient under "People with access".
      expect(find.byType(ShareFingerprintTile), findsNothing);
      expect(find.text('No one has access yet.'), findsNothing);
      expect(find.text('People with access'), findsOneWidget);
      expect(find.text(recipient.email), findsOneWidget);
    });
  });

  group('existing recipients', () {
    testWidgets('lists current recipients and revokes through the controller', (
      tester,
    ) async {
      sharesClient.recipients = [
        AppShare(
          fileId: ownedFile.id,
          recipientId: recipient.userId,
          recipientEmail: recipient.email,
          recipientPubkeyFingerprint: recipient.fingerprint,
          shareRole: ShareRole.reader,
          createdAt: 1,
        ),
      ];
      await pumpDialog(tester);

      expect(find.text('People with access'), findsOneWidget);
      expect(find.text(recipient.email), findsWidgets);

      await tester.tap(find.byTooltip('Revoke'));
      await tester.pumpAndSettle();

      // Confirm the revoke in the adaptive alert.
      await tester.tap(find.text('Revoke').last);
      await tester.pumpAndSettle();

      expect(sharesClient.revokeArgs, isNotNull);
      final (fileId, userId, body) = sharesClient.revokeArgs!;
      expect(fileId, ownedFile.id);
      expect(userId, recipient.userId);
      expect(body.keys.toSet(), {'event_signature', 'timestamp'});
    });
  });

  group('share-with-group gating (capability collapse)', () {
    const groupButton = ValueKey('share-with-group-button');

    testWidgets(
      'offered when sharing is enabled and the server speaks groups',
      (tester) async {
        await pumpDialog(tester, sharingEnabled: true, shareGroups: true);
        expect(find.byKey(groupButton), findsOneWidget);
      },
    );

    testWidgets('hidden when the server does not speak groups', (tester) async {
      await pumpDialog(tester, sharingEnabled: true, shareGroups: false);
      expect(find.byKey(groupButton), findsNothing);
    });

    testWidgets('hidden when sharing is disabled even if groups are present', (
      tester,
    ) async {
      await pumpDialog(tester, sharingEnabled: false, shareGroups: true);
      expect(find.byKey(groupButton), findsNothing);
    });
  });
}
