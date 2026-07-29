import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();

  group('wrapping', () {
    test('wrap/unwrap roundtrips a file key', () {
      final kp = crypto.generateWrappingKeyPair();
      expect(kp.privatePem, contains('BEGIN HOODIK WRAPPING PRIVATE KEY'));
      expect(kp.publicPem, contains('BEGIN HOODIK WRAPPING KEY'));

      final fileKey = crypto.generateSymmetricKey();
      final blob = crypto.wrappingWrap(
        fileKey: fileKey,
        recipientPublicPem: kp.publicPem,
      );
      final unwrapped = crypto.wrappingUnwrap(
        blob: blob,
        privatePem: kp.privatePem,
      );
      expect(unwrapped, equals(fileKey));
    });

    test('unwrap with the wrong key throws', () {
      final kp = crypto.generateWrappingKeyPair();
      final other = crypto.generateWrappingKeyPair();
      final blob = crypto.wrappingWrap(
        fileKey: crypto.generateSymmetricKey(),
        recipientPublicPem: kp.publicPem,
      );
      expect(
        () => crypto.wrappingUnwrap(blob: blob, privatePem: other.privatePem),
        throwsA(anything),
      );
    });
  });

  group('ed25519', () {
    test('sign/verify roundtrips and rejects a tampered message', () {
      final kp = crypto.generateEd25519KeyPair();
      final sig = crypto.ed25519Sign(
        message: 'hello world',
        privatePem: kp.privatePem,
      );
      expect(
        crypto.ed25519Verify(
          message: 'hello world',
          signature: sig,
          publicPem: kp.publicPem,
        ),
        isTrue,
      );
      expect(
        crypto.ed25519Verify(
          message: 'hello world!',
          signature: sig,
          publicPem: kp.publicPem,
        ),
        isFalse,
      );
    });

    test('sign/verify bytes roundtrips and rejects tampered bytes', () {
      final kp = crypto.generateEd25519KeyPair();
      final message = Uint8List.fromList([0, 159, 146, 150]);
      final sig = crypto.ed25519SignBytes(
        message: message,
        privatePem: kp.privatePem,
      );
      expect(
        crypto.ed25519VerifyBytes(
          message: message,
          signature: sig,
          publicPem: kp.publicPem,
        ),
        isTrue,
      );
      final tampered = Uint8List.fromList([1, 159, 146, 150]);
      expect(
        crypto.ed25519VerifyBytes(
          message: tampered,
          signature: sig,
          publicPem: kp.publicPem,
        ),
        isFalse,
      );
    });
  });

  group('spkiFingerprint', () {
    test('is deterministic 64-char hex', () {
      final kp = crypto.generateEd25519KeyPair();
      final fingerprint = crypto.spkiFingerprint(publicPem: kp.publicPem);
      expect(fingerprint, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(crypto.spkiFingerprint(publicPem: kp.publicPem), fingerprint);
    });
  });
}
