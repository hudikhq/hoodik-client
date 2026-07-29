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

/// The chunk re-upload tail and the failure paths. The fork crypto contract
/// (body shape, re-key, audit signature) lives in
/// `files_fork_controller_test.dart` (split to stay under the new-file ceiling).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late rust.RsaKeyPair caller;
  late RecordingSharesClient sharesClient;
  late RecordingFilesClient filesClient;
  late FakeForkDownloader downloader;

  const callerId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const sourceId = '11111111-1111-1111-1111-111111111111';
  const sourceName = 'quarterly-report.pdf';

  // 9 MiB → three 4 MiB upload chunks.
  final plaintext = Uint8List.fromList(
    List<int>.generate(9 * 1024 * 1024, (i) => i % 251),
  );

  late FileItem source;
  late Uint8List sourceKey;

  ProviderContainer makeContainer({String? cid = callerId}) {
    final seed = FilesState(
      loading: false,
      decryptedNames: const {sourceId: sourceName},
      decryptedKeys: {sourceId: sourceKey},
    );
    return ProviderContainer(
      overrides: [
        decryptedPrivateKeyProvider.overrideWith((ref) => caller.privateKeyPem),
        activeServerUserIdProvider.overrideWithValue(cid),
        activeAccountProvider.overrideWith(
          (ref) => forkAccount(caller.publicKeyPem),
        ),
        apiClientProvider.overrideWithValue(
          FakeForkApiClient(sharesClient, filesClient, FakeForkAuthClient()),
        ),
        fileDownloaderProvider.overrideWithValue(downloader),
        filesNotifierProvider.overrideWith(() => SeededFilesNotifier(seed)),
      ],
    );
  }

  setUp(() {
    caller = rust.generateRsaKeypair();
    sourceKey = _crypto.generateSymmetricKey(cipher: 'chacha20poly1305');
    final callerFileCrypto = FileCrypto(privateKeyPem: caller.privateKeyPem);
    source = FileItem(
      id: sourceId,
      encryptedName: 'enc-name',
      encryptedKey: callerFileCrypto.encryptFileKey(
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
    sharesClient = RecordingSharesClient();
    filesClient = RecordingFilesClient();
    downloader = FakeForkDownloader(plaintext);
  });

  group('chunk re-upload', () {
    test('uploads the re-encrypted chunks under the returned id and finalizes '
        'the posted sha256', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(filesForkControllerProvider(null)).fork(source);

      // Three 4 MiB upload chunks for a 9 MiB plaintext.
      expect(filesClient.uploadedChunks, hasLength(3));
      expect(
        filesClient.uploadedToFileIds,
        everyElement(sharesClient.returnedId),
      );
      expect(filesClient.finalizedFileId, sharesClient.returnedId);
      expect(filesClient.finalizedSha256, sharesClient.forkBody!['sha256']);
      expect(filesClient.finalizedSha256, _crypto.sha256(data: plaintext));
    });

    test('uploaded chunks decrypt under the new key back to the source '
        'plaintext', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(filesForkControllerProvider(null)).fork(source);

      final newKey = _crypto.hexDecode(
        _crypto.rsaDecrypt(
          ciphertextBase64: sharesClient.forkBody!['encrypted_key'] as String,
          privateKeyPem: caller.privateKeyPem,
        ),
      );
      final fileCrypto = FileCrypto(privateKeyPem: caller.privateKeyPem);
      final reassembled = BytesBuilder();
      for (final (index, chunk) in filesClient.uploadedChunks.indexed) {
        reassembled.add(
          fileCrypto.decryptChunk(
            data: chunk,
            fileKey: newKey,
            cipher: 'chacha20poly1305',
            chunkIndex: index,
          ),
        );
      }
      expect(reassembled.toBytes(), plaintext);
    });
  });

  group('failure paths', () {
    test('surfaces a "space" message on 409 fork_quota_exceeded', () async {
      sharesClient.quotaExceeded = true;
      final container = makeContainer();
      addTearDown(container.dispose);

      final outcome = await container
          .read(filesForkControllerProvider(null))
          .fork(source);

      expect(outcome, isA<ForkFailure>());
      expect((outcome as ForkFailure).message.toLowerCase(), contains('space'));
      // No chunks uploaded when the metadata POST is rejected up front.
      expect(filesClient.uploadedChunks, isEmpty);
    });

    test('rejects a directory before any network call', () async {
      final dir = FileItem(
        id: sourceId,
        encryptedName: 'enc',
        mime: 'dir',
        isOwner: false,
        shareRole: ShareRole.coOwner,
      );
      final container = makeContainer();
      addTearDown(container.dispose);

      final outcome = await container
          .read(filesForkControllerProvider(null))
          .fork(dir);

      expect(outcome, isA<ForkFailure>());
      expect(sharesClient.forkBody, isNull);
      expect(downloader.requested, isNull);
    });

    test('fails clearly without a caller UUID', () async {
      final container = makeContainer(cid: null);
      addTearDown(container.dispose);

      final outcome = await container
          .read(filesForkControllerProvider(null))
          .fork(source);

      expect(outcome, isA<ForkFailure>());
      expect((outcome as ForkFailure).message, contains('initialized'));
      expect(sharesClient.forkBody, isNull);
    });
  });
}
