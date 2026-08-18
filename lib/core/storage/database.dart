import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'at_rest_cipher.dart';

part 'database.g.dart';

/// Stored server connections.
class Servers extends Table {
  TextColumn get id => text()();
  TextColumn get url => text()();
  TextColumn get name => text()();

  /// Accept the server's TLS certificate even if it's self-signed or
  /// otherwise untrusted by the OS. Useful for self-hosted instances on
  /// local networks.
  BoolColumn get trustSelfSignedCerts =>
      boolean().withDefault(const Constant(false))();

  /// Whether this server uses header-based auth (`USE_HEADERS_FOR_AUTH=true`)
  /// instead of cookies. Auto-detected on first login.
  BoolColumn get useHeaderAuth =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stored accounts (one per server+user combination).
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get serverId => text().references(Servers, #id)();
  TextColumn get userId => text()();
  TextColumn get email => text()();
  TextColumn get fingerprint => text().nullable()();
  TextColumn get publicKey => text().nullable()();

  /// Hybrid wrapping public key (PEM) for curve accounts. Null for legacy
  /// RSA accounts, which wrap to [publicKey]. Encrypting a value to the
  /// account's own key (e.g. the local MCP bearer token) needs this, since the
  /// in-memory identity key of a curve account is Ed25519 and can't do RSA.
  TextColumn get wrappingPublicKey => text().nullable()();
  TextColumn get encryptedPrivateKey => text().nullable()();

  /// The private key encrypted with the user's PIN (hex string).
  /// Used for quick unlock without password.
  TextColumn get pinEncryptedPrivateKey => text().nullable()();

  /// The user's PIN stored for biometric unlock.
  /// When set, the unlock screen auto-prompts biometric and uses this PIN
  /// to decrypt the private key if authentication succeeds.
  TextColumn get biometricPin => text().nullable()();

  IntColumn get quota => integer().nullable()();
  TextColumn get role => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  /// Per-account offline cache size limit in bytes. `0` = unlimited.
  /// Defaults to null (use [kDefaultCacheLimitBytes]).
  IntColumn get cacheLimitBytes => integer().nullable()();

  /// Persisted JWT for header-auth servers (survives app restart).
  TextColumn get headerJwt => text().nullable()();

  /// Persisted refresh token UUID for header-auth servers. Sealed at rest via
  /// [AtRestTextConverter] — a live session token is account access until it
  /// rotates, so it must not sit in plaintext in a cold copy of the database.
  TextColumn get headerRefreshToken =>
      text().map(const AtRestTextConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cache policies for files/folders.
enum CachePolicyType { auto, pinned, never }

/// Cached file metadata from the server.
class CachedFiles extends Table {
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get id => text()();
  TextColumn get dirId => text().nullable()();
  TextColumn get encryptedName => text()();

  /// Decrypted file name, cached for display. Sealed at rest via
  /// [AtRestTextConverter] so a cold copy of the database never reveals the
  /// plaintext names of cached files.
  TextColumn get decryptedName =>
      text().map(const AtRestTextConverter()).nullable()();
  TextColumn get encryptedKey => text().nullable()();
  TextColumn get encryptedThumbnail => text().nullable()();
  TextColumn get mime => text()();
  IntColumn get size => integer().nullable()();
  IntColumn get chunks => integer().nullable()();
  IntColumn get chunksStored => integer().nullable()();
  TextColumn get cipher => text().withDefault(const Constant('aegis128l'))();
  IntColumn get fileModifiedAt => integer().nullable()();
  IntColumn get createdAt => integer().nullable()();
  IntColumn get finishedUploadAt => integer().nullable()();
  TextColumn get cachePolicy => textEnum<CachePolicyType>().withDefault(
    Constant(CachePolicyType.auto.name),
  )();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {accountId, id};
}

/// Files that have been downloaded and cached encrypted for offline access.
///
/// Files are re-encrypted with their per-file symmetric key before writing
/// to disk, so they can only be read by someone who can decrypt that key
/// (i.e. the account owner with their RSA private key). This provides
/// per-user isolation on shared devices and protection against filesystem
/// snooping by other apps.
class OfflineFiles extends Table {
  TextColumn get accountId => text()();
  TextColumn get fileId => text()();

  /// Path to the encrypted blob on disk.
  TextColumn get localPath => text()();

  /// Size of the encrypted file on disk (bytes). Used for cache size tracking.
  IntColumn get sizeOnDisk => integer().withDefault(const Constant(0))();

  /// Whether the user explicitly pinned this file for offline access.
  /// Pinned files are never auto-evicted; auto-cached files use LRU eviction.
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  DateTimeColumn get downloadedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Last time this cached file was accessed (read/decrypted). Used for
  /// LRU eviction of auto-cached (non-pinned) files.
  DateTimeColumn get lastAccessedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {accountId, fileId};
}

/// Pending uploads queued while offline.
///
/// [retryCount] and [nextRetryAt] implement exponential backoff so a
/// persistently-failing upload can't DDoS the server on reconnect.
/// See `SyncService.processPendingUploads` for the schedule.
class PendingUploads extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountId => text()();
  TextColumn get localPath => text()();
  TextColumn get targetDirId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Downloads handed to the OS transfer queue and not yet finished.
///
/// The OS keeps running these while the app is suspended, and keeps the ones
/// it already started even if the app is killed — but anything still waiting
/// its turn is lost with the process. This table is what lets the next launch
/// tell a transfer the user still wants from one that died with an old
/// session, and re-queue only the chunks that never landed.
///
/// Deliberately no URLs. A direct transfer runs on presigned links that stay
/// valid for days, and parking a pile of those on disk would leave working
/// credentials for the file's ciphertext lying around long after the transfer
/// they belonged to. The manifest is cheap to ask for again at resume, when
/// the app is awake and logged in anyway.
class PendingDownloads extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountId => text()();
  TextColumn get fileId => text()();

  /// How many chunks the finished file has, so resume can tell "all present"
  /// from "stopped partway" without asking the server.
  IntColumn get chunkCount => integer()();

  /// Where the chunks are being collected, so a resumed transfer writes into
  /// the same place rather than starting a second one alongside it.
  TextColumn get outputDir => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {accountId, fileId},
  ];
}

/// MCP server settings, one row per account (macOS only).
class McpSettings extends Table {
  TextColumn get accountId => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  IntColumn get port => integer().withDefault(const Constant(19548))();
  TextColumn get bearerToken => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// When true, read-only tools (list_files, list_notes, search_files,
  /// storage_stats) remain available while the app is PIN-locked. Crypto-
  /// requiring tools (read_file, write_file, rename, etc.) are always denied
  /// in the locked state regardless of this flag. Defaults to false — deny
  /// all agent access while locked.
  BoolColumn get allowReadOnlyWhileLocked =>
      boolean().withDefault(const Constant(false))();

