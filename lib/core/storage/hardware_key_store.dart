import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Platform-keychain storage for raw key material (device wrap keys, the
/// SQLCipher passphrase) that must never touch the app's own SQLite file.
///
/// The values are encrypted at rest by the OS but remain ordinary, readable
/// keychain items — not Secure Enclave/StrongBox-bound keys — so anything that
/// gates low-entropy input on them must add its own KDF cost (see
/// `DeviceKeyVault`, which folds the PIN in with Argon2id).
///
/// Accessibility is [KeychainAccessibility.first_unlock_this_device]: the item
/// is readable after the first device unlock following a boot (so the database
/// opens and accounts unlock across app restarts without re-entering the device
/// passcode), but `ThisDeviceOnly` keeps it out of iCloud Keychain and out of
/// device-to-device restores — a key that only protects *this* install must not
/// ride along in a backup to another device. Android uses the Keystore-backed
/// `EncryptedSharedPreferences`.
class HardwareKeyStore {
  final FlutterSecureStorage _storage;

  HardwareKeyStore() : _storage = _defaultStorage();

  /// Injects a storage backend for tests.
  HardwareKeyStore.withStorage(this._storage);

  static FlutterSecureStorage _defaultStorage() => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);
}
