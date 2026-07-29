import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/crypto_service_migration.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

/// Real-crypto coverage for the migration re-wrap and the envelope key bundle.
/// The ceremony discards the old RSA key once it commits, so a file key OR a
/// public-link key that fails to re-wrap must abort the whole migration — these
/// prove both sets survive the re-key and the bundle keeps its `rsa:` segment.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();

  late rust.RsaKeyPair rsa;
  late rust.Ed25519KeyPair ed;
  setUpAll(() {
    // 2048-bit keygen is slow; generate one legacy identity and reuse it.
    rsa = rust.generateRsaKeypair();
    ed = crypto.generateEd25519KeyPair();
  });

  // How a legacy account stores a file/link key: RSA-encrypt the raw key bytes'
  // hex string (matches FileCrypto.encryptFileKey / encryptLinkKey RSA path).
  String legacyWrap(Uint8List keyBytes) => crypto.rsaEncrypt(
    plaintext: crypto.hexEncode(keyBytes),
    publicKeyPem: rsa.publicKeyPem,
  );

  // The re-wrap runs in a one-shot isolate in production; drive it the same way
  // so RustLib initializes in a fresh isolate (a direct call double-inits). The
  // legacy wraps and the new X key are built in the main isolate and sent in.
  Future<MigrationRewrap> rewrap({
    required List<Map<String, dynamic>> fileKeys,
    required List<Map<String, dynamic>> linkKeys,
    required String newXPub,
  }) {
    final oldRsaPriv = rsa.privateKeyPem;
    final newEdPriv = ed.privatePem;
    return Isolate.run(
      () => rewrapMigrationKeys(
        fileKeys: fileKeys,
        linkKeys: linkKeys,
        oldRsaPrivPem: oldRsaPriv,
        newXPub: newXPub,
        newEdPriv: newEdPriv,
      ),
    );
  }

  group('rewrapMigrationKeys', () {
    test(
      're-wraps every file and link key with the exact field names',
      () async {
        final fileKeys = [
          crypto.generateSymmetricKey(),
          crypto.generateSymmetricKey(),
        ];
        final linkKeys = [
          crypto.generateSymmetricKey(cipher: 'ascon128a'),
          crypto.generateSymmetricKey(cipher: 'ascon128a'),
          crypto.generateSymmetricKey(cipher: 'ascon128a'),
        ];
        final newX = crypto.generateWrappingKeyPair();

        final result = await rewrap(
          fileKeys: [
            {'file_id': 'f1', 'encrypted_key': legacyWrap(fileKeys[0])},
            {'file_id': 'f2', 'encrypted_key': legacyWrap(fileKeys[1])},
          ],
          linkKeys: [
            {
              'link_id': 'l1',
              'encrypted_link_key': legacyWrap(linkKeys[0]),
              'file_id': '11111111-1111-1111-1111-111111111111',
            },
            {
              'link_id': 'l2',
              'encrypted_link_key': legacyWrap(linkKeys[1]),
              'file_id': '22222222-2222-2222-2222-222222222222',
            },
            {
              'link_id': 'l3',
              'encrypted_link_key': legacyWrap(linkKeys[2]),
              'file_id': '33333333-3333-3333-3333-333333333333',
            },
          ],
          newXPub: newX.publicPem,
        );

        expect(result.fileKeys, hasLength(2));
        expect(result.linkKeys, hasLength(3));
        for (final e in result.fileKeys) {
          expect(e.keys.toSet(), {'file_id', 'encrypted_key'});
        }
        // The re-wrapped link entries carry the re-signature but NOT the file_id
        // — the server looks the file_id up from its own row to verify.
        for (final e in result.linkKeys) {
          expect(e.keys.toSet(), {
            'link_id',
            'encrypted_link_key',
            'signature',
          });
        }
        expect(result.linkKeys.map((e) => e['link_id']), ['l1', 'l2', 'l3']);
      },
    );

    test(
      're-signs each link over its file_id under the new identity key',
      () async {
        final linkKey = crypto.generateSymmetricKey(cipher: 'ascon128a');
        final newX = crypto.generateWrappingKeyPair();
        const fileId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

        final result = await rewrap(
          fileKeys: const [],
          linkKeys: [
            {
              'link_id': 'l1',
              'encrypted_link_key': legacyWrap(linkKey),
              'file_id': fileId,
            },
          ],
          newXPub: newX.publicPem,
        );

        final signature = result.linkKeys.single['signature'] as String;
        // The canonical is the file UUID string, verifiable under the new key.
        expect(
          crypto.ed25519Verify(
            message: fileId,
            signature: signature,
            publicPem: ed.publicPem,
          ),
          isTrue,
        );
        expect(
          crypto.ed25519Verify(
            message: 'wrong-file-id',
            signature: signature,
            publicPem: ed.publicPem,
          ),
          isFalse,
        );
        // The self-check sample mirrors the emitted entry.
        expect(result.sampleLinkFileId, fileId);
        expect(result.sampleLinkSignature, signature);
      },
    );

    test('a re-wrapped link key unwraps under the new wrapping key to the '
        'original bytes', () async {
      final linkKey = crypto.generateSymmetricKey(cipher: 'ascon128a');
      final newX = crypto.generateWrappingKeyPair();

      final result = await rewrap(
        fileKeys: const [],
        linkKeys: [
          {
            'link_id': 'l1',
            'encrypted_link_key': legacyWrap(linkKey),
            'file_id': '99999999-9999-9999-9999-999999999999',
          },
        ],
        newXPub: newX.publicPem,
      );

      final blob = result.linkKeys.single['encrypted_link_key'] as String;
      final recovered = crypto.wrappingUnwrap(
        blob: blob,
        privatePem: newX.privatePem,
      );
      expect(recovered, equals(linkKey));
      // The self-check sample is the same key, so it round-trips too.
      expect(result.sampleLinkKey, equals(linkKey));
      expect(
        crypto.wrappingUnwrap(
          blob: result.sampleLinkBlob!,
          privatePem: newX.privatePem,
        ),
        equals(linkKey),
      );
    });

    test('an account with zero links still re-wraps its file keys', () async {
      final fileKey = crypto.generateSymmetricKey();
      final newX = crypto.generateWrappingKeyPair();

      final result = await rewrap(
        fileKeys: [
          {'file_id': 'f1', 'encrypted_key': legacyWrap(fileKey)},
        ],
        linkKeys: const [],
        newXPub: newX.publicPem,
      );

      expect(result.fileKeys, hasLength(1));
      expect(result.linkKeys, isEmpty);
      expect(result.sampleLinkKey, isNull);
      expect(result.sampleLinkBlob, isNull);
      expect(result.sampleFileKey, equals(fileKey));
    });

    test('a single undecryptable link key aborts the whole re-wrap', () async {
      final newX = crypto.generateWrappingKeyPair();

      await expectLater(
        rewrap(
          fileKeys: [
            {
              'file_id': 'f1',
              'encrypted_key': legacyWrap(crypto.generateSymmetricKey()),
            },
          ],
          // Valid base64, but not a valid RSA ciphertext — the re-wrap throws.
          linkKeys: [
            {
              'link_id': 'l1',
              'encrypted_link_key': 'bm9wZQ==',
              'file_id': '00000000-0000-0000-0000-000000000000',
            },
          ],
          newXPub: newX.publicPem,
        ),
        throwsA(anything),
      );
    });
  });

  group('key bundle codec', () {
    test('encode -> decode preserves the rsa, ed and x segments', () {
      final ed = crypto.generateEd25519KeyPair();
      final x = crypto.generateWrappingKeyPair();

      final encoded = encodeKeyBundle(
        identity: ed.privatePem,
        wrapping: x.privatePem,
        legacyRsa: rsa.privateKeyPem,
      );
      final decoded = decodeKeyBundle(Uint8List.fromList(encoded.codeUnits));

      expect(decoded.identity, ed.privatePem);
      expect(decoded.wrapping, x.privatePem);
      expect(decoded.legacyRsa, rsa.privateKeyPem);
    });

    test('a natively registered v2 bundle carries no rsa segment', () {
      final ed = crypto.generateEd25519KeyPair();
      final x = crypto.generateWrappingKeyPair();

      final encoded = encodeKeyBundle(
        identity: ed.privatePem,
        wrapping: x.privatePem,
      );
      expect(encoded.contains('rsa:'), isFalse);

      final decoded = decodeKeyBundle(Uint8List.fromList(encoded.codeUnits));
      expect(decoded.identity, ed.privatePem);
      expect(decoded.wrapping, x.privatePem);
      expect(decoded.legacyRsa, isNull);
    });

    test(
      'the seal -> open -> decode chain the login path runs retains rsa',
      () {
        final ed = crypto.generateEd25519KeyPair();
        final x = crypto.generateWrappingKeyPair();
        final kek = crypto.envelopeDeriveKek(
          exportKey: Uint8List.fromList('migration-export-key'.codeUnits),
        );

        final bundle = Uint8List.fromList(
          encodeKeyBundle(
            identity: ed.privatePem,
            wrapping: x.privatePem,
            legacyRsa: rsa.privateKeyPem,
          ).codeUnits,
        );
        final env = crypto.envelopeSeal(kek: kek, bundle: bundle);
        final decoded = decodeKeyBundle(
          crypto.envelopeOpen(kek: kek, envelope: env),
        );

        expect(decoded.legacyRsa, rsa.privateKeyPem);
        expect(decoded.identity, ed.privatePem);
        expect(decoded.wrapping, x.privatePem);
      },
    );
  });
}
