import 'dart:convert';
import 'dart:typed_data';

import '../utils/hex.dart' as hex_utils;
import 'crypto_service.dart';
import 'pem_key_type.dart';

/// Decrypts file metadata (names, thumbnails) using the user's private key
/// and each file's per-file symmetric key.
///
/// Typical usage:
/// ```dart
/// final fileCrypto = FileCrypto(
///   privateKeyPem: decryptedPrivateKey,
///   crypto: CryptoService(),
/// );
///
/// for (final file in files) {
///   final fileKey = fileCrypto.decryptFileKey(file.encryptedKey!);
///   final name = fileCrypto.decryptFileName(
///     encryptedNameHex: file.encryptedName,
///     fileKey: fileKey,
///     cipher: file.cipher,
///   );
/// }
/// ```
class FileCrypto {
  final String privateKeyPem;

  /// Hybrid wrapping private key (for curve accounts) to (un)wrap the caller's own file keys.
  /// When present and the identity key is curve, key wrap/unwrap uses the hybrid
  /// construction (raw bytes) instead of the legacy RSA+hex path.
  final String? wrappingPrivateKeyPem;

  final CryptoService _crypto;

  FileCrypto({
    this.privateKeyPem = '',
    this.wrappingPrivateKeyPem,
    CryptoService? crypto,
  }) : _crypto = crypto ?? const CryptoService();

  /// Decrypt a file's per-file symmetric key from its `encrypted_key` field.
  ///
  /// The `encrypted_key` is a **base64-encoded** RSA-PKCS1v15 ciphertext.
  /// After RSA decryption the plaintext is a **hex string** representing the
  /// actual symmetric key bytes.
  ///
  /// Returns the raw key bytes.
  Uint8List decryptFileKey(String encryptedKeyBase64) {
    final isCurve = wrappingPrivateKeyPem != null && pemIsCurve(privateKeyPem);

    if (isCurve) {
      // The hybrid unwrap returns the raw file key bytes directly.
      return _crypto.wrappingUnwrap(
        blob: encryptedKeyBase64,
        privatePem: wrappingPrivateKeyPem!,
      );
    }

    // Legacy RSA path: RSA decrypt → hex string → bytes
    final hexKey = _crypto.rsaDecrypt(
      ciphertextBase64: encryptedKeyBase64,
      privateKeyPem: privateKeyPem,
    );
    return _hexDecode(hexKey);
  }

  /// Decrypt a file's name from its `encrypted_name` field.
  ///
  /// - `encryptedNameHex` — hex-encoded ciphertext
  /// - `fileKey` — the raw symmetric key bytes (from [decryptFileKey])
  /// - `cipher` — the cipher identifier ("aegis128l", "ascon128a",
  ///   "chacha20poly1305", "aegis256")
  ///
  /// Returns the plaintext file name as a UTF-8 string.
  String decryptFileName({
    required String encryptedNameHex,
    required Uint8List fileKey,
    required String cipher,
  }) {
    final ciphertext = _hexDecode(encryptedNameHex);

    final plaintext = _crypto.symmetricDecryptString(
      cipher: cipher,
      key: fileKey,
      ciphertext: ciphertext,
    );

    return utf8.decode(plaintext);
  }

  /// Decrypt a file's thumbnail from its `encrypted_thumbnail` field.
  ///
  /// Same structure as file names: hex-encoded ciphertext decrypted with the
  /// file's symmetric key.  Returns the plaintext as a UTF-8 string (typically
  /// a base64-encoded image).
  String? decryptThumbnail({
    required String? encryptedThumbnailHex,
    required Uint8List fileKey,
    required String cipher,
  }) {
    if (encryptedThumbnailHex == null || encryptedThumbnailHex.isEmpty) {
      return null;
    }

    final ciphertext = _hexDecode(encryptedThumbnailHex);

    final plaintext = _crypto.symmetricDecryptString(
      cipher: cipher,
      key: fileKey,
      ciphertext: ciphertext,
    );

    return utf8.decode(plaintext);
  }

  /// Generate a new random symmetric key for a file or directory.
  Uint8List generateFileKey({String cipher = 'aegis128l'}) {
    return _crypto.generateSymmetricKey(cipher: cipher);
  }

  /// Encrypt a symmetric key with the user's public key.
  ///
  /// The key bytes are hex-encoded, then RSA-encrypted with the public key.
  /// Returns a base64-encoded ciphertext string (matching the server's
  /// `encrypted_key` field format).
  String encryptFileKey({
    required Uint8List fileKey,
    required String publicKeyPem,
  }) {
    final isCurve = wrappingPrivateKeyPem != null && pemIsCurve(privateKeyPem);

    if (isCurve) {
      // Curve: hybrid wrap of the raw key bytes (no hex inside).
      return _crypto.wrappingWrap(
        fileKey: fileKey,
        recipientPublicPem: publicKeyPem,
      );
    }

    final hexKey = _hexEncode(fileKey);
    return _crypto.rsaEncrypt(plaintext: hexKey, publicKeyPem: publicKeyPem);
  }

