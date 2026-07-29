import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hoodik_app/core/auth/auth_service.dart';
import 'package:hoodik_app/core/auth/secure_pin_storage.dart';
import 'package:hoodik_app/core/storage/database.dart';

/// Non-networked [AuthService] stand-in for the login golden. Every
/// method resolves synchronously to the empty-state defaults — no
/// cookies, no keychain, no HTTP — so the screen always renders the
/// fresh-install variant of the form.
class LoginGoldenAuthService extends AuthService {
  LoginGoldenAuthService()
    : super(
        AppDatabase.forTesting(NativeDatabase.memory()),
        _GoldenPinStorage(),
      );

  @override
  Future<List<Account>> getAccountsForServer(String serverId) async => const [];

  @override
  Future<List<Account>> getAccounts() async => const [];

  @override
  Future<List<Server>> getServers() async => const [];

  @override
  Future<bool> hasPinSetup(String accountId) async => false;

  @override
  Future<bool> hasBiometricSetup(String accountId) async => false;

  @override
  Future<String?> getBiometricPin(String accountId) async => null;
}

class _GoldenPinStorage extends SecurePinStorage {
  _GoldenPinStorage() : super.forTesting(const FlutterSecureStorage());

  @override
  Future<void> store(String accountId, String pin) async {}

  @override
  Future<String?> read(String accountId) async => null;

  @override
  Future<bool> has(String accountId) async => false;

  @override
  Future<void> delete(String accountId) async {}
}
