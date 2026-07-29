import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/files/controllers/files_share_controller.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../../helpers/fakes.dart';

/// The audit action `shareFile` signs must match the one the server
/// reconstructs in `share.rs` (`role_change` when a different role already
/// exists, `shared_by_co_owner` for a co-owner's grant, else `grant`), and a
/// same-role re-share must not post at all. These tests verify each branch
/// against the server-parity canonical, complementing the envelope-shape
/// coverage in `files_share_controller_test.dart`.
class _RecordingSharesClient extends Fake implements SharesClient {
  Map<String, dynamic>? createBody;
  List<AppShare> recipients = const [];

  @override
  Future<List<AppShare>> createShare(Map<String, dynamic> envelope) async {
    createBody = envelope;
    return const [];
  }

  @override
  Future<List<AppShare>> getShareRecipients(String fileId) async => recipients;
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._shares);

  final SharesClient _shares;

  @override
  SharesClient get shares => _shares;
}

const _crypto = CryptoService();

FileItem _file(
  String id, {
  required String encryptedKey,
  bool isOwner = true,
  ShareRole? shareRole,
}) {
  return FileItem(
    id: id,
    encryptedName: 'enc-name',
    encryptedKey: encryptedKey,
    mime: 'text/plain',
    cipher: 'aegis128l',
    finishedUploadAt: 100,
    isOwner: isOwner,
    shareRole: shareRole,
  );
}

AppShare _recipientRow(String fileId, String userId, ShareRole role) {
  return AppShare(
    fileId: fileId,
    recipientId: userId,
    recipientEmail: 'recipient@example.com',
    recipientPubkeyFingerprint: 'fp',
    shareRole: role,
    createdAt: 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late rust.RsaKeyPair sender;
  late rust.RsaKeyPair recipientKp;
  late DiscoveredUser recipient;
  late _RecordingSharesClient sharesClient;
  late AppDatabase db;

  const senderId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        decryptedPrivateKeyProvider.overrideWith((ref) => sender.privateKeyPem),
        activeServerUserIdProvider.overrideWithValue(senderId),
        apiClientProvider.overrideWithValue(_FakeApiClient(sharesClient)),
        databaseProvider.overrideWithValue(db),
        connectivityProvider.overrideWith(
          (ref) => FakeConnectivityService(fakeOnline: true),
        ),
        workerManagerProvider.overrideWithValue(null),
      ],
    );
  }

  setUp(() {
    sender = rust.generateRsaKeypair();
    recipientKp = rust.generateRsaKeypair();
    recipient = DiscoveredUser(
      userId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      email: 'recipient@example.com',
      pubkey: recipientKp.publicKeyPem,
      fingerprint: recipientKp.fingerprint,
    );
    sharesClient = _RecordingSharesClient();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => await db.close());

  ({Uint8List key, String wrap}) ownFileKey() {
    final key = _crypto.generateSymmetricKey();
    final wrap = FileCrypto(
      privateKeyPem: sender.privateKeyPem,
    ).encryptFileKey(fileKey: key, publicKeyPem: sender.publicKeyPem);
    return (key: key, wrap: wrap);
  }

  /// Find the unix-second the controller stamped by replaying the small
  /// request-handling window: the server reconstructs the canonical from
  /// `(action, before, after, timestamp)`, so the only free variable between
  /// the controller's `now` and the test's is the signing latency.
  int? findVerifyingTimestamp({
    required AuditEventAction action,
    required ShareRole? before,
    required ShareRole after,
    required String fileId,
  }) {
    final verifier = ShareCrypto(privateKeyPem: sender.privateKeyPem);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (var t = now + 1; t >= now - 5; t--) {
      final ok = verifier.verifyAuditEvent(
        input: AuditEventSigInput(
          senderId: senderId,
          recipientId: recipient.userId,
          fileId: fileId,
          action: action,
          shareRoleBefore: before,
          shareRoleAfter: after,
          timestamp: t,
        ),
        signature: sharesClient.createBody!['event_signature'] as String,
        senderPubkey: sender.publicKeyPem,
      );
      if (ok) return t;
    }
    return null;
  }

  group('shareFile audit action', () {
    test('grant when the recipient has no existing role', () async {
      final fk = ownFileKey();
      final file = _file(
        'aaaaaaaa-0000-0000-0000-000000000001',
        encryptedKey: fk.wrap,
      );
      final container = makeContainer();
      addTearDown(container.dispose);

      await container
          .read(filesShareControllerProvider(null))
          .shareFile(file: file, recipient: recipient, role: ShareRole.editor);

      expect(
        findVerifyingTimestamp(
          action: AuditEventAction.grant,
          before: null,
          after: ShareRole.editor,
          fileId: file.id,
        ),
        isNotNull,
        reason: 'grant canonical must verify',
      );
    });

    test(
      'role_change with the prior role when upgrading an existing recipient',
      () async {
        final fk = ownFileKey();
        final file = _file(
          'aaaaaaaa-0000-0000-0000-000000000002',
          encryptedKey: fk.wrap,
        );
        sharesClient.recipients = [
          _recipientRow(file.id, recipient.userId, ShareRole.reader),
        ];
        final container = makeContainer();
        addTearDown(container.dispose);

        final outcome = await container
            .read(filesShareControllerProvider(null))
            .shareFile(
              file: file,
              recipient: recipient,
              role: ShareRole.editor,
            );

        expect(outcome, isA<ShareSuccess>());
        // The server reconstructs role_change with before = reader (the row it
        // finds) and after = the requested editor; the signature must verify
        // against that exact canonical, not a grant.
        expect(
          findVerifyingTimestamp(
            action: AuditEventAction.roleChange,
            before: ShareRole.reader,
            after: ShareRole.editor,
            fileId: file.id,
          ),
          isNotNull,
          reason: 'role_change/reader canonical must verify',
        );
      },
    );

    test('same-role re-share is a no-op (no createShare POST)', () async {
      final fk = ownFileKey();
      final file = _file(
        'aaaaaaaa-0000-0000-0000-000000000003',
        encryptedKey: fk.wrap,
      );
      sharesClient.recipients = [
        _recipientRow(file.id, recipient.userId, ShareRole.editor),
      ];
      final container = makeContainer();
      addTearDown(container.dispose);

      final outcome = await container
          .read(filesShareControllerProvider(null))
          .shareFile(file: file, recipient: recipient, role: ShareRole.editor);

      expect(outcome, isA<ShareSuccess>());
      expect(
        sharesClient.createBody,
        isNull,
        reason: 'the server skips a same-role grant, so nothing is posted',
      );
    });

    test(
      'shared_by_co_owner when a co-owner caller grants a fresh role',
      () async {
        final fk = ownFileKey();
        final file = _file(
          'aaaaaaaa-0000-0000-0000-000000000004',
          encryptedKey: fk.wrap,
          isOwner: false,
          shareRole: ShareRole.coOwner,
        );
        final container = makeContainer();
        addTearDown(container.dispose);

        final outcome = await container
            .read(filesShareControllerProvider(null))
            .shareFile(
              file: file,
              recipient: recipient,
              role: ShareRole.reader,
            );

        expect(outcome, isA<ShareSuccess>());
        expect(
          findVerifyingTimestamp(
            action: AuditEventAction.sharedByCoOwner,
            before: null,
            after: ShareRole.reader,
            fileId: file.id,
          ),
          isNotNull,
          reason: 'shared_by_co_owner canonical must verify',
        );
      },
    );
  });
}
