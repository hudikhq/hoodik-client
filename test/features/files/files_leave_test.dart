import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/files/controllers/files_share_controller.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../../helpers/fakes.dart';
import '../shares/shares_test_fakes.dart';

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
  late FakeSharesClient sharesClient;
  late AppDatabase db;

  const senderId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  ProviderContainer makeContainer({String? sender0 = senderId}) {
    return ProviderContainer(
      overrides: [
        decryptedPrivateKeyProvider.overrideWith((ref) => sender.privateKeyPem),
        activeServerUserIdProvider.overrideWithValue(sender0),
        apiClientProvider.overrideWithValue(FakeApiClient(sharesClient)),
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
    sharesClient = FakeSharesClient();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => await db.close());

  group('leaveShare', () {
    FileItem sharedFile(String id, ShareRole role) {
      return FileItem(
        id: id,
        encryptedName: 'enc-name',
        mime: 'text/plain',
        cipher: 'aegis128l',
        isOwner: false,
        shareRole: role,
        finishedUploadAt: 100,
      );
    }

    test(
      'signs a self-targeted revoke at the caller\'s current role',
      () async {
        final file = sharedFile(
          'cccccccc-cccc-cccc-cccc-cccccccccccc',
          ShareRole.editor,
        );
        final container = makeContainer();
        addTearDown(container.dispose);

        final outcome = await container
            .read(filesShareControllerProvider(null))
            .leaveShare(file);

        expect(outcome, isA<ShareSuccess>());
        final (fileId, userId, body) = sharesClient.revokeArgs!;
        expect(fileId, file.id);
        // Sender and recipient are the same identity: the caller removing self.
        expect(userId, senderId);
        expect(body.keys.toSet(), {'event_signature', 'timestamp'});

        // The server rebuilds the revoke canonical from the row it drops: the
        // caller as both sender and recipient, revoke, before = the caller's
        // current role, after = null, at the body timestamp. The signature must
        // verify against that exact reconstruction for some second in the
        // request-handling window.
        final ts = _findVerifyingTimestamp(
          signature: body['event_signature'] as String,
          build: (t) => AuditEventSigInput(
            senderId: senderId,
            recipientId: senderId,
            fileId: file.id,
            action: AuditEventAction.revoke,
            shareRoleBefore: ShareRole.editor,
            shareRoleAfter: null,
            timestamp: t,
          ),
          senderPubkey: sender.publicKeyPem,
          verifierKey: sender.privateKeyPem,
        );
        expect(
          ts,
          isNotNull,
          reason: 'self-revoke canonical must verify at the signed timestamp',
        );
        expect(body['timestamp'], ts);
      },
    );

    test('rejects an owned row before signing (nothing to leave)', () async {
      final owned = _file(
        'dddddddd-dddd-dddd-dddd-dddddddddddd',
        encryptedKey: 'unused',
      );
      final container = makeContainer();
      addTearDown(container.dispose);

      final outcome = await container
          .read(filesShareControllerProvider(null))
          .leaveShare(owned);

      expect(outcome, isA<ShareFailure>());
      expect(sharesClient.revokeArgs, isNull);
    });

    test('fails clearly without a sender UUID', () async {
      final file = sharedFile(
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
        ShareRole.reader,
      );
      final container = makeContainer(sender0: null);
      addTearDown(container.dispose);

      final outcome = await container
          .read(filesShareControllerProvider(null))
          .leaveShare(file);

      expect(outcome, isA<ShareFailure>());
      expect((outcome as ShareFailure).message, contains('initialized'));
      expect(sharesClient.revokeArgs, isNull);
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