  /// Token-bucket refill rate in requests/second.
  IntColumn get rateLimitRps => integer().withDefault(const Constant(5))();

  /// Token-bucket capacity (burst allowance).
  IntColumn get rateLimitBurst => integer().withDefault(const Constant(20))();

  /// How many days to keep audit-log entries. `0` means "forever". The
  /// cleanup pass in [AppDatabase.maybeRunMcpAuditRetention] respects this
  /// value on app foreground, deleting anything older than the window.
  IntColumn get auditRetentionDays =>
      integer().withDefault(const Constant(30))();

  /// Wall-clock time of the most recent retention pass. Null means "never".
  /// Used to debounce the cleanup so we only rescan once per 24 hours even
  /// if the user foregrounds the app repeatedly.
  DateTimeColumn get lastAuditCleanupAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {accountId};
}

/// One row per MCP tool invocation: what tool ran, when, for which account,
/// and whether it succeeded. Deliberately redacted — we store a SHA256 of
/// the JSON-RPC params so users can audit activity without the server-side
/// log itself leaking plaintext file names, content, or anything else that
/// would weaken the E2EE guarantee.
class McpAuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();

  /// SHA256 of the MCP session ID (never the session ID itself).
  TextColumn get sessionId => text()();
  TextColumn get accountId => text().nullable()();
  TextColumn get toolName => text()();

