import 'dart:convert';
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
import 'package:hoodik_app/features/shares/services/trusted_fingerprint_dao.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../../helpers/fakes.dart';

/// Captures the bodies the controller posts so each test can assert the exact
/// envelope shape and the revoke body. `getShareRecipients` returns a scripted
/// roster for the passthrough test.
class _RecordingSharesClient extends Fake implements SharesClient {
  Map<String, dynamic>? createBody;
  (String, String, Map<String, dynamic>)? revokeArgs;
  List<AppShare> recipients = const [];
  bool throwOnCreate = false;

  @override
  Future<List<AppShare>> createShare(Map<String, dynamic> envelope) async {
    createBody = envelope;
    if (throwOnCreate) {
      throw Exception('server rejected');
    }
    return const [];
  }

  @override
  Future<void> revokeShare(
    String fileId,
    String userId,
    Map<String, dynamic> body,
  ) async {
    revokeArgs = (fileId, userId, body);
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

FileItem _file(String id, {required String encryptedKey}) {
  return FileItem(
    id: id,
    encryptedName: 'enc-name',
    encryptedKey: encryptedKey,
    mime: 'text/plain',
    cipher: 'aegis128l',
    finishedUploadAt: 100,
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

  ProviderContainer makeContainer({String? sender0 = senderId}) {
    return ProviderContainer(
      overrides: [
        decryptedPrivateKeyProvider.overrideWith((ref) => sender.privateKeyPem),
        activeServerUserIdProvider.overrideWithValue(sender0),
        apiClientProvider.overrideWithValue(_FakeApiClient(sharesClient)),
        databaseProvider.overrideWithValue(db),
        // The controller reads `filesNotifierProvider(dirId)` for the cached
        // file key; that notifier wires a connectivity listener and a worker
        // manager at build time. Stub both so the host test never reaches a
        // platform channel.
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

  /// Wrap a freshly generated file key under the sender's own pubkey — the
  /// form a real `user_files.encrypted_key` row carries for the owner.
  ({Uint8List key, String wrap}) ownFileKey() {
    final key = _crypto.generateSymmetricKey();
    final wrap = FileCrypto(
      privateKeyPem: sender.privateKeyPem,
    ).encryptFileKey(fileKey: key, publicKeyPem: sender.publicKeyPem);
    return (key: key, wrap: wrap);
  }

  group('shareFile envelope', () {
    test('builds exactly the four-key envelope the server validates', () async {
      final fk = ownFileKey();
      final file = _file(
        '11111111-1111-1111-1111-111111111111',
        encryptedKey: fk.wrap,
      );
      final container = makeContainer();
      addTearDown(container.dispose);

      final outcome = await container
          .read(filesShareControllerProvider(null))
          .shareFile(file: file, recipient: recipient, role: ShareRole.editor);

      expect(outcome, isA<ShareSuccess>());
      final body = sharesClient.createBody!;
      expect(body.keys.toSet(), {
        'payload_der',
        'signature',
        'entries',
        'event_signature',
      });
      expect(body['payload_der'], isA<String>());
      expect(body['signature'], isA<String>());
      expect(body['event_signature'], isA<String>());

      final entries = body['entries'] as List;
      expect(entries, hasLength(1));
      final entry = entries.single as Map;
      expect(entry.keys.toSet(), {'file_id', 'encrypted_key'});
      expect(entry['file_id'], file.id);
    });

    test('entry encrypted_key is the recipient-wrapped file key', () async {
      final fk = ownFileKey();
      final file = _file(
        '22222222-2222-2222-2222-222222222222',
        encryptedKey: fk.wrap,
      );
      final container = makeContainer();
      addTearDown(container.dispose);

      await container
          .read(filesShareControllerProvider(null))
          .shareFile(file: file, recipient: recipient, role: ShareRole.reader);

      final entry = (sharesClient.createBody!['entries'] as List).single as Map;
      final wrap = entry['encrypted_key'] as String;

      // Only the recipient's private key can unwrap it, back to the same key.
      final unwrappedHex = _crypto.rsaDecrypt(
        ciphertextBase64: wrap,
        privateKeyPem: recipientKp.privateKeyPem,
      );
      expect(unwrappedHex, _crypto.hexEncode(fk.key));
    });

    test('payload signature verifies against the canonical the server '
        'reconstructs', () async {
      final fk = ownFileKey();
      final file = _file(
        '33333333-3333-3333-3333-333333333333',
        encryptedKey: fk.wrap,
      );
      final container = makeContainer();
      addTearDown(container.dispose);

      await container
          .read(filesShareControllerProvider(null))
          .shareFile(file: file, recipient: recipient, role: ShareRole.coOwner);

      final body = sharesClient.createBody!;
      final der = base64.decode(body['payload_der'] as String);
      final prefix = utf8.encode('hoodik-share-v1\x00');
      final signingInput = Uint8List(prefix.length + der.length)
        ..setRange(0, prefix.length, prefix)
        ..setRange(prefix.length, prefix.length + der.length, der);

      expect(
        rust.rsaVerifyBytes(
          message: signingInput,
          signature: body['signature'] as String,
          publicKeyPem: sender.publicKeyPem,
        ),
        isTrue,
      );
    });

    test('event_signature verifies as a grant the server can reconstruct '
        'from its own state', () async {
      final fk = ownFileKey();
      final file = _file(
        '44444444-4444-4444-4444-444444444444',
        encryptedKey: fk.wrap,
      );
      final container = makeContainer();
      addTearDown(container.dispose);

      await container
          .read(filesShareControllerProvider(null))
          .shareFile(file: file, recipient: recipient, role: ShareRole.editor);

      // The server rebuilds AuditEventSigInputV1 from the recipient row it
      // wrote: grant, no before-role, after = requested role, at the share's
      // timestamp. The signature must verify against that exact canonical for
      // some second in the request-handling window — which is the only thing
      // the controller's internal `now` is free to vary on.
      final ts = _findVerifyingTimestamp(
        signature: sharesClient.createBody!['event_signature'] as String,
        build: (t) => AuditEventSigInput(
          senderId: senderId,
          recipientId: recipient.userId,
          fileId: file.id,
          action: AuditEventAction.grant,
          shareRoleBefore: null,
          shareRoleAfter: ShareRole.editor,
          timestamp: t,
        ),
        senderPubkey: sender.publicKeyPem,
        verifierKey: sender.privateKeyPem,
      );
      expect(
        ts,
        isNotNull,
        reason: 'grant canonical must verify at the signed timestamp',
      );
    });

    test('payload_der commits to the entries_hash of the wire entry', () async {
      final fk = ownFileKey();
      final file = _file(
        '55555555-5555-5555-5555-555555555555',
        encryptedKey: fk.wrap,
      );
      final container = makeContainer();
      addTearDown(container.dispose);

      await container
          .read(filesShareControllerProvider(null))
          .shareFile(file: file, recipient: recipient, role: ShareRole.reader);

      final body = sharesClient.createBody!;
      final entry = (body['entries'] as List).single as Map;
      final expectedHash = ShareCrypto(privateKeyPem: sender.privateKeyPem)
          .computeEntriesHash([
            ShareEntryInput(
              fileId: entry['file_id'] as String,
              encryptedKey: entry['encrypted_key'] as String,
            ),
          ]);

      // The 32-byte entries_hash is the only SHA-256-length OCTET STRING in
      // the payload SEQUENCE (sender/recipient ids are 16, fingerprint is 32
      // but precedes it, nonce is 16). Locating the computed hash as a
      // contiguous run inside the DER proves the controller signed over the
      // entries it actually sent — the binding the server's
      // `entries_hash_mismatch` guard enforces.
      final der = base64.decode(body['payload_der'] as String);
      expect(
        _containsSubsequence(der, expectedHash),
        isTrue,
        reason: 'payload DER must carry the computed entries_hash',
      );
    });

    test('records the recipient fingerprint on success (TOFU)', () async {
      final fk = ownFileKey();
      final file = _file(
        '66666666-6666-6666-6666-666666666666',
        encryptedKey: fk.wrap,
      );
      final container = makeContainer();
      addTearDown(container.dispose);

      await container
          .read(filesShareControllerProvider(null))
          .shareFile(file: file, recipient: recipient, role: ShareRole.reader);

      final row = await db.getTrustedFingerprint(senderId, recipient.userId);
      expect(row, isNotNull);
      expect(row!.ownerUserId, senderId);
      expect(row.fingerprint, recipient.fingerprint);
    });

    test('does not record trust when the server rejects the share', () async {
      sharesClient.throwOnCreate = true;
      final fk = ownFileKey();
      final file = _file(
        '77777777-7777-7777-7777-777777777777',
        encryptedKey: fk.wrap,
      );
      final container = makeContainer();
      addTearDown(container.dispose);

      final outcome = await container
          .read(filesShareControllerProvider(null))
          .shareFile(file: file, recipient: recipient, role: ShareRole.reader);

      expect(outcome, isA<ShareFailure>());
      expect(
        await db.getTrustedFingerprint(senderId, recipient.userId),
        isNull,
      );
    });

    test('fails clearly without a sender UUID', () async {
      final fk = ownFileKey();
      final file = _file(
        '88888888-8888-8888-8888-888888888888',
        encryptedKey: fk.wrap,
      );
      final container = makeContainer(sender0: null);
      addTearDown(container.dispose);

      final outcome = await container
          .read(filesShareControllerProvider(null))
          .shareFile(file: file, recipient: recipient, role: ShareRole.reader);

      expect(outcome, isA<ShareFailure>());
      expect((outcome as ShareFailure).message, contains('initialized'));
      expect(sharesClient.createBody, isNull);
    });
  });

  group('revokeRecipient', () {
    test('posts a signed event_signature + timestamp body', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final outcome = await container
          .read(filesShareControllerProvider(null))
          .revokeRecipient(
            fileId: '99999999-9999-9999-9999-999999999999',
            userId: recipient.userId,
            currentRole: ShareRole.editor,
          );

      expect(outcome, isA<ShareSuccess>());
      final (fileId, userId, body) = sharesClient.revokeArgs!;
      expect(fileId, '99999999-9999-9999-9999-999999999999');
      expect(userId, recipient.userId);
      expect(body.keys.toSet(), {'event_signature', 'timestamp'});
      expect(body['timestamp'], isA<int>());

      // The server reconstructs the revoke canonical from the target row's
      // current role and the body timestamp; the signature must verify there.
      final verifier = ShareCrypto(privateKeyPem: sender.privateKeyPem);
      final ok = verifier.verifyAuditEvent(
        input: AuditEventSigInput(
          senderId: senderId,
          recipientId: recipient.userId,
          fileId: fileId,
          action: AuditEventAction.revoke,
          shareRoleBefore: ShareRole.editor,
          shareRoleAfter: null,
          timestamp: body['timestamp'] as int,
        ),
        signature: body['event_signature'] as String,
        senderPubkey: sender.publicKeyPem,
      );
      expect(ok, isTrue);
    });
  });

  group('listRecipients', () {
    test('passes through the roster the client returns', () async {
      sharesClient.recipients = [
        AppShare(
          fileId: 'f',
          recipientId: recipient.userId,
          recipientEmail: recipient.email,
          recipientPubkeyFingerprint: recipient.fingerprint,
          shareRole: ShareRole.reader,
          createdAt: 1,
        ),
      ];
      final container = makeContainer();
      addTearDown(container.dispose);

      final rows = await container
          .read(filesShareControllerProvider(null))
          .listRecipients('f');
      expect(rows, hasLength(1));
      expect(rows.single.recipientId, recipient.userId);
    });
  });
}

/// Recover the unix-second timestamp the controller stamped into a signature
/// by replaying the small request-handling window: the server reconstructs the
/// canonical from `(fields, timestamp)` and the controller's `now` can only
/// differ from the test's `now` by the time it took to sign. Returns the
/// timestamp that makes the signature verify, or null if none in the window do.
int? _findVerifyingTimestamp({
  required String signature,
  required AuditEventSigInput Function(int timestamp) build,
  required String senderPubkey,
  required String verifierKey,
}) {
  final verifier = ShareCrypto(privateKeyPem: verifierKey);
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  for (var t = now + 1; t >= now - 5; t--) {
    final ok = verifier.verifyAuditEvent(
      input: build(t),
      signature: signature,
      senderPubkey: senderPubkey,
    );
    if (ok) return t;
  }
  return null;
}

/// Whether [needle] appears as a contiguous byte run inside [haystack].
bool _containsSubsequence(Uint8List haystack, Uint8List needle) {
  if (needle.isEmpty || needle.length > haystack.length) return false;
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}
