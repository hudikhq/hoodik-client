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

  group('loadMcpBearerToken', () {
    test('mints only when stored ciphertext is empty', () {
      var mintCount = 0;
      final loaded = loadMcpBearerToken(
        storedCiphertext: '',
        decrypt: (_) => 'should-not-run',
        keysReady: true,
        mint: () {
          mintCount++;
          return 'fresh-uuid';
        },
      );
      expect(loaded.plaintext, 'fresh-uuid');
      expect(loaded.minted, isTrue);
      expect(mintCount, 1);
    });

    test('null stored ciphertext is treated as empty and mints', () {
      final loaded = loadMcpBearerToken(
        storedCiphertext: null,
        decrypt: (_) => 'should-not-run',
        keysReady: false,
        mint: () => 'fresh-uuid',
      );
      expect(loaded.plaintext, 'fresh-uuid');
      expect(loaded.minted, isTrue);
    });

    test('does not mint when decrypt fails while the account is locked', () {
      var mintCount = 0;
      final loaded = loadMcpBearerToken(
        storedCiphertext: 'existing-blob',
        decrypt: (_) => null,
        keysReady: false,
        mint: () {
          mintCount++;
          return 'fresh-uuid';
        },
      );
      expect(loaded.plaintext, isNull);
      expect(loaded.minted, isFalse);
      expect(mintCount, 0);
    });

    test('mints when decrypt fails with the keys unlocked — the blob is dead', () {
      var mintCount = 0;
      final loaded = loadMcpBearerToken(
        storedCiphertext: 'blob-wrapped-to-old-keys',
        decrypt: (_) => null,
        keysReady: true,
        mint: () {
          mintCount++;
          return 'fresh-uuid';
        },
      );
      expect(loaded.plaintext, 'fresh-uuid');
      expect(loaded.minted, isTrue);
      expect(mintCount, 1);
    });

    test('returns decrypted token when ciphertext decrypts', () {
      var mintCount = 0;
      final loaded = loadMcpBearerToken(
        storedCiphertext: 'existing-blob',
        decrypt: (c) => c == 'existing-blob' ? 'plain-token' : null,
        keysReady: true,
        mint: () {
          mintCount++;
          return 'fresh-uuid';
        },
      );
      expect(loaded.plaintext, 'plain-token');
      expect(loaded.minted, isFalse);
      expect(mintCount, 0);
    });
  });

  group('resolveStoredMcpCiphertext', () {
    test('keeps existing ciphertext and does not mint', () {
      var encryptCount = 0;
      var mintCount = 0;
      final result = resolveStoredMcpCiphertext(
        storedCiphertext: 'existing-blob',
        encrypt: (p) {
          encryptCount++;
          return 'enc($p)';
        },
        mint: () {
          mintCount++;
          return 'fresh';
        },
      );
      expect(result, 'existing-blob');
      expect(encryptCount, 0);
      expect(mintCount, 0);
    });

    test('mints and encrypts only when DB has no token', () {
      final result = resolveStoredMcpCiphertext(
        storedCiphertext: '',
        encrypt: (p) => 'enc($p)',
        mint: () => 'fresh',
      );
      expect(result, 'enc(fresh)');
    });

    test('null stored ciphertext mints and encrypts', () {
      final result = resolveStoredMcpCiphertext(
        storedCiphertext: null,
        encrypt: (p) => 'enc($p)',
        mint: () => 'fresh',
      );
      expect(result, 'enc(fresh)');
    });

    test('returns null when first-time encrypt cannot proceed', () {
      final result = resolveStoredMcpCiphertext(
        storedCiphertext: null,
        encrypt: (_) => null,
        mint: () => 'fresh',
      );
      expect(result, isNull);
    });
  });
}