  /// SHA256 of the canonical JSON encoding of the tool params. Fixed width,
  /// no plaintext leakage. Empty string if params were absent.
  TextColumn get paramsHash => text()();

  /// 'ok' | 'error' | 'denied'. 'denied' is reserved for future authz checks.
  TextColumn get resultStatus => text()();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get durationMs => integer()();
}

/// Trust-on-first-use record of a peer's RSA public-key fingerprint, scoped
/// per owning account so switching accounts re-scopes the trust set. The first
/// time the caller sees a given [userId], the share flow records the
/// fingerprint here silently; on every later sighting it compares against this
/// row and only warns if the fingerprint changed. [ownerUserId] is the
/// caller's own server UUID; [userId] is the peer being trusted.
class TrustedFingerprints extends Table {
  TextColumn get ownerUserId => text()();
  TextColumn get userId => text()();

  /// The peer's `sha256(hex(modulus))` fingerprint, hex-encoded.
  TextColumn get fingerprint => text()();

  /// The peer's email as last seen at discovery or share time. Feeds the
  /// recipient-suggestion list; already server-visible metadata, so caching
  /// it locally adds no exposure. Null on rows recorded before the column
  /// existed, backfilled on the next successful lookup of that peer.
  TextColumn get email => text().nullable()();

  /// When the user explicitly confirmed the fingerprint out of band. Null for
  /// a row that was only ever recorded on first sight.
  DateTimeColumn get lastVerifiedAt => dateTime().nullable()();

  /// How the row got here: 'tofu' (recorded on first sight) or 'manual' (the
  /// user confirmed it out of band).
  TextColumn get verificationMethod =>
      text().withDefault(const Constant('tofu'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {ownerUserId, userId};
}

@DriftDatabase(
  tables: [
    Servers,
    Accounts,
    CachedFiles,
    OfflineFiles,
    PendingUploads,
    PendingDownloads,
    McpSettings,
    McpAuditLog,
    TrustedFingerprints,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Testing constructor — pass `NativeDatabase.memory()` for in-memory tests.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 20;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2 && to >= 2) {
        await m.addColumn(accounts, accounts.pinEncryptedPrivateKey);
      }
      if (from < 3 && to >= 3) {
        await m.addColumn(accounts, accounts.biometricPin);
      }
      if (from < 4 && to >= 4) {
        await m.addColumn(offlineFiles, offlineFiles.sizeOnDisk);
        await m.addColumn(offlineFiles, offlineFiles.pinned);
        await m.addColumn(offlineFiles, offlineFiles.lastAccessedAt);
      }
      // v5 created the subscriptions table and v11 extended it; both steps
      // were dropped along with the table when the app went free in v18 —
      // upgraders from < 5 simply never get the table, and the v18 step
      // below cleans it up on every database that still has it.
      if (from < 6 && to >= 6) {
        await m.addColumn(accounts, accounts.cacheLimitBytes);
      }
      if (from < 7 && to >= 7) {
        await m.addColumn(servers, servers.trustSelfSignedCerts);
      }
      if (from < 8 && to >= 8) {
        await m.addColumn(servers, servers.useHeaderAuth);
        await m.addColumn(accounts, accounts.headerJwt);
        await m.addColumn(accounts, accounts.headerRefreshToken);
      }
      if (from < 9 && to >= 9) {
        // v9 created the old singleton McpSettings table — v10 replaces it.
        await m.createTable(mcpSettings);
      }
      if (from < 10 && to >= 10) {
        // Recreate McpSettings with accountId as primary key (per-account).
        await m.deleteTable('mcp_settings');
        await m.createTable(mcpSettings);
      }
      if (from < 12 && to >= 12) {
        await m.addColumn(pendingUploads, pendingUploads.retryCount);
        await m.addColumn(pendingUploads, pendingUploads.nextRetryAt);
      }
      if (from < 13 && to >= 13) {
        await m.createTable(mcpAuditLog);
      }
      if (from < 14 && to >= 14) {
        await m.addColumn(mcpSettings, mcpSettings.allowReadOnlyWhileLocked);
        await m.addColumn(mcpSettings, mcpSettings.rateLimitRps);
        await m.addColumn(mcpSettings, mcpSettings.rateLimitBurst);
      }
      if (from < 15 && to >= 15) {
        await m.addColumn(mcpSettings, mcpSettings.auditRetentionDays);
        await m.addColumn(mcpSettings, mcpSettings.lastAuditCleanupAt);
      }
      if (from < 16 && to >= 16) {
        await m.createTable(trustedFingerprints);
      }
      if (from < 17 && to >= 17) {
        await m.addColumn(accounts, accounts.wrappingPublicKey);
      }
      if (from < 18 && to >= 18) {
        // The app went free — the IAP/trial cache is gone for good.
        await m.deleteTable('subscriptions');
      }
      if (from < 19 && to >= 19) {
        await m.addColumn(trustedFingerprints, trustedFingerprints.email);
      }
      if (from < 20 && to >= 20) {
        await m.createTable(pendingDownloads);
      }
    },
  );

