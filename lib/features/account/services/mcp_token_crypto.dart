import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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
/// (wrong account, wrapping key not ready, corrupted or previous-format
/// ciphertext). Whether a failure means "locked" or "dead blob" is decided by
/// [mcpTokenKeysReady] — see [loadMcpBearerToken].
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

/// Result of [loadMcpBearerToken].
class McpTokenLoad {
  const McpTokenLoad({required this.plaintext, required this.minted});

  /// Plaintext bearer, or null when a stored blob could not be decrypted.
  final String? plaintext;

  /// True when [plaintext] was freshly minted because the DB had no token.
  final bool minted;
}

String _mintMcpBearer() => const Uuid().v4();

/// Whether the unlocked key material needed to decrypt this account's stored
/// MCP token is in memory. Mirrors the dispatch in [decryptMcpToken].
bool mcpTokenKeysReady(WidgetRef ref) {
  final account = ref.read(activeAccountProvider);
  if (account?.wrappingPublicKey != null) {
    return ref.read(decryptedWrappingPrivateKeyProvider) != null;
  }
  return ref.read(decryptedPrivateKeyProvider) != null;
}

/// Loads the MCP bearer from stored ciphertext.
///
/// Mints a new UUID when [storedCiphertext] is null or empty (first time),
/// and also when [decrypt] fails while [keysReady] is true: with the unlocked
/// key in hand a failed decrypt means the blob was wrapped to keys this
/// account no longer has (re-login, re-key), so it is unrecoverable for every
/// client and replacing it beats presenting an empty bearer. While the
/// account is locked ([keysReady] false) a failed decrypt proves nothing —
/// the blob stays untouched and nothing is minted.
McpTokenLoad loadMcpBearerToken({
  required String? storedCiphertext,
  required String? Function(String ciphertext) decrypt,
  required bool keysReady,
  String Function()? mint,
}) {
  final encrypted = storedCiphertext ?? '';
  if (encrypted.isEmpty) {
    return McpTokenLoad(plaintext: (mint ?? _mintMcpBearer)(), minted: true);
  }

  final plaintext = decrypt(encrypted);
  if (plaintext == null && keysReady) {
    return McpTokenLoad(plaintext: (mint ?? _mintMcpBearer)(), minted: true);
  }
  return McpTokenLoad(plaintext: plaintext, minted: false);
}

/// Ciphertext to persist when enabling MCP (tray / first-time).
///
/// If [storedCiphertext] is non-empty, returns it unchanged — never remints.
/// If empty, mints a UUID and encrypts it with [encrypt]. Returns null when
/// encryption cannot proceed.
String? resolveStoredMcpCiphertext({
  required String? storedCiphertext,
  required String? Function(String plaintext) encrypt,
  String Function()? mint,
}) {
  final existing = storedCiphertext ?? '';
  if (existing.isNotEmpty) return existing;
  return encrypt((mint ?? _mintMcpBearer)());
}
