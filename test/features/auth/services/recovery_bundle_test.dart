import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/features/auth/services/recovery_bundle.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

const _fakeRsaPem =
    '-----BEGIN RSA PRIVATE KEY-----\nAAAA\n-----END RSA PRIVATE KEY-----';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();

  group('recoveryKeyOf', () {
    test('returns null without an identity key', () {
      expect(recoveryKeyOf(identity: null), isNull);
      expect(recoveryKeyOf(identity: ''), isNull);
    });

    test('legacy RSA account exports its bare PEM', () {
      expect(recoveryKeyOf(identity: _fakeRsaPem), _fakeRsaPem);
    });

    test('curve account exports the full bundle', () {
      expect(
        recoveryKeyOf(identity: 'ID', wrapping: 'WRAP', legacyRsa: 'RSA'),
        'v1|rsa:RSA|ed:ID|x:WRAP',
      );
      expect(
        recoveryKeyOf(identity: 'ID', wrapping: 'WRAP'),
        'v1|ed:ID|x:WRAP',
      );
    });
  });

  group('parseRecoveryKey', () {
    test('round-trips the exported curve bundle', () {
      final exported = recoveryKeyOf(
        identity: 'ID',
        wrapping: 'WRAP',
        legacyRsa: 'RSA',
      );
      final parsed = parseRecoveryKey(exported!);
      expect(parsed.identity, 'ID');
      expect(parsed.wrapping, 'WRAP');
      expect(parsed.legacyRsa, 'RSA');
      expect(parsed.isCurve, isTrue);
    });

    test('round-trips a bundle without a retained RSA key', () {
      final parsed = parseRecoveryKey('v1|ed:ID|x:WRAP');
      expect(parsed.identity, 'ID');
      expect(parsed.wrapping, 'WRAP');
      expect(parsed.legacyRsa, isNull);
    });

    test('accepts a bare RSA PEM with surrounding whitespace', () {
      final parsed = parseRecoveryKey('  $_fakeRsaPem\n');
      expect(parsed.identity, _fakeRsaPem);
      expect(parsed.isCurve, isFalse);
    });

    test('rejects empty and unrecognizable input', () {
      expect(() => parseRecoveryKey('   '), throwsFormatException);
      expect(() => parseRecoveryKey('not a key'), throwsFormatException);
    });

    test('rejects a bundle missing its wrapping key', () {
      expect(
        // Both tags present so it parses as a bundle, but `x:` is empty.
        () => parseRecoveryKey('v1|ed:ID|x:'),
        throwsFormatException,
      );
    });
  });

  group('ed25519PublicPemFromPrivate', () {
    test('recovers the exact public key of a generated keypair', () {
      final kp = crypto.generateEd25519KeyPair();
      final extracted = ed25519PublicPemFromPrivate(kp.privatePem);
      expect(extracted, isNotNull);
      expect(extracted!.trim(), kp.publicPem.trim());
      expect(
        crypto.spkiFingerprint(publicPem: extracted),
        crypto.spkiFingerprint(publicPem: kp.publicPem),
      );
    });

    test('extracted key verifies a signature from the private key', () {
      final kp = crypto.generateEd25519KeyPair();
      final publicPem = ed25519PublicPemFromPrivate(kp.privatePem)!;
      final signature = crypto.ed25519Sign(
        message: 'probe',
        privatePem: kp.privatePem,
      );
      expect(
        crypto.ed25519Verify(
          message: 'probe',
          signature: signature,
          publicPem: publicPem,
        ),
        isTrue,
      );
    });

    test('returns null for PEMs without an embedded public key', () {
      expect(ed25519PublicPemFromPrivate(_fakeRsaPem), isNull);
      expect(ed25519PublicPemFromPrivate('garbage'), isNull);
    });
  });
}
