import 'dart:convert';
import 'dart:typed_data';

import '../../src/rust/api.dart' as rust;
import '../utils/hex.dart' as hex_utils;

/// Provides high-level crypto operations used throughout the app.
///
/// All heavy lifting (AEAD ciphers, RSA) is delegated to the Rust `cryptfns`
/// crate via flutter_rust_bridge generated bindings in `core/rust/api.dart`.
class CryptoService {
  const CryptoService();

  /// Decrypt the user's PEM private key from the server's
  /// `encrypted_private_key` field.
  ///
  /// The server stores the private key encrypted with Ascon-128a using the
  /// user's password as key material:
  ///   1. Pad (or truncate) the password to 32 bytes by appending '0' chars,
  ///      then encode as UTF-8.
  ///   2. Hex-decode `encryptedPrivateKeyHex` to get the ciphertext bytes.
  ///   3. Ascon-128a decrypt (via `cipher_decrypt("ascon128a", key, ct)`).
  ///   4. The resulting plaintext bytes are the PEM private key as UTF-8.
  String decryptPrivateKey({
    required String encryptedPrivateKeyHex,
    required String password,
  }) {
    final key = _passwordToKey(password);
    final ciphertext = hex_utils.hexDecode(encryptedPrivateKeyHex);

    final plaintext = rust.cipherDecrypt(
      cipher: 'ascon128a',
      key: key,
      ciphertext: ciphertext,
    );

    return utf8.decode(plaintext);
  }

  /// Decrypt a legacy PIN-derived private-key blob (Ascon-128a, PIN padded to
  /// 32 bytes). Retained only for [DeviceKeyVault]'s legacy-migration branch,
  /// which opens a pre-vault blob with the PIN once so it can be re-sealed under
  /// the device key. New blobs are written by the vault, never encrypted here.
  ///
  /// Throws if the PIN is wrong (the AEAD tag fails).
  String pinDecryptPrivateKey(String encryptedHex, String pin) {
    final key = _passwordToKey(pin);
    final ciphertext = hex_utils.hexDecode(encryptedHex);

    final plaintext = rust.cipherDecrypt(
      cipher: 'ascon128a',
      key: key,
      ciphertext: ciphertext,
    );

    return utf8.decode(plaintext);
  }

