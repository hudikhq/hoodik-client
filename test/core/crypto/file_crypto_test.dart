import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();

  group('link key wrap (curve25519 account)', () {
    test('encrypt/decrypt roundtrips the owner copy via the hybrid wrap', () {
      final identity = crypto.generateEd25519KeyPair();
      final wrapping = crypto.generateWrappingKeyPair();

      final fileCrypto = FileCrypto(
        privateKeyPem: identity.privatePem,
        wrappingPrivateKeyPem: wrapping.privatePem,
      );

      final linkKey = fileCrypto.generateLinkKey();
      final encrypted = fileCrypto.encryptLinkKey(
        linkKey: linkKey,
        publicKeyPem: wrapping.publicPem,
      );

      expect(fileCrypto.decryptLinkKey(encrypted), equals(linkKey));
    });

    test('decrypt with a mismatched wrapping key throws', () {
      final identity = crypto.generateEd25519KeyPair();
      final wrapping = crypto.generateWrappingKeyPair();
      final other = crypto.generateWrappingKeyPair();

      final owner = FileCrypto(
        privateKeyPem: identity.privatePem,
        wrappingPrivateKeyPem: wrapping.privatePem,
      );
      final encrypted = owner.encryptLinkKey(
        linkKey: owner.generateLinkKey(),
        publicKeyPem: wrapping.publicPem,
      );

      final wrong = FileCrypto(
        privateKeyPem: identity.privatePem,
        wrappingPrivateKeyPem: other.privatePem,
      );
      expect(() => wrong.decryptLinkKey(encrypted), throwsA(anything));
    });
  });

  group('chunk crypto (per-chunk nonces)', () {
    final fileCrypto = FileCrypto();

    test('identical plaintext encrypts to distinct ciphertext per index', () {
      final key = fileCrypto.generateFileKey();
      final plaintext = Uint8List.fromList(List.filled(64, 0x41));

      final chunk1 = fileCrypto.encryptChunk(
        data: plaintext,
        fileKey: key,
        cipher: 'aegis128l',
        chunkIndex: 1,
      );
      final chunk2 = fileCrypto.encryptChunk(
        data: plaintext,
        fileKey: key,
        cipher: 'aegis128l',
        chunkIndex: 2,
      );
      expect(chunk1, isNot(equals(chunk2)));

      for (final (index, chunk) in [(1, chunk1), (2, chunk2)]) {
        expect(
          fileCrypto.decryptChunk(
            data: chunk,
            fileKey: key,
            cipher: 'aegis128l',
            chunkIndex: index,
          ),
          equals(plaintext),
        );
      }
    });

    test('chunk 0 is byte-identical to the whole-payload encryption', () {
      final key = fileCrypto.generateFileKey();
      final plaintext = Uint8List.fromList(List.filled(64, 0x42));

      expect(
        fileCrypto.encryptChunk(
          data: plaintext,
          fileKey: key,
          cipher: 'aegis128l',
          chunkIndex: 0,
        ),
        equals(
          crypto.symmetricEncrypt(
            cipher: 'aegis128l',
            key: key,
            plaintext: plaintext,
          ),
        ),
      );
    });

    test('a legacy fixed-nonce chunk still decrypts via the fallback', () {
      final key = fileCrypto.generateFileKey();
      final plaintext = Uint8List.fromList(List.filled(64, 0x43));

      // Files uploaded before per-chunk nonces encrypted every chunk with the
      // key blob as-is; a non-zero index must still recover them.
      final legacy = crypto.symmetricEncrypt(
        cipher: 'aegis128l',
        key: key,
        plaintext: plaintext,
      );
      expect(
        fileCrypto.decryptChunk(
          data: legacy,
          fileKey: key,
          cipher: 'aegis128l',
          chunkIndex: 3,
        ),
        equals(plaintext),
      );
    });

    test('a chunk fed to the wrong index fails authentication', () {
      final key = fileCrypto.generateFileKey();
      final chunk = fileCrypto.encryptChunk(
        data: Uint8List.fromList(List.filled(64, 0x44)),
        fileKey: key,
        cipher: 'aegis128l',
        chunkIndex: 2,
      );
      expect(
        () => fileCrypto.decryptChunk(
          data: chunk,
          fileKey: key,
          cipher: 'aegis128l',
          chunkIndex: 5,
        ),
        throwsA(anything),
      );
    });
  });

  group('metadata string crypto (per-string random nonces)', () {
    final fileCrypto = FileCrypto();

    test('encrypting the same name twice yields distinct ciphertext', () {
      final key = fileCrypto.generateFileKey();

      final first = fileCrypto.encryptFileName(
        name: 'report あいうえお.pdf',
        fileKey: key,
        cipher: 'aegis128l',
      );
      final second = fileCrypto.encryptFileName(
        name: 'report あいうえお.pdf',
        fileKey: key,
        cipher: 'aegis128l',
      );
      expect(first, isNot(equals(second)));

      for (final encrypted in [first, second]) {
        expect(
          fileCrypto.decryptFileName(
            encryptedNameHex: encrypted,
            fileKey: key,
            cipher: 'aegis128l',
          ),
          'report あいうえお.pdf',
        );
      }
    });

    test('a legacy embedded-nonce name still decrypts via the fallback', () {
      final key = fileCrypto.generateFileKey();

      // Metadata written before per-string nonces encrypted with the key
      // blob as-is.
      final legacy = crypto.symmetricEncrypt(
        cipher: 'aegis128l',
        key: key,
        plaintext: Uint8List.fromList('old name.txt'.codeUnits),
      );
      expect(
        fileCrypto.decryptFileName(
          encryptedNameHex: crypto.hexEncode(legacy),
          fileKey: key,
          cipher: 'aegis128l',
        ),
        'old name.txt',
      );
    });

    test('link metadata roundtrips through the link key', () {
      final linkKey = fileCrypto.generateLinkKey();
      final fileKey = fileCrypto.generateFileKey();

      final encryptedName = fileCrypto.encryptWithLinkKey(
        text: 'shared.jpg',
        linkKey: linkKey,
      );
      expect(
        fileCrypto.decryptWithLinkKey(
          encryptedHex: encryptedName,
          linkKey: linkKey,
        ),
        'shared.jpg',
      );

      final encryptedFileKey = fileCrypto.encryptFileKeyWithLinkKey(
        fileKey: fileKey,
        linkKey: linkKey,
      );
      expect(
        fileCrypto.decryptFileKeyWithLinkKey(
          encryptedFileKey: encryptedFileKey,
          linkKey: linkKey,
        ),
        equals(fileKey),
      );
    });

    // Cross-client anchor: the same vector is asserted in
    // `cryptfns/src/cipher.rs` (string_golden_vector_decrypts) and the web
    // frontend's `web/tests/crypto-cipher.test.ts`. If any client's
    // nonce-prepend format drifts, one of the three fails.
    test('cross-client golden vector decrypts', () {
      final key = crypto.hexDecode(
        '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f',
      );
      const blobHex =
          'a0a1a2a3a4a5a6a7a8a9aaabacadaeaf'
          'bbe8a3087cc12efc536324b18fb194d014ab82478e8e43951d2d';

      expect(
        fileCrypto.decryptFileName(
          encryptedNameHex: blobHex,
          fileKey: key,
          cipher: 'ascon128a',
        ),
        'hoodik.txt',
      );
    });
  });
}
