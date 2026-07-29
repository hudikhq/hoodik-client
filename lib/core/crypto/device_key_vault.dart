import 'dart:convert';
import 'dart:typed_data';

import '../../src/rust/api.dart' as rust;
import '../storage/hardware_key_store.dart';
import 'crypto_service.dart';

/// Outcome of unwrapping a stored PIN blob: the recovered bundle plus whether
/// it came from a superseded wrap scheme and therefore wants re-sealing under
/// the current format.
typedef UnwrappedBundle = ({String plaintext, bool wasLegacy});

/// Wraps the on-device private-key bundle under a random 256-bit device key
/// held in the platform keychain, replacing the old scheme that derived the
/// wrap key straight from the PIN.
///
/// The threat this closes: the legacy blob in the (previously plaintext) SQLite
/// file was `Ascon128a(bundle, pad(pin))` — a 6-digit PIN is ~20 bits, so an
/// extracted `app.db` cracked offline in under a second. Here the bundle is
/// sealed under a 256-bit random key that only lives in the keychain, so an
/// extracted `app.db` yields nothing without also extracting the keychain.
///
/// The keychain item is app-readable rather than a Secure Enclave/StrongBox
/// key (see [HardwareKeyStore]), so the PIN's entropy still matters against an
/// attacker who extracts both stores. The v3 wrap key is therefore
/// `Argon2id(deviceKey ‖ pin, salt)` — every PIN guess costs a 64 MiB
/// memory-hard derivation instead of one SHA-256 (the v2 fold). v2 blobs still
/// unwrap and are flagged for re-sealing, so enrolled users migrate to v3 on
/// their next successful unlock without re-entering anything.
class DeviceKeyVault {
  final HardwareKeyStore _keychain;
  final CryptoService _crypto;

  DeviceKeyVault({
    HardwareKeyStore? keychain,
    CryptoService crypto = const CryptoService(),
  }) : _keychain = keychain ?? HardwareKeyStore(),
       _crypto = crypto;

  static const _keyPrefix = 'hoodik_devkey_';
  static const _formatV2 = 0x02;
  static const _formatV3 = 0x03;
  static const _nonceLength = 32;
  static const _saltLength = 16;

  String _deviceKeyName(String accountId) => '$_keyPrefix$accountId';

  /// Seal [plaintext] under the account's device key, creating that key on
  /// first use. Returns the hex blob to persist in `pinEncryptedPrivateKey`:
  /// `0x03 ‖ salt ‖ nonce ‖ ciphertext`.
  Future<String> wrapBundle(
    String accountId,
    String plaintext,
    String pin,
  ) async {
    final deviceKey = await _getOrCreateDeviceKey(accountId);
    final salt = _crypto
        .generateSymmetricKey(cipher: 'aegis128l')
        .sublist(0, _saltLength);
    final wrapKey = await _deriveWrapKey(deviceKey, pin, salt);
    final nonce = _crypto
        .generateSymmetricKey(cipher: 'aegis128l')
        .sublist(0, _nonceLength);

    final ciphertext = _crypto.symmetricEncrypt(
      cipher: 'aegis256',
      key: Uint8List.fromList([...wrapKey, ...nonce]),
      plaintext: Uint8List.fromList(utf8.encode(plaintext)),
    );

    return _crypto.hexEncode(
      Uint8List.fromList([_formatV3, ...salt, ...nonce, ...ciphertext]),
    );
  }

  /// Recover the bundle from [storedHex]. A v3 blob decrypts under the
  /// Argon2id-folded device key; a v2 blob decrypts under the SHA-256 fold and
  /// is flagged for re-sealing; a legacy blob decrypts under the PIN alone and
  /// is likewise flagged. Throws on a wrong PIN, a missing device key, or a
  /// corrupt blob — callers treat any throw as "unlock failed".
  Future<UnwrappedBundle> unwrapBundle(
    String accountId,
    String pin,
    String storedHex,
  ) async {
    final bytes = _crypto.hexDecode(storedHex);
    if (bytes.isNotEmpty && bytes[0] == _formatV3) {
      return (
        plaintext: await _unwrapV3(accountId, pin, bytes),
        wasLegacy: false,
      );
    }
    if (bytes.isNotEmpty && bytes[0] == _formatV2) {
      return (
        plaintext: await _unwrapV2(accountId, pin, bytes),
        wasLegacy: true,
      );
    }
    return (
      plaintext: _crypto.pinDecryptPrivateKey(storedHex, pin),
      wasLegacy: true,
    );
  }

