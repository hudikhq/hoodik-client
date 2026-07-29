import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/account/services/mcp_token_crypto.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();

  Account account({String? publicKey, String? wrappingPublicKey}) => Account(
    id: 'srv_user@example.com',
    serverId: 'srv',
    userId: 'user-uuid',
    email: 'user@example.com',
    publicKey: publicKey,
    wrappingPublicKey: wrappingPublicKey,
    isActive: true,
    createdAt: DateTime(2026),
  );

  group('curve account (hybrid wrapping)', () {
    test('encrypt -> decrypt roundtrips the token', () {
      final kp = crypto.generateWrappingKeyPair();
      final acc = account(wrappingPublicKey: kp.publicPem);
      const token = 'a-secret-bearer-token-1234';

      final ciphertext = encryptMcpTokenWith(acc, crypto, token);
      expect(ciphertext, isNotNull);

      final plaintext = decryptMcpTokenWith(
        account: acc,
        crypto: crypto,
        identityPrivateKey: null,
        wrappingPrivateKey: kp.privatePem,
        ciphertext: ciphertext!,
      );
      expect(plaintext, token);
    });

    test('decrypt with the wrong wrapping key fails to null', () {
      final kp = crypto.generateWrappingKeyPair();
      final other = crypto.generateWrappingKeyPair();
      final acc = account(wrappingPublicKey: kp.publicPem);

      final ciphertext = encryptMcpTokenWith(acc, crypto, 'token')!;
      final plaintext = decryptMcpTokenWith(
        account: acc,
        crypto: crypto,
        identityPrivateKey: null,
        wrappingPrivateKey: other.privatePem,
        ciphertext: ciphertext,
      );
      expect(plaintext, isNull);
    });
  });

  group('legacy RSA account', () {
    // RSA keygen is expensive; generate one pair for the whole group.
    late final rsa = rust.generateRsaKeypair();

    test('encrypt -> decrypt roundtrips the token', () {
      final acc = account(publicKey: rsa.publicKeyPem);
      const token = 'legacy-rsa-bearer-token';

      final ciphertext = encryptMcpTokenWith(acc, crypto, token);
      expect(ciphertext, isNotNull);

      final plaintext = decryptMcpTokenWith(
        account: acc,
        crypto: crypto,
        identityPrivateKey: rsa.privateKeyPem,
        wrappingPrivateKey: null,
        ciphertext: ciphertext!,
      );
      expect(plaintext, token);
    });

    test('decrypt with the wrong private key fails to null', () {
      final acc = account(publicKey: rsa.publicKeyPem);
      final other = rust.generateRsaKeypair();

      final ciphertext = encryptMcpTokenWith(acc, crypto, 'token')!;
      final plaintext = decryptMcpTokenWith(
        account: acc,
        crypto: crypto,
        identityPrivateKey: other.privateKeyPem,
        wrappingPrivateKey: null,
        ciphertext: ciphertext,
      );
      expect(plaintext, isNull);
    });
  });

  test('missing key material returns null instead of throwing', () {
    final acc = account();
    expect(encryptMcpTokenWith(acc, crypto, 'token'), isNull);
  });
}
