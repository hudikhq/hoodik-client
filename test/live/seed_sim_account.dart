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

/// Not a test — a seeder, so the simulator has an account and a file big
/// enough for the background path to be worth watching.
///
///     flutter test --tags live test/live/seed_sim_account.dart
///
/// Writes every chunk straight into the bucket, so the file on the server is
/// one a direct download will actually be served from.
const _serverUrl = String.fromEnvironment(
  'HOODIK_LIVE_URL',
  defaultValue: 'http://localhost:5443',
);
const _email = String.fromEnvironment(
  'SIM_EMAIL',
  defaultValue: 'sim@example.com',
);
// Alphanumeric on purpose: the simulator types through the host keyboard
// layout, and anything else comes out as a different character on a non-US
// one.
const _password = String.fromEnvironment(
  'SIM_PASSWORD',
  defaultValue: 'simtestpassword1',
);
const _chunkSize = 4 * 1024 * 1024;
const _chunks = int.fromEnvironment('SIM_CHUNKS', defaultValue: 10);

class _FakePinStorage extends SecurePinStorage {
  _FakePinStorage() : super.forTesting(const FlutterSecureStorage());
  @override
  Future<String?> read(String accountId) async => null;
  @override
  Future<bool> has(String accountId) async => false;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('seed', () async {
    HttpOverrides.global = null;
    await RustLib.init();
    final support = Directory.systemTemp.createTempSync('hoodik-seed');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => support.path,
    );

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.insertServer(
      const ServersCompanion(
        id: Value('live'),
        url: Value(_serverUrl),
        name: Value('live'),
      ),
    );
    final auth = AuthService(db, _FakePinStorage());
    final server = (await db.getAllServers()).single;

    try {
      await auth.register(
        server: server,
        email: _email,
        password: _password,
      );
    } on DioException {
      await auth.login(server: server, email: _email, password: _password);
    }

    final client = auth.activeClient!;
    final account = auth.activeAccount!;
    final fileCrypto = FileCrypto(
      privateKeyPem: auth.decryptedPrivateKey!,
      wrappingPrivateKeyPem: auth.decryptedWrappingPrivateKey,
      crypto: const CryptoService(),
    );

    const cipher = 'aegis128l';
    final fileKey = fileCrypto.generateFileKey(cipher: cipher);
    final name = 'sim-probe-${DateTime.now().millisecondsSinceEpoch}.bin';

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
      size: _chunkSize * _chunks,
      chunks: _chunks,
      cipher: cipher,
    );
    final fileId = entry['id'] as String;
    final token = await client.auth.requestTransferToken(
      fileId: fileId,
      action: 'upload',
    );

    final bodies = <int, List<int>>{};
    for (var i = 0; i < _chunks; i++) {
      bodies[i] = fileCrypto.encryptChunk(
        data: Uint8List.fromList(
          List.generate(_chunkSize, (b) => (b + i) % 251),
        ),
        fileKey: fileKey,
        cipher: cipher,
        chunkIndex: i,
      );
    }

    final manifest = await client.files.fetchUploadUrls(
      fileId: fileId,
      transferToken: token.token,
      chunkSizes: bodies.map((k, v) => MapEntry(k, v.length)),
    );

    for (var i = 0; i < _chunks; i++) {
      final http = HttpClient();
      final req = await http.putUrl(Uri.parse(manifest!.urls[i]));
      req.headers.contentLength = bodies[i]!.length;
      req.add(bodies[i]!);
      final resp = await req.close();
      await resp.drain<void>();
      expect(resp.statusCode, inInclusiveRange(200, 299));
      http.close(force: true);
      // ignore: avoid_print
      print('chunk $i uploaded');
    }

    await client.files.finalizeDirectUpload(
      fileId: fileId,
      transferToken: token.token,
    );

    // ignore: avoid_print
    print(
      jsonEncode({
        'email': _email,
        'password': _password,
        'file_id': fileId,
        'name': name,
        'chunks': _chunks,
      }),
    );

    await db.close();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