  /// Remove the account's device key. Called from every teardown path so a
  /// forgotten/removed account leaves no wrap key behind in the keychain.
  Future<void> deleteDeviceKey(String accountId) =>
      _keychain.delete(_deviceKeyName(accountId));

  Future<String> _unwrapV3(
    String accountId,
    String pin,
    Uint8List bytes,
  ) async {
    final deviceKey = await _requireDeviceKey(accountId);
    final salt = bytes.sublist(1, 1 + _saltLength);
    final nonce = bytes.sublist(
      1 + _saltLength,
      1 + _saltLength + _nonceLength,
    );
    final ciphertext = bytes.sublist(1 + _saltLength + _nonceLength);
    final wrapKey = await _deriveWrapKey(deviceKey, pin, salt);

    final plaintext = _crypto.symmetricDecrypt(
      cipher: 'aegis256',
      key: Uint8List.fromList([...wrapKey, ...nonce]),
      ciphertext: ciphertext,
    );
    return utf8.decode(plaintext);
  }

  Future<String> _unwrapV2(
    String accountId,
    String pin,
    Uint8List bytes,
  ) async {
    final deviceKey = await _requireDeviceKey(accountId);
    final wrapKey = _legacyV2WrapKey(deviceKey, pin);
    final nonce = bytes.sublist(1, 1 + _nonceLength);
    final ciphertext = bytes.sublist(1 + _nonceLength);

    final plaintext = _crypto.symmetricDecrypt(
      cipher: 'aegis256',
      key: Uint8List.fromList([...wrapKey, ...nonce]),
      ciphertext: ciphertext,
    );
    return utf8.decode(plaintext);
  }

  Future<Uint8List> _requireDeviceKey(String accountId) async {
    final deviceKeyHex = await _keychain.read(_deviceKeyName(accountId));
    if (deviceKeyHex == null || deviceKeyHex.isEmpty) {
      throw StateError('device key missing for account');
    }
    return _crypto.hexDecode(deviceKeyHex);
  }

  Future<Uint8List> _getOrCreateDeviceKey(String accountId) async {
    final name = _deviceKeyName(accountId);
    final existing = await _keychain.read(name);
    if (existing != null && existing.isNotEmpty) {
      return _crypto.hexDecode(existing);
    }
    final deviceKey = _crypto.generateSymmetricKey(cipher: 'aegis256');
    await _keychain.write(name, _crypto.hexEncode(deviceKey));
    return deviceKey;
  }

  /// The 32-byte AEGIS-256 key binding the device key to the PIN. Memory-hard
  /// on purpose: with both `app.db` and the keychain item in hand, the PIN is
  /// the only remaining secret, and Argon2id keeps its ~20 bits from being
  /// brute-forced in seconds. The random nonce lives in the blob, so
  /// re-wrapping the same account never reuses a (key, nonce) pair.
  Future<Uint8List> _deriveWrapKey(
    Uint8List deviceKey,
    String pin,
    Uint8List salt,
  ) {
    return rust.argon2IdDeriveKey(
      secret: [...deviceKey, ...utf8.encode(pin)],
      salt: salt,
    );
  }

  /// The v2 wrap key: a single SHA-256 over `deviceKey ‖ pin`. Too fast a fold
  /// once the keychain item is extracted alongside `app.db`, hence superseded
  /// by the Argon2id derivation — kept only so existing v2 blobs unwrap and
  /// get re-sealed.
  Uint8List _legacyV2WrapKey(Uint8List deviceKey, String pin) {
    final material = <int>[...deviceKey, ...utf8.encode(pin)];
    return _crypto.hexDecode(_crypto.sha256(data: material));
  }
}