  /// Challenge for `POST /api/auth/signature`: a fresh 16-byte random nonce
  /// (lowercase hex) plus the current unix time, bound into the canonical
  /// `{fingerprint}:{timestamp}:{nonce}` the server reconstructs and verifies.
  /// A random nonce — unlike the old deterministic minute bucket — keeps two
  /// same-minute logins distinct, so the server's replay guard only ever
  /// rejects true replays.
  ({String nonce, int timestamp, String message}) createSignatureLoginChallenge(
    String fingerprint,
  ) {
    final nonce = hex_utils.hexEncode(
      Uint8List.fromList(
        rust.cipherGenerateKey(cipher: 'aegis128l').sublist(0, 16),
      ),
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (
      nonce: nonce,
      timestamp: timestamp,
      message: '$fingerprint:$timestamp:$nonce',
    );
  }

  /// Decrypt a base64-encoded RSA-PKCS1v15 ciphertext using the given PEM
  /// private key. Returns the plaintext as a UTF-8 string.
  ///
  /// Used to decrypt each file's `encrypted_key` field.
  String rsaDecrypt({
    required String ciphertextBase64,
    required String privateKeyPem,
  }) {
    return rust.rsaDecrypt(
      ciphertextB64: ciphertextBase64,
      privateKeyPem: privateKeyPem,
    );
  }

  /// Decrypt `ciphertextBytes` using the specified symmetric cipher and key.
  ///
  /// Supported ciphers: `"aegis128l"`, `"ascon128a"`, `"chacha20poly1305"`,
  /// `"aegis256"`.
  Uint8List symmetricDecrypt({
    required String cipher,
    required Uint8List key,
    required Uint8List ciphertext,
  }) {
    return rust.cipherDecrypt(cipher: cipher, key: key, ciphertext: ciphertext);
  }

  /// Sign a message with the user's RSA private key (PSS + SHA256).
  /// Returns the signature as a base64 string.
  String rsaSign({required String message, required String privateKeyPem}) {
    return rust.rsaSign(message: message, privateKeyPem: privateKeyPem);
  }

  /// Encrypt a plaintext string with an RSA public key (PKCS#1 v1.5).
  /// Returns the ciphertext as a base64 string.
  String rsaEncrypt({required String plaintext, required String publicKeyPem}) {
    return rust.rsaEncrypt(plaintext: plaintext, publicKeyPem: publicKeyPem);
  }

  /// Generate a random symmetric key for the given cipher.
  Uint8List generateSymmetricKey({String cipher = 'aegis128l'}) {
    return rust.cipherGenerateKey(cipher: cipher);
  }

  /// Encrypt plaintext bytes using the specified symmetric cipher and key.
  Uint8List symmetricEncrypt({
    required String cipher,
    required Uint8List key,
    required Uint8List plaintext,
  }) {
    return rust.cipherEncrypt(cipher: cipher, key: key, plaintext: plaintext);
  }

  /// Encrypt a metadata string (file name, thumbnail, link fields) with a
  /// fresh random nonce prepended to the ciphertext. Metadata strings share
  /// the file key with the content chunks, so [symmetricEncrypt] would reuse
  /// the key blob's embedded nonce across all of them. The format lives in
  /// `cryptfns::cipher::Cipher::encrypt_string` so every client produces
  /// identical output.
  Uint8List symmetricEncryptString({
    required String cipher,
    required Uint8List key,
    required Uint8List plaintext,
  }) {
    return rust.cipherEncryptString(
      cipher: cipher,
      key: key,
      plaintext: plaintext,
    );
  }

  /// Decrypt a metadata string. Tries the prepended random nonce first, then
  /// the key blob's own nonce so metadata written before per-string nonces
  /// still decrypts — the AEAD tag rejects the wrong branch.
  Uint8List symmetricDecryptString({
    required String cipher,
    required Uint8List key,
    required Uint8List ciphertext,
  }) {
    return rust.cipherDecryptString(
      cipher: cipher,
      key: key,
      ciphertext: ciphertext,
    );
  }

  /// Encrypt one chunk of a multi-chunk payload. Each chunk gets its own
  /// derived nonce — reusing the key blob's embedded nonce across chunks
  /// voids the AEAD guarantees. Chunk 0 is byte-identical to
  /// [symmetricEncrypt], keeping single-chunk payloads wire-compatible.
  Uint8List symmetricEncryptChunk({
    required String cipher,
    required Uint8List key,
    required int chunkIndex,
    required Uint8List plaintext,
  }) {
    // Owned copies. The iOS/macOS AOT binding for Vec<u8> has SIGSEGV'd
    // at 0xf when the Dart buffer was a view into a larger list — note
    // save encrypts sublist chunks. A fresh list is what the CST encoder
    // can hand rust without aliasing the caller's memory.
    final keyCopy = Uint8List.fromList(key);
    final plainCopy = Uint8List.fromList(plaintext);
    return rust.cipherEncryptChunk(
      cipher: cipher,
      key: keyCopy,
      chunkIndex: BigInt.from(chunkIndex),
      plaintext: plainCopy,
    );
  }

  /// Decrypt one chunk of a multi-chunk payload. Tries the per-chunk nonce
  /// first, then the blob's own nonce so files uploaded before per-chunk
  /// nonces existed still decrypt — the AEAD tag rejects the wrong branch.
  Uint8List symmetricDecryptChunk({
    required String cipher,
    required Uint8List key,
    required int chunkIndex,
    required Uint8List ciphertext,
  }) {
    return rust.cipherDecryptChunk(
      cipher: cipher,
      key: key,
      chunkIndex: BigInt.from(chunkIndex),
      ciphertext: ciphertext,
    );
  }

  /// DER-encode a `ShareRequestPayloadV1`.
  Uint8List sharePayloadEncodeV1({
    required Uint8List senderId,
    required Uint8List recipientId,
    required Uint8List recipientPubkeyFingerprint,
    required int shareRole,
    required Uint8List rootFileId,
    required Uint8List entriesHash,
    required int timestamp,
    required Uint8List nonce,
  }) {
    return rust.sharePayloadEncodeV1(
      senderId: senderId,
      recipientId: recipientId,
      recipientPubkeyFingerprint: recipientPubkeyFingerprint,
      shareRole: shareRole,
      rootFileId: rootFileId,
      entriesHash: entriesHash,
      timestamp: timestamp,
      nonce: nonce,
    );
  }

  /// DER-encode a `MemberSigPayloadV1`.
  Uint8List memberSigEncodeV1({
    required Uint8List userId,
    required Uint8List pubkeyDer,
    required Uint8List fingerprint,
    required int shareRole,
    required int signedAt,
  }) {
    return rust.memberSigEncodeV1(
      userId: userId,
      pubkeyDer: pubkeyDer,
      fingerprint: fingerprint,
      shareRole: shareRole,
      signedAt: signedAt,
    );
  }

  /// DER-encode a `FolderMemberListV1`. Members travel as flat parallel
  /// arrays; the encoder sorts by `userId`.
  Uint8List folderMemberListEncodeV1({
    required Uint8List folderId,
    required Uint8List folderOwnerId,
    required Uint8List userIds,
    required Uint8List pubkeyFingerprints,
    required Uint8List shareRoles,
    required Uint8List isOwnerFlags,
    required Uint8List signedByUserIds,
    required int membersSignedAt,
  }) {
    return rust.folderMemberListEncodeV1(
      folderId: folderId,
      folderOwnerId: folderOwnerId,
      userIds: userIds,
      pubkeyFingerprints: pubkeyFingerprints,
      shareRoles: shareRoles,
      isOwnerFlags: isOwnerFlags,
      signedByUserIds: signedByUserIds,
      membersSignedAt: membersSignedAt,
    );
  }

  /// DER-encode an `AuditEventRowV1`. Pass byte `255` for `shareRole` to
  /// encode a row without a role.
  Uint8List auditEventEncodeV1({
    required Uint8List senderId,
    required Uint8List recipientId,
    required Uint8List fileId,
    required String action,
    required int shareRole,
    required int createdAt,
  }) {
    return rust.auditEventEncodeV1(
      senderId: senderId,
      recipientId: recipientId,
      fileId: fileId,
      action: action,
      shareRole: shareRole,
      createdAt: createdAt,
    );
  }

  /// Sign raw bytes with the user's RSA private key (PSS + SHA256).
  /// Sharing payloads are DER blobs, not UTF-8, so they take this path
  /// rather than [rsaSign]. Returns the signature as a base64 string.
  String rsaSignBytes({
    required Uint8List message,
    required String privateKeyPem,
  }) {
    return rust.rsaSignBytes(message: message, privateKeyPem: privateKeyPem);
  }

  /// Verify an RSA-PSS-SHA256 signature over raw bytes with a public key.
  bool rsaVerifyBytes({
    required Uint8List message,
    required String signature,
    required String publicKeyPem,
  }) {
    return rust.rsaVerifyBytes(
      message: message,
      signature: signature,
      publicKeyPem: publicKeyPem,
    );
  }

  /// SHA-256 fingerprint of an RSA public key PEM, matching the server's
  /// `users.fingerprint`. Used to verify a recipient's identity client-side.
  String rsaFingerprintPublic({required String publicKeyPem}) {
    return rust.rsaFingerprintPublic(publicKeyPem: publicKeyPem);
  }

  /// PKCS#1 DER bytes of an RSA public key PEM — the `pubkey_der` octet
  /// string the member-signature encoder commits to.
  Uint8List rsaPkcs1DerFromPem({required String publicKeyPem}) {
    return rust.rsaPkcs1DerFromPem(publicKeyPem: publicKeyPem);
  }

  /// The `MemberSigPayloadV1.pubkey_der` canonical for a member of the given
  /// key type: PKCS#1 DER body for `"rsa"`, SPKI DER body for `"curve25519"`.
  /// The dispatch lives in the FFI so web and mobile commit to identical bytes.
  Uint8List memberPubkeyDer({
    required String keyType,
    required String publicKeyPem,
  }) {
    return rust.memberPubkeyDer(keyType: keyType, publicKeyPem: publicKeyPem);
  }

  /// Generate a new hybrid X25519 + ML-KEM-768 wrapping keypair (PEM-encoded).
  rust.WrappingKeyPair generateWrappingKeyPair() {
    return rust.generateWrappingKeypair();
  }

  /// Wrap a file key for a recipient's hybrid wrapping public key.
  /// Returns the wrap blob as a base64 string.
  String wrappingWrap({
    required Uint8List fileKey,
    required String recipientPublicPem,
  }) {
    return rust.wrappingWrap(
      fileKey: fileKey,
      recipientPublicPem: recipientPublicPem,
    );
  }

  /// Unwrap a base64 wrap blob with a hybrid wrapping private key.
  /// Returns the file key bytes. Throws if the key doesn't match.
  Uint8List wrappingUnwrap({required String blob, required String privatePem}) {
    return rust.wrappingUnwrap(blob: blob, privatePem: privatePem);
  }

  /// Generate a new Ed25519 keypair (PKCS#8 private, SPKI public PEM).
  rust.Ed25519KeyPair generateEd25519KeyPair() {
    return rust.generateEd25519Keypair();
  }

  /// Sign a message with an Ed25519 private key.
  /// Returns the signature as a base64 string.
  String ed25519Sign({required String message, required String privatePem}) {
    return rust.ed25519Sign(message: message, privatePem: privatePem);
  }

  /// Sign raw bytes with an Ed25519 private key.
  /// Returns the signature as a base64 string.
  String ed25519SignBytes({
    required Uint8List message,
    required String privatePem,
  }) {
    return rust.ed25519SignBytes(message: message, privatePem: privatePem);
  }

  /// Verify an Ed25519 signature.
  bool ed25519Verify({
    required String message,
    required String signature,
    required String publicPem,
  }) {
    return rust.ed25519Verify(
      message: message,
      signature: signature,
      publicPem: publicPem,
    );
  }

  /// Verify an Ed25519 signature over raw bytes.
  bool ed25519VerifyBytes({
    required Uint8List message,
    required String signature,
    required String publicPem,
  }) {
    return rust.ed25519VerifyBytes(
      message: message,
      signature: signature,
      publicPem: publicPem,
    );
  }

  /// SHA-256 fingerprint of a SPKI public key PEM (64 hex chars), matching
  /// the server-side fingerprint for Curve25519 identities.
  String spkiFingerprint({required String publicPem}) {
    return rust.spkiFingerprint(publicPem: publicPem);
  }

  /// Verify another user's key-transition certificate: the old key's
  /// endorsement of the new keys, the new identity key's proof of possession,
  /// and each fingerprint against the key it names. [userId] must be the 16
  /// UUID bytes the caller resolved the signer as — the canonical binds it, so
  /// a certificate replayed from a different account fails.
  bool transitionVerify({
    required Uint8List userId,
    required String oldKeyType,
    required Uint8List oldKeySpki,
    required String oldFingerprint,
    required String newIdentityKeyPem,
    required String newWrappingKeyPem,
    required String newFingerprint,
    required int issuedAt,
    required String oldSignature,
    required String newSignature,
  }) {
    return rust.transitionVerify(
      userId: userId,
      oldKeyType: oldKeyType,
      oldKeySpki: oldKeySpki,
      oldFingerprint: oldFingerprint,
      newIdentityKeyPem: newIdentityKeyPem,
      newWrappingKeyPem: newWrappingKeyPem,
      newFingerprint: newFingerprint,
      issuedAt: issuedAt,
      oldSignature: oldSignature,
      newSignature: newSignature,
    );
  }

  /// DER-encode an `AuditEventSigInputV1`. Pass an empty list for an absent
  /// `recipientId` and byte `255` for an absent role.
  Uint8List auditEventSigInputEncodeV1({
    required Uint8List senderId,
    required Uint8List recipientId,
    required Uint8List fileId,
    required int action,
    required int shareRoleBefore,
    required int shareRoleAfter,
    required int timestamp,
  }) {
    return rust.auditEventSigInputEncodeV1(
      senderId: senderId,
      recipientId: recipientId,
      fileId: fileId,
      action: action,
      shareRoleBefore: shareRoleBefore,
      shareRoleAfter: shareRoleAfter,
      timestamp: timestamp,
    );
  }

  /// DER-encode the canonical entries list `entries_hash` commits to. Inputs
  /// are flat parallel arrays; the encoder sorts by `fileId`.
  Uint8List entriesEncodeV1({
    required Uint8List fileIds,
    required Uint8List encryptedKeysFlat,
    required List<int> encryptedKeyLengths,
  }) {
    return rust.entriesEncodeV1(
      fileIds: fileIds,
      encryptedKeysFlat: encryptedKeysFlat,
      encryptedKeyLengths: encryptedKeyLengths,
    );
  }

  /// Compute SHA-256 hash of the input bytes. Returns hex string.
  String sha256({required List<int> data}) {
    return rust.sha256Digest(data: data);
  }

  /// Compute CRC-16 checksum. Returns hex string.
  String crc16({required List<int> data}) {
    return rust.crc16Digest(data: data);
  }

  /// Tokenize text and return SHA-256 hashed search tokens with weights.
  ///
  /// Returns tokens in `"hash:weight"` format, matching the web frontend.
  /// The server's `from_vec` parser requires this format — tokens without
  /// weights are silently dropped. Input is lowercased to match the web
  /// frontend's behaviour (`file.name.toLowerCase()`).
  /// The account-wide search key, derived from the private key that is
  /// already unlocked in memory.
  ///
  /// Curve accounts derive from the wrapping key and legacy RSA accounts from
  /// their RSA key, whichever the account actually has. Never leaves the
  /// device and is never persisted.
  String searchRootKey(String privateKeyPem) =>
      rust.searchRootKey(privateKeyPem: privateKeyPem);

  /// A file's search key, derived from the key its contents are encrypted
  /// with. That key reaches every recipient of a share, which is what lets a
  /// share grant skip touching the index.
  String searchFileKey(Uint8List fileKey) =>
      rust.searchFileKey(fileKey: fileKey);

  /// Tag one value: a file name for `name_hash`, or a single query word.
  String searchTag(String key, String value) =>
      rust.searchTag(keyHex: key, value: value);

  /// Tokenize and tag text, in the `"{tag}:{weight}"` form the index accepts.
  ///
  /// Folds case here so a capitalized note is findable by a lowercased query.
  /// cryptfns lowercases too, but the loaded tokenizer does not reliably fold
  /// on its own, so this fold is load-bearing rather than redundant — every
  /// client (Dart here, JS on web) folds the same way before tagging. See the
  /// cross-client vector in `search_tagging_test.dart`.
  List<String> searchTags(String key, String text) {
    final raw = rust.searchTagTokens(keyHex: key, text: text.toLowerCase());
    if (raw.isEmpty) return [];
    return raw.split(';').where((s) => s.isNotEmpty).toList();
  }

  /// Bare tags, as the search route receives them: the weight that ranks a
  /// hit is the stored one, not the query's.
  List<String> searchQueryTags(String key, String text) =>
      searchTags(key, text).map((entry) => entry.split(':').first).toList();

  /// Decode a hex-encoded string to bytes (public API).
  Uint8List hexDecode(String hex) => hex_utils.hexDecode(hex);

  /// Encode bytes to a hex string (public API).
  String hexEncode(Uint8List bytes) => hex_utils.hexEncode(bytes);

  /// Build a 32-byte key from the user's password.
  ///
  /// The password is padded with '0' characters to 32 chars (or truncated if
  /// longer), then encoded as UTF-8 bytes.
  Uint8List _passwordToKey(String password) {
    final padded = password.length >= 32
        ? password.substring(0, 32)
        : password.padRight(32, '0');
    return Uint8List.fromList(utf8.encode(padded));
  }
}
