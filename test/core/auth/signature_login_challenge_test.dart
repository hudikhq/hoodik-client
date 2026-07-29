import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

/// The signature-login challenge the app signs for `POST /api/auth/signature`.
/// The server reconstructs `{fingerprint}:{timestamp}:{nonce}` from the wire
/// fields and refuses a reused `(fingerprint, nonce)` pair, so freshness of
/// the nonce is what lets two same-minute unlocks both succeed — the property
/// the old deterministic minute-bucket nonce lacked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();
  const fingerprint = 'ab12cd34';

  test('two challenges in the same instant carry distinct nonces', () {
    final first = crypto.createSignatureLoginChallenge(fingerprint);
    final second = crypto.createSignatureLoginChallenge(fingerprint);
    expect(first.nonce, isNot(equals(second.nonce)));
  });

  test('the canonical is {fingerprint}:{timestamp}:{nonce}', () {
    final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final challenge = crypto.createSignatureLoginChallenge(fingerprint);
    final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    expect(challenge.nonce, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(challenge.timestamp, inInclusiveRange(before, after));
    expect(
      challenge.message,
      '$fingerprint:${challenge.timestamp}:${challenge.nonce}',
    );
  });

  test('the challenge signs and verifies under both key types', () {
    final challenge = crypto.createSignatureLoginChallenge(fingerprint);

    final ed = crypto.generateEd25519KeyPair();
    final edSig = crypto.ed25519Sign(
      message: challenge.message,
      privatePem: ed.privatePem,
    );
    expect(
      crypto.ed25519Verify(
        message: challenge.message,
        signature: edSig,
        publicPem: ed.publicPem,
      ),
      isTrue,
    );
  });
}