  // ── Server operations ──────────────────────────────────────────────

  Future<List<Server>> getAllServers() => select(servers).get();

  Future<Server?> getServerByUrl(String url) =>
      (select(servers)..where((s) => s.url.equals(url))).getSingleOrNull();

  Future<Server> insertServer(ServersCompanion server) async {
    await into(servers).insert(server, mode: InsertMode.insertOrReplace);
    return (select(
      servers,
    )..where((s) => s.id.equals(server.id.value))).getSingle();
  }

  Future<void> updateServerUseHeaderAuth(String id, bool useHeaderAuth) async {
    await (update(servers)..where((s) => s.id.equals(id))).write(
      ServersCompanion(useHeaderAuth: Value(useHeaderAuth)),
    );
  }

  Future<void> deleteServer(String id) async {
    await (delete(accounts)..where((a) => a.serverId.equals(id))).go();
    await (delete(servers)..where((s) => s.id.equals(id))).go();
  }

  // ── Account operations ─────────────────────────────────────────────

  Future<List<Account>> getAllAccounts() => (select(
    accounts,
  )..orderBy([(a) => OrderingTerm.desc(a.lastUsedAt)])).get();

  Future<Account?> getActiveAccount() => (select(
    accounts,
  )..where((a) => a.isActive.equals(true))).getSingleOrNull();

  Future<Account?> getAccountById(String id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  /// Insert a new account or update an existing one.
  ///
  /// Uses INSERT OR IGNORE + UPDATE instead of INSERT OR REPLACE, because
  /// SQLite's REPLACE is a DELETE + INSERT that wipes columns not included
  /// in the companion (e.g. pinEncryptedPrivateKey, biometricPin).
  Future<Account> insertAccount(AccountsCompanion account) async {
    await into(accounts).insert(account, mode: InsertMode.insertOrIgnore);
    // Always update the mutable fields so a re-login refreshes the account.
    await (update(accounts)..where((a) => a.id.equals(account.id.value))).write(
      AccountsCompanion(
        serverId: account.serverId,
        userId: account.userId,
        email: account.email,
        fingerprint: account.fingerprint,
        publicKey: account.publicKey,
        wrappingPublicKey: account.wrappingPublicKey,
        encryptedPrivateKey: account.encryptedPrivateKey,
        quota: account.quota,
        role: account.role,
        isActive: account.isActive,
        lastUsedAt: account.lastUsedAt,
      ),
    );
    return (select(
      accounts,
    )..where((a) => a.id.equals(account.id.value))).getSingle();
  }

  /// Persist the migrated curve identity on the local account row — the same
  /// columns a fresh OPAQUE login stores. Quick unlock signs its nonce with the
  /// Ed25519 key but sends the fingerprint stored here, so a stale RSA value
  /// would fail signature verification on every unlock until a full re-login.
  Future<void> persistMigratedIdentity(
    String accountId, {
    required String fingerprint,
    required String publicKey,
    required String wrappingPublicKey,
    required String encryptedPrivateKey,
  }) async {
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(
        fingerprint: Value(fingerprint),
        publicKey: Value(publicKey),
        wrappingPublicKey: Value(wrappingPublicKey),
        encryptedPrivateKey: Value(encryptedPrivateKey),
      ),
    );
  }

