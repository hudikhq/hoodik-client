import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/providers.dart';
import '../../../core/storage/database.dart';

/// Encrypts the MCP bearer token to the active account's own key so it never
/// sits in the local database as plaintext.
///
/// Curve accounts hold an Ed25519 identity key that can't do RSA, so the
/// dispatch keys off [Account.wrappingPublicKey]: present means curve (hybrid
/// wrapping), absent means legacy RSA. The token is a String, carried as its
/// UTF-8 bytes.
///
/// Returns null when the required key material is missing rather than throwing,
/// matching the call sites that skip persistence when encryption can't proceed.
String? encryptMcpToken(WidgetRef ref, String plaintext) => encryptMcpTokenWith(
  ref.read(activeAccountProvider),
  ref.read(cryptoServiceProvider),
  plaintext,
);

/// Decrypts a token produced by [encryptMcpToken]. Returns null on any failure
/// (wrong account, corrupted or previous-format ciphertext) so the caller can
/// fall back to minting a fresh token.
String? decryptMcpToken(WidgetRef ref, String ciphertext) =>
    decryptMcpTokenWith(
      account: ref.read(activeAccountProvider),
      crypto: ref.read(cryptoServiceProvider),
      identityPrivateKey: ref.read(decryptedPrivateKeyProvider),
      wrappingPrivateKey: ref.read(decryptedWrappingPrivateKeyProvider),
      ciphertext: ciphertext,
    );

/// Value-based core of [encryptMcpToken], shared with call sites that hold a
/// plain [Ref] rather than a [WidgetRef].
String? encryptMcpTokenWith(
  Account? account,
  CryptoService crypto,
  String plaintext,
) {
  final wrappingPublicKey = account?.wrappingPublicKey;
  if (wrappingPublicKey != null) {
    return crypto.wrappingWrap(
      fileKey: Uint8List.fromList(utf8.encode(plaintext)),
      recipientPublicPem: wrappingPublicKey,
    );
  }

  final publicKey = account?.publicKey;
  if (publicKey == null) return null;
  return crypto.rsaEncrypt(plaintext: plaintext, publicKeyPem: publicKey);
}

/// Value-based core of [decryptMcpToken].
String? decryptMcpTokenWith({
  required Account? account,
  required CryptoService crypto,
  required String? identityPrivateKey,
  required String? wrappingPrivateKey,
  required String ciphertext,
}) {
  try {
    if (account?.wrappingPublicKey != null) {
      if (wrappingPrivateKey == null) return null;
      final bytes = crypto.wrappingUnwrap(
        blob: ciphertext,
        privatePem: wrappingPrivateKey,
      );
      return utf8.decode(bytes);
    }

    if (identityPrivateKey == null) return null;
    return crypto.rsaDecrypt(
      ciphertextBase64: ciphertext,
      privateKeyPem: identityPrivateKey,
    );
  } catch (_) {
    return null;
  }
}
