part of 'auth_service.dart';

extension AuthServiceSession on AuthService {
  /// Try to restore the last active session on app start.
  Future<bool> tryRestoreSession() async {
    final account = await _db.getActiveAccount();
    if (account == null) return false;

    final servers = await _db.getAllServers();
    final server = servers.where((s) => s.id == account.serverId).firstOrNull;
    if (server == null) return false;

    // Create client with persisted cookies for this account
    final client = await ApiClient.create(
      baseUrl: server.url,
      accountId: account.id,
    );

    // For header-auth servers, restore persisted tokens into the client.
    if (server.useHeaderAuth) {
      client.useHeaderAuth = true;
      if (account.headerJwt != null && account.headerRefreshToken != null) {
        client.setTokens(
          jwt: account.headerJwt!,
          refresh: account.headerRefreshToken!,
        );
      } else {
        return false; // No tokens to restore
      }
    }

    // Check if the stored session (cookies or tokens) is still present
    if (!await client.hasSession) return false;

    try {
      final authResp = await client.auth.getSelf();
      _activeServer = server;
      _activeAccount = account;
      _setActiveClient(client, authResp: authResp);

      return true;
    } catch (e) {
      // Session expired — try refresh
      _log.info(
        'getSelf failed — attempting refresh',
        fields: {'error': redactException(e)},
      );
      try {
        final authResp = await client.auth.refresh();
        _activeServer = server;
        _activeAccount = account;
        _setActiveClient(client, authResp: authResp);

        return true;
      } catch (refreshError) {
        _log.warn(
          'session refresh also failed',
          fields: {'error': redactException(refreshError)},
        );
        return false;
      }
    }
  }

  /// Validate and add a server. Returns the server record.
  Future<Server> addServer(String url) async {
    // Normalize URL
    var normalized = url.trim();
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    // Check if server is reachable
    final client = ApiClient.createTemporary(baseUrl: normalized);
    await client.auth.checkLivenessOrThrow();

    // Check if already exists
    final existing = await _db.getServerByUrl(normalized);
    if (existing != null) return existing;

    // Extract friendly name from URL
    final uri = Uri.parse(normalized);
    final name = uri.host;

    return await _db.insertServer(
      ServersCompanion(
        id: Value(_uuid.v4()),
        url: Value(normalized),
        name: Value(name),
      ),
    );
  }

  /// Delete a server and all its associated accounts from the database.
  Future<void> deleteServer(String serverId) async {
    // If the active account belongs to this server, clear state.
    if (_activeAccount != null && _activeAccount!.serverId == serverId) {
      if (_activeClient != null) {
        await _activeClient!.logout();
      }
      _clearActiveClient();
      _activeAccount = null;
      _activeServer = null;
      _decryptedPrivateKey = null;
      _decryptedWrappingPrivateKey = null;
      _decryptedLegacyRsaPrivateKey = null;
    }
    await _db.deleteServer(serverId);
  }

  /// Attempt to recover the decrypted private key for [accountId] using
  /// the biometric PIN stored in the platform keychain. This is a silent
  /// operation — no user interaction needed.
  Future<void> _tryRecoverPrivateKey(String accountId) async {
    final pin = await _securePinStorage.read(accountId);
    if (pin == null || pin.isEmpty) return;

    final encryptedHex = await _db.getPinEncryptedKey(accountId);
    if (encryptedHex == null || encryptedHex.isEmpty) return;

    try {
      final decoded = await _unwrapAndMigrate(accountId, pin, encryptedHex);
      _decryptedPrivateKey = decoded.identity;
      _decryptedWrappingPrivateKey = decoded.wrapping;
      _decryptedLegacyRsaPrivateKey = null;
      _log.info('private key recovered via stored PIN');
    } catch (e) {
      _log.warn(
        'failed to recover private key via stored PIN',
        fields: {'error': redactException(e)},
      );
    }
  }

  Future<void> logout() async {
    final accountId = _activeAccount?.id;
    if (_activeClient != null) {
      await _activeClient!.logout();
    }
    _clearActiveClient();
    // Clear persisted header tokens so they can't be reused.
    if (accountId != null) {
      await _db.clearHeaderTokens(accountId);
    }
    _activeAccount = null;
    _activeServer = null;
    _decryptedPrivateKey = null;
    _decryptedWrappingPrivateKey = null;
    _decryptedLegacyRsaPrivateKey = null;
  }

  Future<void> removeAccount(String accountId) async {
    // Keychain items are keyed by account id and are not covered by the DB row
    // delete, so drop the device key and biometric PIN before the row goes.
    await _vault.deleteDeviceKey(accountId);
    await _securePinStorage.delete(accountId);
    await _db.deleteAccount(accountId);

    if (_activeAccount?.id == accountId) {
      _clearActiveClient();
      _activeAccount = null;
      _activeServer = null;
      _decryptedPrivateKey = null;
      _decryptedWrappingPrivateKey = null;
      _decryptedLegacyRsaPrivateKey = null;
    }
  }
}
