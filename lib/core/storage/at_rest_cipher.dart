import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../crypto/crypto_service.dart';
import 'hardware_key_store.dart';

/// Seals the handful of sensitive columns that would otherwise sit in plaintext
/// in the local SQLite file — a cached file name, a live session refresh token —
/// under an app-wide 256-bit key held in the platform keychain.
///
/// The threat is a cold copy of `app.db` lifted off the device without the
/// keychain: the private-key bundle is already sealed under [DeviceKeyVault]'s
/// device key, offline file content is stored as ciphertext chunks, so these
/// two columns were the last readable secrets. The key here never leaves the
/// keychain, so an extracted database yields nothing.
///
/// It fails closed. If the keychain is unreadable the cipher stays un-keyed and
/// a write is dropped to NULL rather than persisted in plaintext; a sealed value
/// that can no longer be opened — wrong or wiped key, corruption — likewise
/// reads back as null. Both surface to callers as the same benign outcome
/// (re-fetch a name, re-login for a token), never a crash — and, crucially, a
/// denied or wiped keychain can never downgrade a stored secret to plaintext.
/// The `first_unlock_this_device` key legitimately reads back empty on a
/// pre-first-unlock background launch, so this is a normal path, not an error.
class AtRestCipher {
  AtRestCipher._();

  static final AtRestCipher instance = AtRestCipher._();

  static const _keyName = 'hoodik_atrest_v1';
  static const _formatV1 = 0x01;
  static const _nonceLength = 32;
  static const _keyLength = 32;

  final CryptoService _crypto = const CryptoService();
  Uint8List? _key;
  Future<void>? _loading;

  /// Load — minting on first use — the app-wide key from the keychain into
  /// memory for the synchronous converter path. Called before the database is
  /// opened, and again on app resume: a keychain that is unreadable (a
  /// background launch before the device's first unlock) leaves the cipher
  /// un-keyed, and a later call retries rather than latching failure for the
  /// whole process. Concurrent callers share one load so a first run can never
  /// mint two competing keys.
  Future<void> ensureInitialized({HardwareKeyStore? keychain}) async {
    if (_key != null) return;
    await (_loading ??= _load(keychain).whenComplete(() => _loading = null));
  }

  Future<void> _load(HardwareKeyStore? keychain) async {
    final store = keychain ?? HardwareKeyStore();
    try {
      final existing = await store.read(_keyName);
      if (existing != null && existing.isNotEmpty) {
        _key = _crypto.hexDecode(existing);
        return;
      }
      final key = _crypto
          .generateSymmetricKey(cipher: 'aegis256')
          .sublist(0, _keyLength);
      await store.write(_keyName, _crypto.hexEncode(key));
      _key = key;
    } catch (_) {
      _key = null;
    }
  }

  /// Seal [value] for storage under AEGIS-256 with a fresh random nonce,
  /// returning the hex of `[version][nonce][ciphertext]`. Returns null when no
  /// key is loaded — the value is dropped to NULL rather than written in
  /// plaintext, which is the same "cache miss / re-login" outcome [open] already
  /// produces for an unopenable row and which keeps a denied or wiped keychain
  /// from downgrading a secret to plaintext.
  String? seal(String value) {
    final key = _key;
    if (key == null) return null;
    final nonce = _crypto
        .generateSymmetricKey(cipher: 'aegis128l')
        .sublist(0, _nonceLength);
    final ciphertext = _crypto.symmetricEncrypt(
      cipher: 'aegis256',
      key: Uint8List.fromList([...key, ...nonce]),
      plaintext: Uint8List.fromList(utf8.encode(value)),
    );
    return _crypto.hexEncode(
      Uint8List.fromList([_formatV1, ...nonce, ...ciphertext]),
    );
  }

  /// Recover a stored value. A well-formed sealed blob decrypts under the key;
  /// anything else is a legacy plaintext row and comes back verbatim. Returns
  /// null only when a sealed blob cannot be opened (wrong, rotated, or wiped
  /// key, or corruption).
  String? open(String stored) {
    final Uint8List bytes;
    try {
      bytes = _crypto.hexDecode(stored);
    } catch (_) {
      return stored;
    }
    if (bytes.length < 1 + _nonceLength + 1 || bytes[0] != _formatV1) {
      return stored;
    }
    final key = _key;
    if (key == null) return null;
    try {
      final nonce = bytes.sublist(1, 1 + _nonceLength);
      final ciphertext = bytes.sublist(1 + _nonceLength);
      final plaintext = _crypto.symmetricDecrypt(
        cipher: 'aegis256',
        key: Uint8List.fromList([...key, ...nonce]),
        ciphertext: ciphertext,
      );
      return utf8.decode(plaintext);
    } catch (_) {
      return null;
    }
  }

  /// Drops the in-memory key so a following [ensureInitialized] re-reads the
  /// keychain — used to isolate tests that share the singleton.
  @visibleForTesting
  void resetForTesting() {
    _key = null;
    _loading = null;
  }
}

/// Drift converter that seals a nullable text column under [AtRestCipher]. Null
/// passes through; a value that cannot be opened surfaces as null so an
/// un-decryptable row behaves as a cache miss rather than throwing.
class AtRestTextConverter extends TypeConverter<String?, String?> {
  const AtRestTextConverter();

  @override
  String? toSql(String? value) =>
      value == null ? null : AtRestCipher.instance.seal(value);

  @override
  String? fromSql(String? fromDb) =>
      fromDb == null ? null : AtRestCipher.instance.open(fromDb);
}
