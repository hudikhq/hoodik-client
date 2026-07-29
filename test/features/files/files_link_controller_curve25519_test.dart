import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/files/controllers/files_link_controller.dart';
import 'package:hoodik_app/features/files/providers/files_notifier.dart';
import 'package:hoodik_app/features/files/providers/files_state.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

class _CapturingLinksClient extends Fake implements LinksClient {
  Map<String, dynamic>? body;

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    body = data;
    return {'id': 'link-id'};
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._links);

  final LinksClient _links;

  @override
  LinksClient get links => _links;
}

/// Seeds the per-directory notifier with a decrypted file key so the controller
/// can build a link without a network round-trip or worker wiring.
class _SeededFilesNotifier extends FilesNotifier {
  _SeededFilesNotifier(this._keys);

  final Map<String, Uint8List> _keys;

  @override
  FilesState build(String? arg) =>
      FilesState(loading: false, decryptedKeys: _keys);
}

const _crypto = CryptoService();

FileItem _file(String id, String encryptedKey) => FileItem(
  id: id,
  encryptedName: 'enc',
  encryptedKey: encryptedKey,
  mime: 'text/plain',
  cipher: 'aegis128l',
  finishedUploadAt: 1,
);

Account _account({required String publicKey, String? wrappingPublicKey}) =>
    Account(
      id: 'acct',
      serverId: 'srv',
      userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      email: 'me@example.com',
      publicKey: publicKey,
      wrappingPublicKey: wrappingPublicKey,
      isActive: true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late _CapturingLinksClient links;
  late Uint8List fileKey;
  final file = _file('11111111-1111-1111-1111-111111111111', 'unused');

  setUp(() {
    links = _CapturingLinksClient();
    // RustLib is only ready after setUpAll, so the key can't be a field init.
    fileKey = _crypto.generateSymmetricKey();
  });

  ProviderContainer container({
    required FileCrypto fileCrypto,
    required Account account,
  }) => ProviderContainer(
    overrides: [
      fileCryptoProvider.overrideWithValue(fileCrypto),
      apiClientProvider.overrideWithValue(_FakeApiClient(links)),
      activeAccountProvider.overrideWith((ref) => account),
      filesNotifierProvider.overrideWith(
        () => _SeededFilesNotifier({file.id: fileKey}),
      ),
    ],
  );

  String linkKeyHexFromUrl(String url) => url.split('#').last;

  test(
    'curve account wraps the link key to the hybrid wrapping key and round-trips',
    () async {
      final identity = _crypto.generateEd25519KeyPair();
      final wrapping = _crypto.generateWrappingKeyPair();
      final c = container(
        fileCrypto: FileCrypto(
          privateKeyPem: identity.privatePem,
          wrappingPrivateKeyPem: wrapping.privatePem,
        ),
        account: _account(
          publicKey: identity.publicPem,
          wrappingPublicKey: wrapping.publicPem,
        ),
      );
      addTearDown(c.dispose);

      final outcome = await c
          .read(filesLinkControllerProvider(null))
          .createLink(file);

      // Before the fix the controller wrapped to the Ed25519 identity key and the
      // wrapping Rust side rejected the OID, so createLink returned failure.
      expect(outcome.link, isNotNull);
      final linkKey = _crypto.hexDecode(linkKeyHexFromUrl(outcome.link!.url));
      final unwrapped = _crypto.wrappingUnwrap(
        blob: links.body!['encrypted_link_key'] as String,
        privatePem: wrapping.privatePem,
      );
      expect(unwrapped, equals(linkKey));
    },
  );

  test('legacy RSA account still wraps the link key with RSA', () async {
    final kp = rust.generateRsaKeypair();
    final c = container(
      fileCrypto: FileCrypto(privateKeyPem: kp.privateKeyPem),
      account: _account(publicKey: kp.publicKeyPem),
    );
    addTearDown(c.dispose);

    final outcome = await c
        .read(filesLinkControllerProvider(null))
        .createLink(file);

    expect(outcome.link, isNotNull);
    final linkKey = _crypto.hexDecode(linkKeyHexFromUrl(outcome.link!.url));
    final unwrapped = _crypto.hexDecode(
      _crypto.rsaDecrypt(
        ciphertextBase64: links.body!['encrypted_link_key'] as String,
        privateKeyPem: kp.privateKeyPem,
      ),
    );
    expect(unwrapped, equals(linkKey));
  });
}
