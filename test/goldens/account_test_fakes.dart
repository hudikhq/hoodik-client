import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hoodik_app/core/auth/auth_service.dart';
import 'package:hoodik_app/core/auth/secure_pin_storage.dart';
import 'package:hoodik_app/core/storage/database.dart';

/// Non-networked [AuthService] for the account golden. Returns fixed
/// accounts/servers and answers every PIN/biometric check with "not set
/// up" so the screen always shows the first-run state for security.
class AccountGoldenAuthService extends AuthService {
  AccountGoldenAuthService({required this.accounts, required this.servers})
    : super(
        AppDatabase.forTesting(NativeDatabase.memory()),
        _AccountGoldenPinStorage(),
      );

  final List<Account> accounts;
  final List<Server> servers;

  @override
  Future<List<Account>> getAccounts() async => accounts;

  @override
  Future<List<Server>> getServers() async => servers;

  @override
  Future<List<Account>> getAccountsForServer(String serverId) async =>
      accounts.where((a) => a.serverId == serverId).toList();

  @override
  Future<bool> hasPinSetup(String accountId) async => false;

  @override
  Future<bool> hasBiometricSetup(String accountId) async => false;

  @override
  Future<String?> getBiometricPin(String accountId) async => null;
}

class _AccountGoldenPinStorage extends SecurePinStorage {
  _AccountGoldenPinStorage() : super.forTesting(const FlutterSecureStorage());

  @override
  Future<void> store(String accountId, String pin) async {}

  @override
  Future<String?> read(String accountId) async => null;

  @override
  Future<bool> has(String accountId) async => false;

  @override
  Future<void> delete(String accountId) async {}
}
