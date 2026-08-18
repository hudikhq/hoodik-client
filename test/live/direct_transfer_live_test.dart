@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/auth/auth_service.dart';
import 'package:hoodik_app/core/auth/secure_pin_storage.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

/// End to end against a real server and a real bucket.
///
/// Held out of `flutter test` by its tag, because it needs both. Run it against
/// a direct-transfer server (default `http://localhost:5443`) with:
///
///     flutter test --tags live test/live/direct_transfer_live_test.dart
///
/// What it proves that the unit tests cannot: that the length the client
/// declares is the one the bucket will accept, that a presigned PUT sent with
/// no credentials is honoured, that `finalize` sees a write the server never
/// handled, and that the bytes come back unchanged. Each of those is a
/// contract with software we do not control, and none of them fails in a way
/// a mock would reproduce.
const _serverUrl = String.fromEnvironment(
  'HOODIK_LIVE_URL',
  defaultValue: 'http://localhost:5443',
);

class _FakePinStorage extends SecurePinStorage {
  _FakePinStorage() : super.forTesting(const FlutterSecureStorage());

  @override
  Future<String?> read(String accountId) async => null;

  @override
  Future<bool> has(String accountId) async => false;
}

Future<bool> _directTransferServerIsUp() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final req = await client.getUrl(Uri.parse('$_serverUrl/api/readiness'));
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    return (jsonDecode(body) as Map)['direct_transfer'] == true;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

void main() {
  late AppDatabase db;
  late AuthService auth;
  late Directory support;

  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // flutter_test installs an HttpOverrides that answers every request with an
    // empty 400 so unit tests cannot reach the network. This suite exists to
    // reach it.
    HttpOverrides.global = null;

    await RustLib.init();
    support = Directory.systemTemp.createTempSync('hoodik-live');

    // The real client keeps its cookie jar under the app support directory,
    // which is a platform channel this harness has no host for.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => support.path,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider_macos'),
      (call) async => support.path,
    );
  });

  tearDownAll(() {
    if (support.existsSync()) support.deleteSync(recursive: true);
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.insertServer(
      const ServersCompanion(
        id: Value('live'),
        url: Value(_serverUrl),
        name: Value('live'),
      ),
    );
    auth = AuthService(db, _FakePinStorage());
  });

  tearDown(() async => db.close());

  test(
    'a file written straight to the bucket comes back byte for byte',
    () async {
      if (!await _directTransferServerIsUp()) {
        markTestSkipped('no direct-transfer server at $_serverUrl');
        return;
      }

      try {
        final server = (await db.getAllServers()).single;
        final account = await auth.register(
          server: server,
          email: 'direct-${DateTime.now().microsecondsSinceEpoch}@example.com',
          password: 'correct-horse-battery-staple-9',
        );

        final client = auth.activeClient!;
        final fileCrypto = FileCrypto(
          privateKeyPem: auth.decryptedPrivateKey!,
          wrappingPrivateKeyPem: auth.decryptedWrappingPrivateKey,
          crypto: const CryptoService(),
        );

        // One chunk of recognisable plaintext, encrypted exactly as the upload
        // pipeline encrypts it.
        const cipher = 'aegis128l';
        final plaintext = Uint8List.fromList(
          List.generate(4096, (i) => (i * 7 + 13) % 251),
        );
        final fileKey = fileCrypto.generateFileKey(cipher: cipher);
        final ciphertext = fileCrypto.encryptChunk(
          data: plaintext,
          fileKey: fileKey,
          cipher: cipher,
          chunkIndex: 0,
        );

        const name = 'direct-upload-probe.bin';
        final entry = await client.files.createFileEntry(
          encryptedKey: fileCrypto.encryptFileKey(
            fileKey: fileKey,
            publicKeyPem: account.wrappingPublicKey ?? account.publicKey!,
          ),
          nameHash: fileCrypto.hashFileName(name),
          encryptedName: fileCrypto.encryptFileName(
            name: name,
            fileKey: fileKey,
            cipher: cipher,
          ),
          mime: 'application/octet-stream',
          size: plaintext.length,
          chunks: 1,
          cipher: cipher,
        );
        final fileId = entry['id'] as String;

        final token = await client.auth.requestTransferToken(
          fileId: fileId,
          action: 'upload',
        );

        // The ciphertext length, not the plaintext one. The server signs whatever
        // is declared here into the URL, so getting it wrong is a bucket refusal
        // rather than a server error.
        final manifest = await client.files.fetchUploadUrls(
          fileId: fileId,
          transferToken: token.token,
          chunkSizes: {0: ciphertext.length},
        );
        expect(
          manifest,
          isNotNull,
          reason: 'server would not sign upload urls',
        );
        expect(manifest!.urls.single, isNotEmpty);

        final putResp = await _put(manifest.urls.single, ciphertext);
        expect(
          putResp,
          inInclusiveRange(200, 299),
          reason: 'bucket refused the presigned PUT',
        );

        await client.files.finalizeDirectUpload(
          fileId: fileId,
          transferToken: token.token,
        );

        final stored = await client.files.getFileMetadata(fileId);
        expect(
          stored['finished_upload_at'],
          isNotNull,
          reason: 'finalize did not commit a version the server never wrote',
        );

        // Back out through the read manifest, again with nothing attached.
        final readUrls = await client.files.fetchChunkUrls(fileId);
        expect(readUrls, isNotNull);
        final fetched = await _get(readUrls!.urls.single);

        expect(
          fetched,
          equals(ciphertext),
          reason: 'bucket returned other bytes',
        );
        expect(
          fileCrypto.decryptChunk(
            data: Uint8List.fromList(fetched),
            fileKey: fileKey,
            cipher: cipher,
            chunkIndex: 0,
          ),
          equals(plaintext),
        );
      } on DioException catch (e) {
        // A live failure is a remote contract failure, and Dio's default
        // message says only that a status code was unexpected. Which call,
        // and what the server said about it, is the whole diagnosis.
        fail(
          '${e.requestOptions.method} ${e.requestOptions.path} '
          '-> ${e.response?.statusCode}: ${e.response?.data}',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// Exactly what the OS task sends: a PUT carrying its length and nothing else.
Future<int> _put(String url, Uint8List body) async {
  final client = HttpClient();
  try {
    final req = await client.putUrl(Uri.parse(url));
    req.headers.contentLength = body.length;
    req.add(body);
    final resp = await req.close();
    await resp.drain<void>();
    return resp.statusCode;
  } finally {
    client.close(force: true);
  }
}

Future<List<int>> _get(String url) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    final resp = await req.close();
    // Awaited inside the try: the finally force-closes the client, and a bare
    // return would do that while the body was still draining.
    return await resp.fold<List<int>>(
      <int>[],
      (acc, chunk) => acc..addAll(chunk),
    );
  } finally {
    client.close(force: true);
  }
}