  /// Encrypt a thumbnail data URL with a symmetric key.
  ///
  /// The thumbnail is a base64 data URL like `data:image/jpeg;base64,...`.
  /// Returns the ciphertext as a hex string (matching the server's
  /// `encrypted_thumbnail` field format).
  String encryptThumbnail({
    required String thumbnailDataUrl,
    required Uint8List fileKey,
    required String cipher,
  }) {
    final plaintext = Uint8List.fromList(utf8.encode(thumbnailDataUrl));
    final ciphertext = _crypto.symmetricEncryptString(
      cipher: cipher,
      key: fileKey,
      plaintext: plaintext,
    );
    return _hexEncode(ciphertext);
  }

  /// Encrypt a file/directory name with a symmetric key.
  ///
  /// Returns the ciphertext as a hex string (matching the server's
  /// `encrypted_name` field format).
  String encryptFileName({
    required String name,
    required Uint8List fileKey,
    required String cipher,
  }) {
    final plaintext = Uint8List.fromList(utf8.encode(name));
    final ciphertext = _crypto.symmetricEncryptString(
      cipher: cipher,
      key: fileKey,
      plaintext: plaintext,
    );
    return _hexEncode(ciphertext);
  }

  /// The account-wide search key, derived once per instance from whichever
  /// private key this account has. Cached because every upload, rename and
  /// query needs it.
  String? _rootKey;

  String get searchRootKey => _rootKey ??= _crypto.searchRootKey(
    (wrappingPrivateKeyPem?.isNotEmpty ?? false)
        ? wrappingPrivateKeyPem!
        : privateKeyPem,
  );

  /// Keyed `name_hash` for a file or directory name.
  ///
  /// Was a bare SHA-256 of the plaintext name, which a dictionary of common
  /// file names reverses without needing a rainbow table at all.
  String hashFileName(String name) => _crypto.searchTag(searchRootKey, name);

  /// One keyed tag of a whole value under [key] — the exact-match unit: the
  /// keyed digest columns, the digest tags in the index, and the query-side
  /// tag that answers a pasted digest without it ever crossing the wire.
  String exactTag(String key, String value) => _crypto.searchTag(key, value);

  /// Tags for text under the account key: everything this user owns.
  List<String> tokenizeForSearch(String name) =>
      _crypto.searchTags(searchRootKey, name);

  /// Tags for text under a file's own key. This is the scope every recipient
  /// of a share searches through, so it is written for every file even when
  /// the file is not shared — that is what makes sharing free of index work.
  List<String> tokenizeForSearchWithFileKey(Uint8List fileKey, String name) =>
      _crypto.searchTags(_crypto.searchFileKey(fileKey), name);

  /// A file's search key as hex, for callers that hold raw key bytes.
  String searchFileKeyHex(Uint8List fileKey) => _crypto.searchFileKey(fileKey);

  /// Bare tags for a query, as the search route receives them.
  List<String> queryTags(String key, String text) =>
      _crypto.searchQueryTags(key, text);

  /// Encrypt a data chunk with the file's symmetric key. [chunkIndex] derives
  /// a per-chunk nonce — encrypting every chunk with the key blob as-is would
  /// reuse the embedded nonce across the file and void the AEAD guarantees.
  /// Chunk 0 stays byte-identical to the whole-payload encryption.
  Uint8List encryptChunk({
    required Uint8List data,
    required Uint8List fileKey,
    required String cipher,
    required int chunkIndex,
  }) {
    return _crypto.symmetricEncryptChunk(
      cipher: cipher,
      key: fileKey,
      chunkIndex: chunkIndex,
      plaintext: data,
    );
  }

  /// Decrypt a data chunk with the file's symmetric key. Tries the per-chunk
  /// nonce for [chunkIndex] first, then the key blob's own nonce so files
  /// uploaded before per-chunk nonces existed still decrypt.
  Uint8List decryptChunk({
    required Uint8List data,
    required Uint8List fileKey,
    required String cipher,
    required int chunkIndex,
  }) {
    return _crypto.symmetricDecryptChunk(
      cipher: cipher,
      key: fileKey,
      chunkIndex: chunkIndex,
      ciphertext: data,
    );
  }

  /// Compute CRC-16 checksum of data bytes. Returns hex string.
  String crc16(List<int> data) {
    return _crypto.crc16(data: data);
  }

  /// Compute SHA-256 hash of data bytes. Returns hex string.
  String sha256(List<int> data) {
    return _crypto.sha256(data: data);
  }

