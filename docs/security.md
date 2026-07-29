# Security Model

Hoodik is an end-to-end encrypted cloud storage system. This document describes how the Flutter app (iOS, Android, macOS) implements client-side encryption and protects user data at rest and in transit. It serves as a reference for developers and auditors working on the codebase.

---

## Core Principle

**End-to-end encryption is non-negotiable.** The server NEVER decrypts any user data. All encryption and decryption happens client-side -- in the browser (WASM), in the Flutter app (Rust FFI), or any future client. **No exceptions are permitted, ever.**

Public links are read-only forever. The recipient's browser performs all decryption using the link key from the URL fragment. The server serves only ciphertext (encrypted metadata + raw encrypted content streams). The server never receives the link key for decryption purposes. There will never be editing, assets, or any write path over public links.

---

## Cryptographic Primitives

All cryptographic operations are implemented in the shared Rust `cryptfns` crate and called from Dart via `flutter_rust_bridge` FFI. No cryptographic logic is implemented in Dart.

| Primitive | Algorithm |
|-----------|-----------|
| Identity / signing | Ed25519 (legacy accounts: RSA-2048 PKCS#1) |
| Key wrapping | hybrid X25519 + ML-KEM-768, post-quantum (legacy accounts: RSA-2048) -- HKDF-SHA256 combiner, AEGIS-256 wrap AEAD |
| Symmetric (default) | AEGIS-128L (hardware-accelerated AEAD) |
| Symmetric (supported) | AEGIS-256, Ascon-128a, ChaCha20-Poly1305 |
| Login | OPAQUE (RFC 9807, ristretto255-SHA512), Argon2id KSF -- password never crosses the wire |
| Private-key wrap | envelope encryption under a KEK derived (HKDF-SHA512) from the OPAQUE `export_key` |
| Search tokenization | BERT-base-cased -> SHA256 |
| Integrity | CRC16 (chunk upload), MD5, SHA1, SHA256, BLAKE2b (file hashes) |

The cipher used to encrypt each file is stored in the server database (`files.cipher`), so old files always decrypt correctly regardless of current defaults. The app reads this field and dispatches to the correct cipher at decryption time.

---

## Key Handling in the App

### Account Private Key

- The user's private key (Ed25519 identity + X25519/ML-KEM-768 wrapping keys; RSA-2048 on legacy accounts) is decrypted **in memory only** via the `decryptedPrivateKeyProvider` (`StateProvider<String?>`) in `lib/core/providers.dart`.
- Login uses OPAQUE (RFC 9807), so the password never crosses the wire. The server stores the private key envelope-encrypted under a KEK derived (HKDF-SHA512) from the OPAQUE `export_key`, which only the correct password can reproduce — the server can never derive it.
- At login, `CryptoService.decryptPrivateKey()` unwraps the envelope via Rust FFI. The plaintext PEM is held in the Riverpod state provider and never persisted to disk.
- Legacy RSA accounts still open under the old scheme and migrate to the new keys automatically on the next login.
- On logout, the in-memory private key is dropped immediately (the provider is set to `null`).

  Being precise about what that does and does not guarantee: the key is held as a Dart `String`, which is immutable, so setting the provider to `null` releases the last reference but cannot overwrite the bytes. They persist in the heap until the garbage collector reclaims that memory, and a core dump or a debugger attached in that window could still recover them. Zeroing would require carrying the key as a `Uint8List` end to end, including across the FFI boundary. The guarantee we do make is the one above: the plaintext key is never written to disk, and never leaves the device.

### PIN Encryption

- When the user sets up a PIN, the plaintext private key PEM is encrypted with Ascon-128a using the PIN as key material (same padding scheme: PIN padded to 32 chars with `'0'`, UTF-8 encoded to get 32 bytes).
- The resulting ciphertext is hex-encoded and stored in the local SQLite database (Drift).
- On unlock, `CryptoService.pinDecryptPrivateKey()` decrypts the key back into the in-memory provider using the entered PIN.
- If the PIN is wrong, the Ascon-128a decryption fails and the key is not recovered.

### Biometric Unlock

- Uses the `local_auth` package (FaceID / TouchID / fingerprint) for the biometric prompt.
- PIN is a **prerequisite** for biometric unlock -- you cannot enable biometrics without first setting a PIN.
- When biometric unlock is enabled, the PIN is stored in the platform keychain via `flutter_secure_storage` (`SecurePinStorage` in `lib/core/auth/secure_pin_storage.dart`):
  - **iOS:** Keychain with `KeychainAccessibility.unlocked`
  - **Android:** EncryptedSharedPreferences (Android Keystore-backed)
  - **macOS:** macOS Keychain
- On biometric unlock: the system verifies the biometric, then retrieves the PIN from the platform keychain, then uses the PIN to decrypt the private key from SQLite. The biometric prompt **gates access to the PIN** -- it does not replace PIN encryption.
- Legacy migration: any plaintext PINs previously stored in SQLite are automatically migrated to secure storage on app startup (`AuthService.migrateBiometricPins()`).

### Per-File Symmetric Keys

- Each file has its own random symmetric key, generated at upload time (`CryptoService.generateSymmetricKey()`).
- The file key is wrapped under the user's own key type — the hybrid X25519 + ML-KEM-768 wrap for current accounts, RSA (PKCS#1 v1.5) for legacy accounts — and stored as base64 in the server database (`files.encrypted_key`). The hybrid combines both shared secrets with HKDF-SHA256 (the salt binds both public keys and the ML-KEM ciphertext) and seals the file key with AEGIS-256, so the wrap stays secure even if one of the two algorithms is broken.
- On download, the app:
  1. Unwraps the `encrypted_key` field with the user's private key to get the hex-encoded symmetric key.
  2. Hex-decodes to raw key bytes.
  3. Uses the per-file cipher (from `files.cipher`) to decrypt the file content chunk by chunk.

---

## Privacy-Preserving Search

- File names are tokenized using a BERT-base-cased tokenizer, run **client-side** via Rust FFI (`CryptoService.tokenizeAndHashForSearch()`).
- Each token is hashed with SHA256.
- Only the SHA256 hashes are sent to the server -- never plaintext search terms or raw tokens.
- The server can match hashed tokens against stored hashed tokens without knowing what the user is searching for.
- Search queries follow the same path: the query text is tokenized and hashed client-side, then the hashes are sent to the server for matching.

---

## Offline Cache Security

- Files cached offline are stored as **encrypted chunks** -- the same ciphertext that was downloaded from the server. No re-encryption or re-keying is performed.
- Each chunk is the raw AEAD ciphertext, decryptable only with the per-file symmetric key (which itself requires the account's private key, which is PIN/biometric-protected in memory).
- Storage layout: `{applicationSupportDirectory}/offline_cache/{accountId}/{fileId}/000000.enc`, `000001.enc`, etc.
- The `OfflineManager` (`lib/core/services/offline_manager.dart`) manages cache policies:
  - **manual** -- only pinned files persist; chunks deleted after use.
  - **autoCache** (default) -- accessed files cached with LRU eviction at a configurable size limit (default 8 GB). Pinned files are never auto-evicted.
  - **fullSync** -- mirror everything from cloud (not yet implemented).

This provides:
- **Per-user isolation** on shared devices (family tablet scenario) -- each account's cache is in a separate directory and encrypted with that account's keys.
- **Protection from filesystem snooping** by other apps.
- **Defense-in-depth** -- even if device encryption is bypassed, Hoodik files remain encrypted at rest.

---

## Cookie-Based Authentication

- The app uses cookie-based auth via Dio HTTP client with a **persistent cookie jar per account**.
- Session tokens are stored in the cookie jar file, not in plaintext application storage.
- An auto-refresh timer and a 401 interceptor handle session lifecycle (automatic re-authentication on token expiry).
- Signature-based auth is also supported: the app can sign a fingerprint nonce with the user's identity private key (Ed25519, or RSA on legacy accounts) via `CryptoService.createFingerprintNonce()` to authenticate without sending the password.

---

## Threat Model

### What the server never sees

- Plaintext file content
- Plaintext file names
- Plaintext thumbnails
- Unencrypted symmetric (per-file) keys
- Unencrypted private keys
- Plaintext search terms or raw BERT tokens

### What the server does see

- Encrypted file content (ciphertext chunks)
- Encrypted file names (hex-encoded ciphertext)
- Encrypted thumbnails (hex-encoded ciphertext)
- Wrapped per-file keys (base64-encoded X25519 + ML-KEM-768 hybrid blobs; RSA on legacy accounts)
- SHA256-hashed search tokens
- File metadata: size, timestamps, chunk count, cipher type, checksum hashes
- User account info: email, OPAQUE password file (no recoverable password), identity + wrapping public keys, envelope-wrapped private key

### What stays on the device

- PIN-encrypted private key (in SQLite, encrypted with Ascon-128a)
- Biometric unlock PIN (in platform keychain, hardware-backed)
- Encrypted file cache (raw ciphertext chunks on disk)
- Cookie jar with session tokens
- Decrypted private key (in memory only, never persisted)

---

## Implementation Files

| Component | File |
|-----------|------|
| Crypto service (Ed25519, hybrid X25519 + ML-KEM-768 wrapping, RSA, symmetric ciphers, hashing, tokenization) | `lib/core/crypto/crypto_service.dart` |
| File crypto (file key decryption, name/thumbnail decryption) | `lib/core/crypto/file_crypto.dart` |
| Rust FFI source (all crypto primitives) | `rust/src/api.rs` |
| Generated FFI bindings | `lib/src/rust/api.dart` |
| Hex utilities | `lib/core/utils/hex.dart` |
| Secure PIN storage (platform keychain) | `lib/core/auth/secure_pin_storage.dart` |
| Auth service (login, PIN, biometric) | `lib/core/auth/auth_service.dart` |
| Offline cache manager | `lib/core/services/offline_manager.dart` |
| Private key provider | `lib/core/providers.dart` (`decryptedPrivateKeyProvider`) |
| File operations (upload/download orchestration) | `lib/core/services/file_operations.dart` |
| Background workers (upload, download, decrypt) | `lib/core/workers/` |

---

## Contributor Checklist

When working on security-sensitive code in this codebase:

1. **Verify E2E encryption is preserved.** The server must never receive or store plaintext data (file content, file names, thumbnails, search terms, private keys, or symmetric keys).
2. **If a feature seems to require server-side plaintext access, STOP and ask the project owner.** Do not implement it. Exhaust every client-side alternative first.
3. **Trace the data flow from client to server** and confirm encryption happens before any network call. Check that `CryptoService` or `FileCrypto` is called before any `ApiClient` request that sends file data.
4. **Never write the plaintext private key to disk.** It must only exist in the `decryptedPrivateKeyProvider` state. On logout it must be set to `null`.
5. **Never send raw BERT tokens to the server.** Only SHA256 hashes of tokens should cross the network boundary.
6. **New crypto operations must go through the Rust FFI.** Do not implement cryptographic primitives in Dart. Add new functions to `rust/src/api.rs` and regenerate bindings.
7. **There are no server-side decryption exceptions** — including for public links, where the recipient does 100% of the decryption in the browser or app with the link key from the URL fragment. The server never receives that link key and never decrypts content, names, thumbnails, or keys for anyone.
