import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores and retrieves the biometric unlock PIN using the platform keychain
/// (iOS Keychain / Android Keystore / macOS Keychain).
///
/// This replaces the previous approach of storing the PIN in plaintext in
/// SQLite. The keychain encrypts the PIN at rest and only releases it while
/// this device is unlocked, but the item stays readable to the app process —
/// the biometric prompt is enforced by the app (local_auth) before this store
/// is read, not by a keychain access-control list.
class SecurePinStorage {
  static const _keyPrefix = 'hoodik_bio_pin_';

  final FlutterSecureStorage _storage;

  SecurePinStorage()
    : _storage = FlutterSecureStorage(
        aOptions: _androidOptions,
        iOptions: _iosOptions,
        mOptions: _macOptions,
      );

  /// Testing constructor — allows injecting a mock storage instance.
  SecurePinStorage.forTesting(this._storage);

  static AndroidOptions get _androidOptions =>
      const AndroidOptions(encryptedSharedPreferences: true);

  // The PIN is only read right after a successful biometric prompt, so the
  // device is unlocked by definition; `ThisDeviceOnly` keeps it out of iCloud
  // Keychain and device-to-device restores. Reads don't filter on
  // accessibility, so entries written under the old value stay readable and
  // pick up this one on their next write.
  static IOSOptions get _iosOptions => const IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  );

  static MacOsOptions get _macOptions => const MacOsOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  );

  String _key(String accountId) => '$_keyPrefix$accountId';

  /// Store the PIN for biometric unlock.
  Future<void> store(String accountId, String pin) async {
    await _storage.write(key: _key(accountId), value: pin);
  }

  /// Read the stored PIN, or null if not set.
  Future<String?> read(String accountId) async {
    return _storage.read(key: _key(accountId));
  }

  /// Delete the stored PIN.
  Future<void> delete(String accountId) async {
    await _storage.delete(key: _key(accountId));
  }

  /// Check whether a PIN is stored for the given account.
  Future<bool> has(String accountId) async {
    final pin = await read(accountId);
    return pin != null && pin.isNotEmpty;
  }

  /// Whether the platform supports secure storage.
  /// Desktop Linux uses libsecret; all other supported platforms have
  /// hardware-backed options.
  static bool get isSupported =>
      Platform.isIOS ||
      Platform.isAndroid ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isWindows;
}