  /// Hex-encode a symmetric key, e.g. a link key.
  String hexEncodeKey(Uint8List key) {
    return _hexEncode(key);
  }

  /// Generate a random link key (Ascon-128a: 16-byte key + 16-byte nonce).
  Uint8List generateLinkKey() {
    return _crypto.generateSymmetricKey(cipher: 'ascon128a');
  }

  /// Sign a file ID with the user's private key (RSA or Ed25519).
  String signFileId(String fileId) {
    if (pemIsCurve(privateKeyPem)) {
      return _crypto.ed25519Sign(message: fileId, privatePem: privateKeyPem);
    }
    return _crypto.rsaSign(message: fileId, privateKeyPem: privateKeyPem);
  }

  /// Encrypt the link key with the owner's public key so they can later
  /// recover it without the URL fragment. Curve accounts wrap the raw bytes
  /// with the hybrid construction; RSA accounts hex-encode then RSA-encrypt.
  String encryptLinkKey({
    required Uint8List linkKey,
    required String publicKeyPem,
  }) {
    final isCurve = wrappingPrivateKeyPem != null && pemIsCurve(privateKeyPem);

    if (isCurve) {
      return _crypto.wrappingWrap(
        fileKey: linkKey,
        recipientPublicPem: publicKeyPem,
      );
    }

    final hexKey = _hexEncode(linkKey);
    return _crypto.rsaEncrypt(plaintext: hexKey, publicKeyPem: publicKeyPem);
  }

  /// Decrypt the owner's copy of the link key.
  ///
  /// Returns the raw link key bytes.
  Uint8List decryptLinkKey(String encryptedLinkKeyBase64) {
    final isCurve = wrappingPrivateKeyPem != null && pemIsCurve(privateKeyPem);

    if (isCurve) {
      return _crypto.wrappingUnwrap(
        blob: encryptedLinkKeyBase64,
        privatePem: wrappingPrivateKeyPem!,
      );
    }

    final hexKey = _crypto.rsaDecrypt(
      ciphertextBase64: encryptedLinkKeyBase64,
      privateKeyPem: privateKeyPem,
    );
    return _hexDecode(hexKey);
  }

  /// Decrypt the real file content key from the form stored in public link metadata.
  ///
  /// Public link recipients receive the raw link key in the URL fragment. The
  /// metadata contains `encrypted_file_key` which is the real file key (hex)
  /// encrypted with the link key (ascon128a, double-hex like names).
  ///
  /// This is the client-side only path (server never decrypts content).
  Uint8List decryptFileKeyWithLinkKey({
    required String encryptedFileKey,
    required Uint8List linkKey,
  }) {
    final hex = decryptWithLinkKey(
      encryptedHex: encryptedFileKey,
      linkKey: linkKey,
    );
    return _hexDecode(hex);
  }

  /// Encrypt a file's symmetric key with the link key.
  ///
  /// The file key bytes are hex-encoded, then Ascon-128a encrypted with the
  /// link key, then hex-encoded again. This double-hex pattern matches the
  /// web frontend.
  String encryptFileKeyWithLinkKey({
    required Uint8List fileKey,
    required Uint8List linkKey,
  }) {
    final hexFileKey = _hexEncode(fileKey);
    final plaintext = Uint8List.fromList(utf8.encode(hexFileKey));
    final ciphertext = _crypto.symmetricEncryptString(
      cipher: 'ascon128a',
      key: linkKey,
      plaintext: plaintext,
    );
    return _hexEncode(ciphertext);
  }

  /// Encrypt a name (or any string) with the link key (Ascon-128a).
  ///
  /// Returns hex-encoded ciphertext.
  String encryptWithLinkKey({
    required String text,
    required Uint8List linkKey,
  }) {
    final plaintext = Uint8List.fromList(utf8.encode(text));
    final ciphertext = _crypto.symmetricEncryptString(
      cipher: 'ascon128a',
      key: linkKey,
      plaintext: plaintext,
    );
    return _hexEncode(ciphertext);
  }

  /// Decrypt a hex-encoded ciphertext using the link key (Ascon-128a).
  ///
  /// Returns the plaintext string.
  String decryptWithLinkKey({
    required String encryptedHex,
    required Uint8List linkKey,
  }) {
    final ciphertext = _hexDecode(encryptedHex);
    final plaintext = _crypto.symmetricDecryptString(
      cipher: 'ascon128a',
      key: linkKey,
      ciphertext: ciphertext,
    );
    return utf8.decode(plaintext);
  }

  Uint8List _hexDecode(String hex) => hex_utils.hexDecode(hex);

  String _hexEncode(Uint8List bytes) => hex_utils.hexEncode(bytes);
}
