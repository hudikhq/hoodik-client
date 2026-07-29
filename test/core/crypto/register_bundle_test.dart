import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/crypto_service_migration.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

/// The register ceremony seals `v1|ed:<edPriv>|x:<xPriv>` (no rsa segment) and
/// the login path opens the same envelope and parses those two segments back.
/// These guard that contract end to end with the real Rust crypto.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();

  test('fresh-signup bundle seals and re-opens into the ed/x keys', () {
    final ed = crypto.generateEd25519KeyPair();
    final x = crypto.generateWrappingKeyPair();

    final bundle = Uint8List.fromList(
      'v1|ed:${ed.privatePem}|x:${x.privatePem}'.codeUnits,
    );
    final exportKey = base64Decode(base64Encode(utf8.encode('opaque-export')));
    final kek = crypto.envelopeDeriveKek(exportKey: exportKey);
    final env = crypto.envelopeSeal(kek: kek, bundle: bundle);

    final opened = crypto.envelopeOpen(kek: kek, envelope: env);
    final s = String.fromCharCodes(opened);
    String? edPriv;
    String? xPriv;
    for (final part in s.split('|')) {
      if (part.startsWith('ed:')) edPriv = part.substring(3);
      if (part.startsWith('x:')) xPriv = part.substring(2);
    }

    expect(edPriv, ed.privatePem);
    expect(xPriv, x.privatePem);
    // The signup bundle carries no legacy RSA key.
    expect(s.contains('rsa:'), isFalse);
    expect(s.startsWith('v1|'), isTrue);
  });

  test('the ceremony ed25519 self-check probe verifies', () {
    final ed = crypto.generateEd25519KeyPair();
    const probe = 'register-probe-new@test.io';
    final sig = crypto.ed25519Sign(message: probe, privatePem: ed.privatePem);
    expect(
      crypto.ed25519Verify(
        message: probe,
        signature: sig,
        publicPem: ed.publicPem,
      ),
      isTrue,
    );
  });

  test('OPAQUE password is UTF-8 encoded, not code units', () {
    // A multi-byte password must reach OPAQUE as UTF-8 bytes so registration
    // and later login agree; codeUnits would diverge for non-ASCII input.
    const password = 'páßwörd🔒';
    final utf8Bytes = Uint8List.fromList(utf8.encode(password));
    expect(utf8Bytes, isNot(equals(Uint8List.fromList(password.codeUnits))));

    // The real OPAQUE start accepts the UTF-8 bytes without throwing.
    final start = crypto.opaqueClientRegistrationStart(password: utf8Bytes);
    expect(start.message, isNotEmpty);
    expect(start.state, isNotEmpty);
  });
}
