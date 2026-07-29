import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/pem_key_type.dart';

void main() {
  group('pemIsCurve', () {
    // The regression this guards: a hybrid wrapping key's random base64 body
    // contains the substring "RSA" ~5% of the time. Deciding by the whole PEM
    // (the old `!pem.toUpperCase().contains('RSA')`) misclassifies it as RSA.
    const wrappingKeyWithRsaInBody =
        '-----BEGIN HOODIK WRAPPING KEY-----\n'
        'AQIDrsaBCDwtRSAqLzAK\n'
        '-----END HOODIK WRAPPING KEY-----';

    test('wrapping key with "RSA" in its body is still curve', () {
      expect(pemIsCurve(wrappingKeyWithRsaInBody), isTrue);

      // The old body-scan logic gets this exact case wrong.
      final oldBodyScan = !wrappingKeyWithRsaInBody.toUpperCase().contains(
        'RSA',
      );
      expect(oldBodyScan, isFalse);
    });

    test('Ed25519 identity labels are curve', () {
      expect(
        pemIsCurve(
          '-----BEGIN PRIVATE KEY-----\nMC4CAQAw\n'
          '-----END PRIVATE KEY-----',
        ),
        isTrue,
      );
      expect(
        pemIsCurve(
          '-----BEGIN PUBLIC KEY-----\nMCowBQYD\n'
          '-----END PUBLIC KEY-----',
        ),
        isTrue,
      );
    });

    test('wrapping labels are curve', () {
      expect(
        pemIsCurve(
          '-----BEGIN HOODIK WRAPPING PRIVATE KEY-----\nAQID\n'
          '-----END HOODIK WRAPPING PRIVATE KEY-----',
        ),
        isTrue,
      );
      expect(
        pemIsCurve(
          '-----BEGIN HOODIK WRAPPING KEY-----\nAQID\n'
          '-----END HOODIK WRAPPING KEY-----',
        ),
        isTrue,
      );
    });

    test('RSA labels are not curve', () {
      expect(
        pemIsCurve(
          '-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIB\n'
          '-----END RSA PRIVATE KEY-----',
        ),
        isFalse,
      );
      expect(
        pemIsCurve(
          '-----BEGIN RSA PUBLIC KEY-----\nMIIBCgKC\n'
          '-----END RSA PUBLIC KEY-----',
        ),
        isFalse,
      );
    });

    test('empty string is not curve', () {
      expect(pemIsCurve(''), isFalse);
    });
  });
}