  /// Keep the cached quota in step with what the server reports. The row
  /// is otherwise only written at login, so a plan change on the server
  /// would show a stale limit until the next full re-login.
  Future<void> updateAccountQuota(String accountId, int? quota) async {
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(quota: Value(quota)),
    );
  }

  Future<void> setActiveAccount(String accountId) async {
    await (update(accounts)..where((a) => a.isActive.equals(true))).write(
      const AccountsCompanion(isActive: Value(false)),
    );
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(
        isActive: const Value(true),
        lastUsedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteAccount(String id) async {
    final account = await getAccountById(id);
    await (delete(cachedFiles)..where((f) => f.accountId.equals(id))).go();
    await (delete(offlineFiles)..where((f) => f.accountId.equals(id))).go();
    await (delete(pendingUploads)..where((u) => u.accountId.equals(id))).go();
    await (delete(pendingDownloads)..where((d) => d.accountId.equals(id))).go();
    // The TOFU store is keyed by the server user UUID, not the local account
    // id, so purge it by the account's userId. A blank userId (account never
    // finished login) owns no trust rows, so skip the delete entirely.
    final ownerUserId = account?.userId;
    if (ownerUserId != null && ownerUserId.isNotEmpty) {
      await (delete(
        trustedFingerprints,
      )..where((t) => t.ownerUserId.equals(ownerUserId))).go();
    }
    await (delete(accounts)..where((a) => a.id.equals(id))).go();
  }

  // ── PIN encrypted key operations ────────────────────────────────────

  /// Store a PIN-encrypted private key for an account.
  Future<void> storePinEncryptedKey(
    String accountId,
    String encryptedKeyHex,
  ) async {
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(pinEncryptedPrivateKey: Value(encryptedKeyHex)),
    );
  }

  /// Clear the stored PIN-encrypted key for an account.
  Future<void> clearPinEncryptedKey(String accountId) async {
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      const AccountsCompanion(pinEncryptedPrivateKey: Value(null)),
    );
  }

  /// Get the PIN-encrypted private key for an account, or null if not set.
  Future<String?> getPinEncryptedKey(String accountId) async {
    final account = await getAccountById(accountId);
    return account?.pinEncryptedPrivateKey;
  }

  /// Get the account that has a PIN-encrypted key stored, preferring the
  /// active account, then the most recently used one.
  /// Used on app start to determine whether to show the unlock screen.
  Future<Account?> getAccountWithPinKey() async {
    return (select(accounts)
          ..where((a) => a.pinEncryptedPrivateKey.isNotNull())
          ..orderBy([
            (a) => OrderingTerm.desc(a.isActive),
            (a) => OrderingTerm.desc(a.lastUsedAt),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get a specific account by ID, only if it has a PIN-encrypted key.
  /// Used when switching accounts to verify the target has a PIN setup.
  Future<Account?> getAccountWithPinKeyById(String accountId) async {
    return (select(accounts)
          ..where((a) => a.id.equals(accountId))
          ..where((a) => a.pinEncryptedPrivateKey.isNotNull()))
        .getSingleOrNull();
  }

  // ── Biometric PIN operations ──────────────────────────────────────

  /// Store the user's PIN for biometric-gated quick unlock.
  Future<void> storeBiometricPin(String accountId, String pin) async {
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(biometricPin: Value(pin)),
    );
  }

  /// Clear the stored biometric PIN for an account.
  Future<void> clearBiometricPin(String accountId) async {
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      const AccountsCompanion(biometricPin: Value(null)),
    );
  }

  /// Get the biometric PIN for an account, or null if not set.
  Future<String?> getBiometricPin(String accountId) async {
    final account = await getAccountById(accountId);
    return account?.biometricPin;
  }

  // ── Cache limit operations ──────────────────────────────────────────

  /// Update the per-account offline cache size limit.
  /// Pass `null` to reset to the default, `0` for unlimited.
  Future<void> setCacheLimitBytes(String accountId, int? bytes) async {
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(cacheLimitBytes: Value(bytes)),
    );
  }

  // ── Header auth token operations ─────────────────────────────────────

  /// Persist JWT and refresh tokens for header-auth servers.
  Future<void> updateHeaderTokens(
    String accountId,
    String jwt,
    String refreshToken,
  ) async {
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(
        headerJwt: Value(jwt),
        headerRefreshToken: Value(refreshToken),
      ),
    );
  }

  /// Clear persisted header auth tokens (on logout).
  Future<void> clearHeaderTokens(String accountId) async {
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      const AccountsCompanion(
        headerJwt: Value(null),
        headerRefreshToken: Value(null),
      ),
    );
  }

  // ── Cached file metadata operations ──────────────────────────────────

  Future<List<CachedFile>> getFilesInDir(String accountId, String? dirId) {
    final query = select(cachedFiles)
      ..where((f) => f.accountId.equals(accountId));
    if (dirId != null) {
      query.where((f) => f.dirId.equals(dirId));
    } else {
      query.where((f) => f.dirId.isNull());
    }
    return query.get();
  }

  Future<CachedFile?> getCachedFileById(String accountId, String fileId) {
    return (select(cachedFiles)
          ..where((f) => f.accountId.equals(accountId))
          ..where((f) => f.id.equals(fileId)))
        .getSingleOrNull();
  }

  Future<void> upsertCachedFile(CachedFilesCompanion file) async {
    await into(cachedFiles).insert(file, mode: InsertMode.insertOrReplace);
  }

  /// Batch-upsert file metadata from a directory listing.
  Future<void> upsertCachedFiles(List<CachedFilesCompanion> files) async {
    await batch((b) {
      for (final file in files) {
        b.insert(cachedFiles, file, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> clearCacheForAccount(String accountId) async {
    await (delete(
      cachedFiles,
    )..where((f) => f.accountId.equals(accountId))).go();
    await (delete(
      offlineFiles,
    )..where((f) => f.accountId.equals(accountId))).go();
  }

  /// Delete cached files in a directory that are NOT in the given set of IDs.
  /// Used during sync to remove files that were deleted on the server.
  Future<void> removeStaleCachedFiles(
    String accountId,
    String? dirId,
    Set<String> keepIds,
  ) async {
    final existing = await getFilesInDir(accountId, dirId);
    final stale = existing.where((f) => !keepIds.contains(f.id)).toList();
    if (stale.isEmpty) return;
    await batch((b) {
      for (final f in stale) {
        b.deleteWhere(
          cachedFiles,
          (tbl) => tbl.accountId.equals(accountId) & tbl.id.equals(f.id),
        );
      }
    });
  }

  // ── Offline file operations ─────────────────────────────────────────

  /// Record an encrypted offline file on disk.
  Future<void> insertOfflineFile(OfflineFilesCompanion entry) async {
    await into(offlineFiles).insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Check if a file has an offline copy.
  Future<OfflineFile?> getOfflineFile(String accountId, String fileId) {
    return (select(offlineFiles)
          ..where((f) => f.accountId.equals(accountId))
          ..where((f) => f.fileId.equals(fileId)))
        .getSingleOrNull();
  }

  /// Get all offline files for an account.
  Future<List<OfflineFile>> getOfflineFilesForAccount(String accountId) {
    return (select(
      offlineFiles,
    )..where((f) => f.accountId.equals(accountId))).get();
  }

  /// Get all offline file IDs for an account (fast lookup set).
  Future<Set<String>> getOfflineFileIds(String accountId) async {
    final rows = await (select(
      offlineFiles,
    )..where((f) => f.accountId.equals(accountId))).get();
    return rows.map((r) => r.fileId).toSet();
  }

  /// Total bytes used by offline cache for an account.
  Future<int> getOfflineCacheSize(String accountId) async {
    final rows = await (select(
      offlineFiles,
    )..where((f) => f.accountId.equals(accountId))).get();
    return rows.fold<int>(0, (sum, r) => sum + r.sizeOnDisk);
  }

  /// Update the last-accessed timestamp (for LRU eviction).
  Future<void> touchOfflineFile(String accountId, String fileId) async {
    await (update(offlineFiles)
          ..where((f) => f.accountId.equals(accountId))
          ..where((f) => f.fileId.equals(fileId)))
        .write(OfflineFilesCompanion(lastAccessedAt: Value(DateTime.now())));
  }

  /// Set or clear the pinned flag on an offline file.
  Future<void> setOfflineFilePinned(
    String accountId,
    String fileId,
    bool pinned,
  ) async {
    await (update(offlineFiles)
          ..where((f) => f.accountId.equals(accountId))
          ..where((f) => f.fileId.equals(fileId)))
        .write(OfflineFilesCompanion(pinned: Value(pinned)));
  }

  /// Get auto-cached (non-pinned) files ordered by least recently accessed.
  /// Used for LRU eviction when the cache exceeds its size limit.
  Future<List<OfflineFile>> getEvictableFiles(String accountId) {
    return (select(offlineFiles)
          ..where((f) => f.accountId.equals(accountId))
          ..where((f) => f.pinned.equals(false))
          ..orderBy([(f) => OrderingTerm.asc(f.lastAccessedAt)]))
        .get();
  }

  /// Delete an offline file record.
  Future<void> deleteOfflineFile(String accountId, String fileId) async {
    await (delete(offlineFiles)
          ..where((f) => f.accountId.equals(accountId))
          ..where((f) => f.fileId.equals(fileId)))
        .go();
  }

  /// Delete all offline files for an account (records only — caller
  /// must also delete the actual files on disk).
  Future<void> deleteAllOfflineFiles(String accountId) async {
    await (delete(
      offlineFiles,
    )..where((f) => f.accountId.equals(accountId))).go();
  }

  // Pending upload CRUD and the retry-backoff helpers live in the
  // `PendingUploadsDao` extension in `pending_uploads_dao.dart`.

  // ── MCP settings operations ──────────────────────────────────────────

  /// Get MCP settings for a specific account.
  Future<McpSetting?> getMcpSettings(String accountId) async {
    return (select(
      mcpSettings,
    )..where((s) => s.accountId.equals(accountId))).getSingleOrNull();
  }

  /// Insert or update MCP settings for a specific account.
  Future<void> upsertMcpSettings(
    String accountId,
    McpSettingsCompanion data,
  ) async {
    final existing = await getMcpSettings(accountId);
    if (existing != null) {
      await (update(
        mcpSettings,
      )..where((s) => s.accountId.equals(accountId))).write(data);
    } else {
      await into(mcpSettings).insert(
        McpSettingsCompanion.insert(
          accountId: accountId,
          enabled: data.enabled,
          port: data.port,
          bearerToken: data.bearerToken,
          allowReadOnlyWhileLocked: data.allowReadOnlyWhileLocked,
          rateLimitRps: data.rateLimitRps,
          rateLimitBurst: data.rateLimitBurst,
          auditRetentionDays: data.auditRetentionDays,
          lastAuditCleanupAt: data.lastAuditCleanupAt,
        ),
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'hoodik.db'));
    // Load the at-rest key before the first query so the column converters
    // have it in hand; a keychain failure leaves values in plaintext rather
    // than blocking the database from opening.
    await AtRestCipher.instance.ensureInitialized();
    return NativeDatabase.createInBackground(file);
  });
}
