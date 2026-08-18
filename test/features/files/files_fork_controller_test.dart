import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/files/controllers/files_fork_controller.dart';
import 'package:hoodik_app/features/files/providers/files_notifier.dart';
import 'package:hoodik_app/features/files/providers/files_state.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

import 'fork_test_harness.dart';

const _crypto = CryptoService();

/// The fork crypto contract: the body it posts, the re-key, and the audit
/// signature. The chunk re-upload tail and the failure paths live in
/// `files_fork_chunks_test.dart` (split to stay under the new-file ceiling).
/// `name_hash` is an HMAC under the account's search key, not a bare digest of
/// the name. A plain SHA-256 of a file name is reversible with a dictionary of
/// common names, which is the half of the old scheme that lived outside the
/// token index.
String _expectedNameHash(String privateKeyPem, String name) =>
    FileCrypto(privateKeyPem: privateKeyPem).hashFileName(name);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late rust.RsaKeyPair caller;
  late rust.RsaKeyPair owner;
  late RecordingSharesClient sharesClient;
  late RecordingFilesClient filesClient;
  late FakeForkDownloader downloader;

  const callerId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const sourceId = '11111111-1111-1111-1111-111111111111';
  const sourceName = 'quarterly-report.pdf';

  // A 9 MiB plaintext spans three 4 MiB upload chunks — proving the controller
  // re-slices on its own chunk size rather than copying the source's.
  final plaintext = Uint8List.fromList(
    List<int>.generate(9 * 1024 * 1024, (i) => i % 251),
  );

  late FileItem source;
  late Uint8List sourceKey;

  ProviderContainer makeContainer({FilesState? seed}) {
    final resolved =
        seed ??
        FilesState(
          loading: false,
          decryptedNames: const {sourceId: sourceName},
          decryptedKeys: {sourceId: sourceKey},
        );
    return ProviderContainer(
      overrides: [
        decryptedPrivateKeyProvider.overrideWith((ref) => caller.privateKeyPem),
        activeServerUserIdProvider.overrideWithValue(callerId),
        activeAccountProvider.overrideWith(
          (ref) => forkAccount(caller.publicKeyPem),
        ),
        apiClientProvider.overrideWithValue(
          FakeForkApiClient(sharesClient, filesClient, FakeForkAuthClient()),
        ),
        fileDownloaderProvider.overrideWithValue(downloader),
        filesNotifierProvider.overrideWith(() => SeededFilesNotifier(resolved)),
      ],
    );
  }

  setUp(() {
    caller = rust.generateRsaKeypair();
    owner = rust.generateRsaKeypair();
    sourceKey = _crypto.generateSymmetricKey(cipher: 'chacha20poly1305');
    final callerFileCrypto = FileCrypto(privateKeyPem: caller.privateKeyPem);
    source = FileItem(
      id: sourceId,
      encryptedName: 'enc-name',
      encryptedKey: callerFileCrypto.encryptFileKey(
        fileKey: sourceKey,
        publicKeyPem: caller.publicKeyPem,
      ),
      encryptedThumbnail: callerFileCrypto.encryptThumbnail(
        thumbnailDataUrl: 'data:image/png;base64,AAAA',
        fileKey: sourceKey,
        cipher: 'chacha20poly1305',
      ),
      mime: 'application/pdf',
      size: plaintext.length,
      chunks: 6,
      cipher: 'chacha20poly1305',
      isOwner: false,
      shareRole: ShareRole.coOwner,
      finishedUploadAt: 100,
    );
    sharesClient = RecordingSharesClient();
    filesClient = RecordingFilesClient();
    downloader = FakeForkDownloader(plaintext);
  });

  Uint8List newKeyFromBody() => _crypto.hexDecode(
    _crypto.rsaDecrypt(
      ciphertextBase64: sharesClient.forkBody!['encrypted_key'] as String,
      privateKeyPem: caller.privateKeyPem,
    ),
  );

  group('fork body', () {
    test('posts to the source id with the required fields and preserves the '
        'source cipher', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final outcome = await container
          .read(filesForkControllerProvider(null))
          .fork(source);

      expect(outcome, isA<ForkSuccess>());
      expect(sharesClient.forkedSourceId, sourceId);

      final body = sharesClient.forkBody!;
      // The server validates new_file_id, encrypted_metadata, name_hash, mime,
      // encrypted_key, event_signature, timestamp, plus size/chunks > 0.
      expect(body['new_file_id'], isA<String>());
      expect(body['new_file_id'], isNot(sourceId));
      expect(body['mime'], 'application/pdf');
      expect(body['cipher'], 'chacha20poly1305');
      expect(body['size'], plaintext.length);
      expect(body['chunks'], 3);
      expect(body['encrypted_metadata'], isA<String>());
      expect(body['encrypted_key'], isA<String>());
      expect(body['event_signature'], isA<String>());
      expect(body['timestamp'], isA<int>());
      expect(body['name_hash'], _expectedNameHash(caller.privateKeyPem, sourceName));
      expect(body['search_tokens_root'], isA<List<dynamic>>());
      expect(body['search_tokens_file'], isA<List<dynamic>>());
    });

    test('name_hash is the keyed tag of the plaintext name, not the '
        'placeholder', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(filesForkControllerProvider(null)).fork(source);

      expect(
        sharesClient.forkBody!['name_hash'],
        _expectedNameHash(caller.privateKeyPem, sourceName),
      );
    });

    test(
      'with a cold cache, derives the name from the source ciphertext so '
      'name_hash is still the true keyed tag of the name, not the placeholder',
      () async {
        // Neither the name nor the key is in the listing cache — the controller
        // must RSA-unwrap the key from the row and decrypt the name from the
        // source ciphertext, never the `[Encrypted]…` placeholder displayName
        // would otherwise return (which would poison server-side dedup/search).
        final fc = FileCrypto(privateKeyPem: caller.privateKeyPem);
        final coldSource = FileItem(
          id: sourceId,
          encryptedName: fc.encryptFileName(
            name: sourceName,
            fileKey: sourceKey,
            cipher: 'chacha20poly1305',
          ),
          encryptedKey: fc.encryptFileKey(
            fileKey: sourceKey,
            publicKeyPem: caller.publicKeyPem,
          ),
          mime: 'application/pdf',
          size: plaintext.length,
          chunks: 6,
          cipher: 'chacha20poly1305',
          isOwner: false,
          shareRole: ShareRole.coOwner,
          finishedUploadAt: 100,
        );
        final container = makeContainer(seed: const FilesState(loading: false));
        addTearDown(container.dispose);

        final outcome = await container
            .read(filesForkControllerProvider(null))
            .fork(coldSource);

        expect(outcome, isA<ForkSuccess>());
        expect(
          sharesClient.forkBody!['name_hash'],
          _expectedNameHash(caller.privateKeyPem, sourceName),
        );
        final name = fc.decryptFileName(
          encryptedNameHex:
              sharesClient.forkBody!['encrypted_metadata'] as String,
          fileKey: newKeyFromBody(),
          cipher: 'chacha20poly1305',
        );
        expect(name, sourceName);
      },
    );
  });

  group('re-key', () {
    test('encrypted_key is the fresh key wrapped for the caller and unwraps '
        'with the caller key', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(filesForkControllerProvider(null)).fork(source);

      final wrap = sharesClient.forkBody!['encrypted_key'] as String;
      // Decrypts only with the caller's private key, to the new key hex.
      final newKeyHex = _crypto.rsaDecrypt(
        ciphertextBase64: wrap,
        privateKeyPem: caller.privateKeyPem,
      );
      expect(newKeyHex, isNotEmpty);
      // The new key differs from the source key — fork re-keys, never reuses.
      expect(newKeyHex, isNot(_crypto.hexEncode(sourceKey)));
    });

    test('encrypted_metadata decrypts under the new key back to the source '
        'name', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(filesForkControllerProvider(null)).fork(source);

      final fileCrypto = FileCrypto(privateKeyPem: caller.privateKeyPem);
      final name = fileCrypto.decryptFileName(
        encryptedNameHex:
            sharesClient.forkBody!['encrypted_metadata'] as String,
        fileKey: newKeyFromBody(),
        cipher: 'chacha20poly1305',
      );
      expect(name, sourceName);
    });

    test('encrypted_thumbnail decrypts under the new key back to the source '
        'thumbnail', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(filesForkControllerProvider(null)).fork(source);

      final body = sharesClient.forkBody!;
      expect(body['encrypted_thumbnail'], isA<String>());
      final fileCrypto = FileCrypto(privateKeyPem: caller.privateKeyPem);
      final thumb = fileCrypto.decryptThumbnail(
        encryptedThumbnailHex: body['encrypted_thumbnail'] as String,
        fileKey: newKeyFromBody(),
        cipher: 'chacha20poly1305',
      );
      expect(thumb, 'data:image/png;base64,AAAA');
    });

    test('downloads the source under the caller-wrapped key', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(filesForkControllerProvider(null)).fork(source);

      expect(downloader.requested?.id, sourceId);
      expect(downloader.requestedKey, sourceKey);
    });
  });

  group('audit event', () {
    test('verifies against the caller over the SOURCE id as a fork with a '
        'null recipient', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(filesForkControllerProvider(null)).fork(source);

      // The server reconstructs AuditEventSigInputV1 from its own state:
      // sender = caller, recipient = none, file = the SOURCE id, action = fork,
      // no before/after role, at the signed timestamp. The signature must
      // verify against that exact canonical for some second in the
      // request-handling window.
      final ts = findVerifyingTimestamp(
        signature: sharesClient.forkBody!['event_signature'] as String,
        build: (t) => AuditEventSigInput(
          senderId: callerId,
          recipientId: null,
          fileId: sourceId,
          action: AuditEventAction.fork,
          shareRoleBefore: null,
          shareRoleAfter: null,
          timestamp: t,
        ),
        senderPubkey: caller.publicKeyPem,
        verifierKey: caller.privateKeyPem,
      );
      expect(
        ts,
        isNotNull,
        reason: 'fork canonical must verify at the signed timestamp',
      );
    });

    test(
      'does not verify against the owner key (signed by the caller)',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);

        await container.read(filesForkControllerProvider(null)).fork(source);

        final verifier = ShareCrypto(privateKeyPem: caller.privateKeyPem);
        final ts = sharesClient.forkBody!['timestamp'] as int;
        final ok = verifier.verifyAuditEvent(
          input: AuditEventSigInput(
            senderId: callerId,
            recipientId: null,
            fileId: sourceId,
            action: AuditEventAction.fork,
            shareRoleBefore: null,
            shareRoleAfter: null,
            timestamp: ts,
          ),
          signature: sharesClient.forkBody!['event_signature'] as String,
          senderPubkey: owner.publicKeyPem,
        );
        expect(ok, isFalse);
      },
    );
  });
}
