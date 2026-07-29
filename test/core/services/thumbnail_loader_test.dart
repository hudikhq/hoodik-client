import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/thumbnail_loader.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

/// Replies with the scripted JSON bodies in order and records requests.
class _ScriptedAdapter implements HttpClientAdapter {
  final List<(int, Map<String, dynamic>)> replies;
  final List<RequestOptions> requests = [];
  int _index = 0;

  _ScriptedAdapter(this.replies);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_index >= replies.length) {
      throw StateError('Unexpected request ${options.method} ${options.path}');
    }
    final (status, body) = replies[_index++];
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _dataUrl = 'data:image/png;base64,dGh1bWI=';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late AppDatabase db;
  late Account account;
  late FileCrypto fileCrypto;
  late Uint8List fileKey;
  late String ciphertext;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.insertServer(
      ServersCompanion(
        id: const Value('s1'),
        url: const Value('https://example.test'),
        name: const Value('Test Server'),
      ),
    );
    account = await db.insertAccount(
      AccountsCompanion(
        id: const Value('a1'),
        serverId: const Value('s1'),
        userId: const Value('u1'),
        email: const Value('a@test.io'),
      ),
    );

    const crypto = CryptoService();
    final identity = crypto.generateEd25519KeyPair();
    final wrapping = crypto.generateWrappingKeyPair();
    fileCrypto = FileCrypto(
      privateKeyPem: identity.privatePem,
      wrappingPrivateKeyPem: wrapping.privatePem,
    );
    fileKey = fileCrypto.generateFileKey();
    ciphertext = fileCrypto.encryptThumbnail(
      thumbnailDataUrl: _dataUrl,
      fileKey: fileKey,
      cipher: 'aegis128l',
    );
  });

  tearDown(() async => await db.close());

  ProviderContainer buildContainer(_ScriptedAdapter adapter) {
    final client = ApiClient.createTemporary(baseUrl: 'https://example.test');
    client.dio.httpClientAdapter = adapter;

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        activeAccountProvider.overrideWith((ref) => account),
        apiClientProvider.overrideWithValue(client),
        fileCryptoProvider.overrideWithValue(fileCrypto),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> cacheRow(String fileId, {String? thumbnail}) {
    return db.upsertCachedFile(
      CachedFilesCompanion(
        accountId: const Value('a1'),
        id: Value(fileId),
        encryptedName: const Value('name'),
        mime: const Value('image/png'),
        encryptedThumbnail: Value(thumbnail),
      ),
    );
  }

  FileItem leanFile(String id) => FileItem(
    id: id,
    encryptedName: 'name',
    mime: 'image/png',
    hasThumbnail: true,
  );

  test('decrypts the inline blob without any network call', () async {
    final adapter = _ScriptedAdapter([]);
    final loader = buildContainer(adapter).read(thumbnailLoaderProvider);

    final file = FileItem(
      id: 'f1',
      encryptedName: 'name',
      mime: 'image/png',
      encryptedThumbnail: ciphertext,
    );

    expect(await loader.loadDataUrl(file, fileKey), _dataUrl);
    expect(adapter.requests, isEmpty);
  });

  test(
    'serves the offline-cached ciphertext without any network call',
    () async {
      await cacheRow('f1', thumbnail: ciphertext);

      final adapter = _ScriptedAdapter([]);
      final loader = buildContainer(adapter).read(thumbnailLoaderProvider);

      final bytes = await loader.loadBytes(leanFile('f1'), fileKey);
      expect(bytes, base64Decode('dGh1bWI='));
      expect(adapter.requests, isEmpty);
    },
  );

  test('fetches from the thumbnail route, memoizes, and writes back into '
      'the offline cache', () async {
    await cacheRow('f1');

    final adapter = _ScriptedAdapter([
      (200, {'encrypted_thumbnail': ciphertext}),
    ]);
    final loader = buildContainer(adapter).read(thumbnailLoaderProvider);

    expect(await loader.loadDataUrl(leanFile('f1'), fileKey), _dataUrl);
    expect(adapter.requests.single.path, '/api/storage/f1/thumbnail');

    // Second call resolves from memory — no extra request.
    expect(await loader.loadDataUrl(leanFile('f1'), fileKey), _dataUrl);
    expect(adapter.requests, hasLength(1));

    // The blob landed in the cached row so offline listings keep it.
    final cached = await db.getCachedFileById('a1', 'f1');
    expect(cached?.encryptedThumbnail, ciphertext);
  });

  test('a 404 from an older server resolves to null', () async {
    final adapter = _ScriptedAdapter([
      (404, {'message': 'not_found'}),
    ]);
    final loader = buildContainer(adapter).read(thumbnailLoaderProvider);

    expect(await loader.loadDataUrl(leanFile('f1'), fileKey), isNull);
  });

  test('files without a thumbnail never hit the network', () async {
    final adapter = _ScriptedAdapter([]);
    final loader = buildContainer(adapter).read(thumbnailLoaderProvider);

    final file = FileItem(id: 'f1', encryptedName: 'name', mime: 'text/plain');
    expect(await loader.loadDataUrl(file, fileKey), isNull);
    expect(adapter.requests, isEmpty);
  });
}
