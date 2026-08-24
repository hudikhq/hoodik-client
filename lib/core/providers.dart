import 'dart:async';
import 'dart:typed_data';

import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;

import 'package:drift/drift.dart' as drift show Value;
import 'package:dio/dio.dart' show DioException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'storage/database.dart';
import 'auth/auth_service.dart';
import 'auth/secure_pin_storage.dart';
import 'api/api_client.dart';
import 'crypto/crypto_service.dart';
import 'crypto/file_crypto.dart';
import 'crypto/share_crypto.dart';
import 'api/shares_models.dart';
import '../features/shares/services/folder_membership.dart';
import '../features/shares/services/trusted_fingerprint_dao.dart';
import 'mcp/mcp_audit_retention.dart';
import 'mcp/mcp_server.dart';
import 'storage/mcp_audit_dao.dart';
import 'services/background_tar_transfer.dart';
import 'services/background_upload_service.dart';
import 'services/binary_upload_transport.dart';
import 'services/chunk_download_transport.dart';
import 'services/direct_chunk_download.dart';
import 'services/direct_chunk_upload.dart';
import 'services/file_downloader_config.dart';
import 'services/file_downloader.dart';
import 'services/file_mutator.dart';
import 'services/file_operations.dart';
import 'services/file_uploader.dart';
import 'services/shared_folder_target.dart';
import 'services/shared_folder_upload.dart';
import 'services/connectivity_service.dart';
import 'services/media_picker_channel.dart';
import 'services/offline_manager.dart';
import 'services/preferences.dart';
import 'services/app_update.dart';
import 'services/latest_release.dart';
import 'services/server_version.dart';
import 'services/sync_service.dart';
import 'services/tar_fallback.dart';
import 'services/transfer_manager.dart';
import 'workers/worker_manager.dart';
import '../features/preview/providers/preview_providers.dart';
import '../features/preview/providers/preview_cache.dart';
import '../features/account/services/mcp_token_crypto.dart';

/// Singleton database instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Singleton crypto service.
final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return const CryptoService();
});

/// Singleton secure PIN storage (iOS Keychain / Android Keystore).
final securePinStorageProvider = Provider<SecurePinStorage>((ref) {
  return SecurePinStorage();
});

/// Auth service — manages login, accounts, cookies.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(databaseProvider),
    ref.watch(securePinStorageProvider),
  );
});

/// Whether the user is currently authenticated.
final isLoggedInProvider = StateProvider<bool>((ref) => false);

/// Whether the app is visually locked behind a PIN overlay.
/// Set to true on app resume when a PIN is configured; cleared on unlock.
final isLockedProvider = StateProvider<bool>((ref) => false);

/// The currently active API client (null if not logged in).
///
/// Watches [isLoggedInProvider] so that when login state changes the provider
/// re-evaluates and picks up the new (or cleared) client from [AuthService].
final apiClientProvider = Provider<ApiClient?>((ref) {
  // This watch ensures the provider rebuilds when login state changes.
  final loggedIn = ref.watch(isLoggedInProvider);
  if (!loggedIn) return null;
  return ref.watch(authServiceProvider).activeClient;
});

/// The currently active account info.
final activeAccountProvider = StateProvider<Account?>((ref) => null);

/// The currently active server info.
final activeServerProvider = StateProvider<Server?>((ref) => null);

/// The active account's **server-assigned** user UUID — the identity the
/// server signs and wraps against, stored in the account row's `userId`
/// column at login. Distinct from [Account.id], which is the local composite
/// `${server.id}_${email}`. Null when logged out or before login persisted a
/// UUID. The sharing sign/wrap/audit paths must read this, never `account.id`.
final activeServerUserIdProvider = Provider<String?>((ref) {
  final userId = ref.watch(activeAccountProvider)?.userId;
  return (userId == null || userId.isEmpty) ? null : userId;
});

/// The decrypted PEM private key for the active session (held in memory only).
/// For curve accounts this is the Ed25519 identity private key (used for signing).
final decryptedPrivateKeyProvider = StateProvider<String?>((ref) => null);

/// For curve accounts, the hybrid wrapping private key used to unwrap the account's own
/// file key wraps (encrypted_key). Null for legacy RSA accounts.
final decryptedWrappingPrivateKeyProvider = StateProvider<String?>(
  (ref) => null,
);

/// [FileCrypto] instance for the active session, or null if no private key
/// is available.
final fileCryptoProvider = Provider<FileCrypto?>((ref) {
  final pem = ref.watch(decryptedPrivateKeyProvider);
  if (pem == null) return null;
  return FileCrypto(
    privateKeyPem: pem,
    wrappingPrivateKeyPem: ref.watch(decryptedWrappingPrivateKeyProvider),
    crypto: ref.watch(cryptoServiceProvider),
  );
});

/// Unwrapped file keys for every file shared with this account.
///
/// Search tags a shared file under that file's own key, so a query has to
/// carry one tag set per such file. Held for the session because it costs an
/// asymmetric unwrap per file and only changes when a share is granted or
/// revoked; it rebuilds automatically when the private key does, so logging
/// out drops it with the key that unwrapped it.
final incomingSearchKeysProvider = FutureProvider<List<Uint8List>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final fileCrypto = ref.watch(fileCryptoProvider);
  if (client == null || fileCrypto == null) return const [];

  try {
    final rows = await client.shares.getIncomingKeys();

    return rows
        .map((row) {
          try {
            return fileCrypto.decryptFileKey(row['encrypted_key']!);
          } catch (_) {
            // A row wrapped under a superseded key is not worth failing the
            // whole search over; it simply will not match.
            return null;
          }
        })
        .whereType<Uint8List>()
        .toList();
  } catch (_) {
    // Search over owned files is the common case and must not break because
    // the shares list is unavailable.
    return const [];
  }
});

/// [ShareCrypto] instance for the active session, or null if no private key
/// is available. Auto-wipes on logout via [decryptedPrivateKeyProvider].
final shareCryptoProvider = Provider<ShareCrypto?>((ref) {
  final pem = ref.watch(decryptedPrivateKeyProvider);
  if (pem == null) return null;
  return ShareCrypto(
    privateKeyPem: pem,
    wrappingPrivateKeyPem: ref.watch(decryptedWrappingPrivateKeyProvider),
    crypto: ref.watch(cryptoServiceProvider),
  );
});

/// Singleton transfer manager for tracking upload/download progress.
final transferManagerProvider = ChangeNotifierProvider<TransferManager>((ref) {
  return TransferManager();
});

/// Native Photos picker with per-item load progress (iOS only — see
/// [MediaPickerChannel.isSupported]). A provider so tests can script the
/// event stream.
final mediaPickerChannelProvider = Provider<MediaPickerChannel>((ref) {
  return MediaPickerChannel();
});

/// Memoizes whether each server base URL supports `?format=tar` so the
/// upload/download pipelines only probe the tar endpoint once per session.
/// Cleared on logout via [AuthStateExtension.setLoggedOut].
final tarCapabilityCacheProvider = Provider<TarCapabilityCache>((ref) {
  return TarCapabilityCache();
});

/// Snapshot of the last `/api/liveness` probe for the active server.
/// Refreshes whenever the active ApiClient changes (login, logout, server
/// switch) so the outdated-server warning follows the user across accounts.
/// Loading and error states collapse into [LivenessInfo.offline] rather
/// than bubble up — a transient probe failure isn't worth blocking the UI.
final serverLivenessProvider = FutureProvider<LivenessInfo>((ref) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) return const LivenessInfo.offline();
  return client.auth.checkLiveness();
});

/// The active server's capability advertisement. Re-evaluates whenever the
/// active ApiClient changes (login, logout, server switch). A null client or
/// any probe failure collapses to [Capabilities.disabled], so every surface
/// gated on this stays hidden against a server that doesn't speak the
/// protocol instead of surfacing an error.
///
/// A request that never reached the server is retried, because this provider
/// outlives the session: one probe lost to a phone changing networks at
/// launch would otherwise hide sharing and pin every chunk to the relaying
/// routes until the next login, with nothing to show for it.
final shareCapabilitiesProvider = FutureProvider<Capabilities>((ref) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) return const Capabilities.disabled();

  try {
    return await client.shares.getCapabilities();
  } catch (e) {
    if (e is DioException && e.response == null) {
      Future.delayed(const Duration(seconds: 15), ref.invalidateSelf);
    }

    return const Capabilities.disabled();
  }
});

/// Server base URLs for which the user dismissed the outdated-server
/// banner in this session. Reset on logout via [AuthStateExtension].
/// Intentionally not persisted to disk: operators upgrade their servers,
/// and we want the banner to come back on the next session if they haven't.
final dismissedOutdatedServerBannersProvider = StateProvider<Set<String>>((
  ref,
) {
  return <String>{};
});

/// Fetcher for the latest published hoodik server release. Overridden in
/// tests to return a canned [LatestRelease] without hitting the network.
final latestReleaseFetcherProvider = Provider<LatestReleaseFetcher>((ref) {
  return LatestReleaseFetcher();
});

/// Latest hoodik server version published on github.com/hudikhq/hoodik,
/// or `null` when GitHub is unreachable / the response can't be parsed.
///
/// Cached for the lifetime of the provider via [KeepAliveLink] — one
/// request per app session is plenty given how rarely releases ship,
/// and avoids hammering GitHub's unauthenticated rate limit (60/h/IP).
///
/// Consumers MUST treat a `null` value as "we don't know" — never as
/// implicit permission to warn the user. The outdated-server banner
/// hides itself when this is null and the server reports a version.
final latestServerReleaseProvider = FutureProvider<String?>((ref) async {
  final fetcher = ref.watch(latestReleaseFetcherProvider);
  final release = await fetcher.fetch();
  if (release != null) ref.keepAlive();
  return release?.version;
});

/// Fetcher for the latest App Store version of the Hoodik app. Overridden in
/// tests to return a canned value without hitting itunes.apple.com.
final appStoreVersionFetcherProvider = Provider<AppStoreVersionFetcher>((ref) {
  return AppStoreVersionFetcher();
});

/// Latest Hoodik version published on the App Store, or `null` when Apple's
/// lookup is unreachable / unparsable. Only queried on iOS and macOS — Android
/// learns about updates from Play directly via the in-app update flow, so this
/// stays null there and keeps the update banner Apple-only. Cached for the
/// session like [latestServerReleaseProvider]; a `null` value means "we don't
/// know" and never justifies a nudge.
final latestAppStoreVersionProvider = FutureProvider<AppStoreVersion?>((
  ref,
) async {
  if (!Platform.isIOS && !Platform.isMacOS) return null;
  final fetcher = ref.watch(appStoreVersionFetcherProvider);
  final version = await fetcher.fetch();
  if (version != null) ref.keepAlive();
  return version;
});

/// The running app's version name (e.g. `"2.0.1"`), read once from the
/// platform bundle. `null` if the platform channel is unavailable.
final currentAppVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return null;
  }
});

/// Whether the user dismissed the app-update banner this session. Not
/// persisted — a new session re-surfaces it if they still haven't updated.
final dismissedAppUpdateBannerProvider = StateProvider<bool>((ref) => false);

/// Worker manager for offloading crypto + I/O to isolates.
/// Null if not logged in (no API client).
///
/// Call `init()` explicitly after login to spawn the isolates.
/// Isolates are automatically killed when the provider is disposed
/// (e.g. on logout when apiClientProvider becomes null).
///
/// Uses `ref.read` for [transferManagerProvider] to avoid rebuilding (and
/// killing isolates!) every time the TransferManager notifies listeners
/// during progress updates. We only need the object reference, not reactivity.
final workerManagerProvider = Provider<WorkerManager?>((ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  final wm = WorkerManager(
    transferManager: ref.read(transferManagerProvider),
    apiClient: client,
  );
  ref.onDispose(() => wm.dispose());
  return wm;
});

/// OS-native background upload service. Dispatches encrypted chunks as
/// individual [UploadTask]s so uploads survive app suspension on mobile.
///
/// Null until there is both an API client and an account — the account
/// stamps every task id, which is what lets a later sign-in tell this
/// account's transfers from another's.
final backgroundUploadServiceProvider = Provider<BackgroundUploadService?>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  final account = ref.watch(activeAccountProvider);
  if (client == null || account == null) return null;

  final bus = BackgroundUploadService(
    baseUrl: client.baseUrl,
    accountId: account.id,
  );
  bus.setTransferManager(ref.read(transferManagerProvider));
  ref.onDispose(() => bus.dispose());
  return bus;
});

/// Shared tar transport — runs the bulk tar HTTP leg of both downloads and
/// uploads through `background_downloader` so the OS (URLSession /
/// WorkManager) can keep moving bytes while the app is suspended. The
/// Rust FFI handles only the local pack/unpack work.
final backgroundTarTransferProvider = Provider<BackgroundTarTransfer?>((ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;

  final service = BackgroundTarTransfer(baseUrl: client.baseUrl);
  ref.onDispose(() {
    () async {
      await service.dispose();
    }();
  });
  return service;
});

/// Reconciles the OS transfer queue with the account that just signed in.
///
/// A provider rather than a direct call so tests can override it away — it
/// reaches into `background_downloader`, which spins up real platform work
/// the moment it is touched. Same reason [mcpServerProvider] is overridden
/// to null in widget tests.
final transferReconcilerProvider =
    Provider<Future<void> Function(String accountId)?>((ref) {
      final db = ref.watch(databaseProvider);
      return (accountId) async {
        final unfinished = await reconcileTransfersForAccount(
          db: db,
          accountId: accountId,
        );
        if (unfinished.isEmpty) return;

        // Read rather than watch, and inside the closure: this runs after
        // sign-in has returned, and evaluating the downloader during the
        // sign-in writes would drag the whole file-operations graph into a
        // half-published session.
        await ref
            .read(fileDownloaderProvider)
            ?.resumeInterruptedDownloads(unfinished);
      };
    });

/// Direct-transfer write leg: one OS-native task per encrypted chunk, straight
/// at the bucket. Same reasoning as the read side — a presigned URL needs
/// nothing from the session, so this holds nothing that could leak into one.
final directChunkUploadProvider = Provider<DirectChunkUploadService>((ref) {
  final service = DirectChunkUploadService();
  ref.onDispose(service.dispose);
  return service;
});

/// Direct-transfer leg: one OS-native task per encrypted chunk, straight at
/// the bucket. Independent of [apiClientProvider] because a presigned URL
/// needs nothing from the session — and a leg that never sees a cookie cannot
/// send one to object storage.
final directChunkDownloadProvider = Provider<DirectChunkDownloadService>((ref) {
  final service = DirectChunkDownloadService();
  ref.onDispose(service.dispose);
  return service;
});

/// Chunk-download transport used by [ChunkDownloadPipeline]. Wraps
/// [BackgroundTarTransfer] for the tar leg and [DirectChunkDownloadService]
/// for presigned chunks, so both survive app suspension; the per-chunk
/// fallback still goes through the Rust HTTP pipeline.
final chunkDownloadTransportProvider = Provider<ChunkDownloadTransport?>((ref) {
  final tarTransfer = ref.watch(backgroundTarTransferProvider);
  if (tarTransfer == null) return null;
  return BackgroundDownloaderChunkTransport(
    tarTransfer: tarTransfer,
    directChunks: ref.watch(directChunkDownloadProvider),
  );
});

/// Upload-tar transport used by [BinaryUploadPipeline]. Wraps
/// [BackgroundTarTransfer] so the tar leg is backgroundable; the per-chunk
/// fallback still uses [BackgroundUploadService].
final uploadTarTransportProvider = Provider<UploadTarTransport?>((ref) {
  final tarTransfer = ref.watch(backgroundTarTransferProvider);
  if (tarTransfer == null) return null;
  return BackgroundDownloaderUploadTarTransport(tarTransfer: tarTransfer);
});

/// Preview context — set by FilesScreen before navigating to /preview/:fileId.
final previewContextProvider = StateProvider<PreviewContext?>((ref) => null);

/// Note-editor font scale. `1.0` is the default; shared across all open
/// tabs and across navigations within a session. Not persisted to disk
/// (resets on app restart) — if we need persistence later we can add a
/// dedicated row in the preferences table.
final editorZoomProvider = StateProvider<double>((ref) => 1.0);

/// Whether the notes editor's desktop sidebar is collapsed. Expanded by
/// default; the user toggles it via a button in the sidebar header or tab
/// bar. Session-scoped (same lifecycle as [editorZoomProvider]).
final notesSidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// How the files screen renders its listing.
///
/// - [list]: one row per item with name, size, date (the historical view).
/// - [icons]: grid of large icons/thumbnails, better for visual scanning.
/// - [tree]: recursive expandable tree rooted at the current directory,
///   so users can see nested structure without navigating.
enum FilesViewMode { list, icons, tree }

/// Populated once in `main.dart` after `SharedPreferences` is loaded.
/// Read synchronously from any provider below via `ref.read`.
final preferencesProvider = Provider<Preferences>(
  (ref) => throw StateError('Preferences must be overridden in ProviderScope'),
);

/// Persisted view-mode preference for the files screen. Reads the
/// stored value on first access and writes back through [Preferences]
/// on every change, so the user's choice sticks across restarts.
class FilesViewModeNotifier extends Notifier<FilesViewMode> {
  @override
  FilesViewMode build() => ref.read(preferencesProvider).filesViewMode;

  Future<void> set(FilesViewMode mode) async {
    if (state == mode) return;
    state = mode;
    await ref.read(preferencesProvider).setFilesViewMode(mode);
  }
}

final filesViewModeProvider =
    NotifierProvider<FilesViewModeNotifier, FilesViewMode>(
      FilesViewModeNotifier.new,
    );

/// Persisted default landing branch. Picks the tab that's active at
/// cold start once the user is logged in. Editable from Account
/// settings.
class LandingBranchNotifier extends Notifier<LandingBranch> {
  @override
  LandingBranch build() => ref.read(preferencesProvider).landingBranch;

  Future<void> set(LandingBranch branch) async {
    if (state == branch) return;
    state = branch;
    await ref.read(preferencesProvider).setLandingBranch(branch);
  }
}

final landingBranchProvider =
    NotifierProvider<LandingBranchNotifier, LandingBranch>(
      LandingBranchNotifier.new,
    );

/// Persisted appearance preference. [ThemeMode.system] follows the OS;
/// the other two pin the app regardless of what the device is doing.
class AppThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(preferencesProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await ref.read(preferencesProvider).setThemeMode(mode);
  }
}

final appThemeModeProvider = NotifierProvider<AppThemeModeNotifier, ThemeMode>(
  AppThemeModeNotifier.new,
);

/// Persisted app display language. `null` follows the device locale;
/// otherwise one of the codes in [AppLocaleNotifier.supported].
class AppLocaleNotifier extends Notifier<Locale?> {
  static const supported = ['en', 'fr', 'de', 'hr'];

  @override
  Locale? build() {
    final code = ref.read(preferencesProvider).appLocale;
    return code == null ? null : Locale(code);
  }

  Future<void> set(Locale? locale) async {
    if (state?.languageCode == locale?.languageCode) return;
    state = locale;
    await ref.read(preferencesProvider).setAppLocale(locale?.languageCode);

    // Mirror the preference server-side so outbound email (activation,
    // share notifications) follows the user's language. Best-effort: a
    // logged-out session or an offline change just keeps the old value.
    if (locale != null && ref.read(isLoggedInProvider)) {
      try {
        await ref
            .read(apiClientProvider)
            ?.shares
            .patchMe(locale: locale.languageCode);
      } catch (_) {}
    }
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale?>(
  AppLocaleNotifier.new,
);

/// Optional per-branch titles that contribute to the window title. Each
/// branch can publish what it's currently "showing" — a folder name, a
/// note filename — and the shell picks the one for the active tab.
/// `null` falls back to the tab's own label (e.g. "Files", "Notes").
final filesBranchTitleProvider = StateProvider<String?>((ref) => null);
final notesBranchTitleProvider = StateProvider<String?>((ref) => null);

/// Bottom-nav branch indices, in bottom-nav order (see MainShell).
const int filesBranchIndex = 0;
const int notesBranchIndex = 1;
const int searchBranchIndex = 2;

/// A "switch the shell to this branch" signal for widgets deep inside a
/// branch. MainShell listens and calls `goBranch`, which restores the
/// target branch's own navigation stack — a cross-branch `context.go`
/// would instead navigate that branch to a fixed location, losing the
/// folder the user was in. Reset to null after handling.
final shellBranchRequestProvider = StateProvider<int?>((ref) => null);

/// Account-level storage usage from `POST /api/storage/stats`, refreshed
/// each time a listener mounts (the Account screen). The listing endpoint
/// does not carry usage figures, so this is the one place they come from.
///
/// Side effect: when the reported quota disagrees with the cached Account
/// row — a plan change on a Hoodik Cloud instance, an admin edit — the row
/// and the in-memory account are updated so every quota consumer sees the
/// fresh limit without a re-login. Errors (including servers without the
/// stats route) resolve to null and leave the cached quota rendering.
final storageUsageProvider = FutureProvider.autoDispose<StorageUsage?>((
  ref,
) async {
  final client = ref.watch(apiClientProvider);
  final account = ref.watch(activeAccountProvider);
  if (client == null || account == null) return null;
  try {
    final usage = StorageUsage.fromJson(await client.storage.getStats());
    if (usage.quota != account.quota) {
      await ref
          .read(databaseProvider)
          .updateAccountQuota(account.id, usage.quota);
      ref.read(activeAccountProvider.notifier).state = account.copyWith(
        quota: drift.Value(usage.quota),
      );
    }
    return usage;
  } catch (_) {
    return null;
  }
});

/// Session-scoped preview cache. Keeps decrypted file bytes in memory so
/// re-opening a preview is instant. Cleared on logout.
final previewCacheProvider = Provider<PreviewCache>((ref) {
  final cache = PreviewCache();
  ref.onDispose(() => cache.dispose());
  return cache;
});

/// Manages encrypted offline file storage. Files are re-encrypted on disk
/// with their per-file key so only the account owner can read them.
///
/// All downloaded files are cached indefinitely. Users can clear the cache
/// manually from Account Settings.
final offlineManagerProvider = ChangeNotifierProvider<OfflineManager>((ref) {
  return OfflineManager(ref.watch(databaseProvider));
});

/// Singleton connectivity monitor.
final connectivityProvider = ChangeNotifierProvider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Sync service — directory cache fallback + pending upload queue.
///
/// Auto-activates when an account is logged in, deactivates on logout.
final syncServiceProvider = ChangeNotifierProvider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final connectivity = ref.watch(connectivityProvider);
  final service = SyncService(db: db, connectivity: connectivity);
  // No ref.onDispose needed — ChangeNotifierProvider calls dispose() automatically.

  final account = ref.watch(activeAccountProvider);
  final client = ref.watch(apiClientProvider);
  final ops = ref.watch(fileOperationsProvider);

  if (account != null && client != null) {
    service.activate(
      accountId: account.id,
      apiClient: client,
      fileOperations: ops,
    );
  } else {
    service.deactivate();
  }

  // Cancels must outlive the transfer that observes them: the tap itself
  // drops the queue row and the server-side partial, whatever the in-flight
  // upload manages to notice before a kill. The upload-phase row's fileId is
  // the server id; the encrypt phase has no server file yet.
  ref.read(transferManagerProvider).onCancelPersist = (item) {
    unawaited(
      service.cancelUploadArtifacts(
        stagingGroup: item.groupId,
        serverFileId: item.type == TransferType.uploadHttp ? item.fileId : null,
      ),
    );
  };

  return service;
});

/// Count of uploads that have exhausted their retry budget for the active
/// account. Re-resolves whenever [SyncService] notifies, so the count stays
/// in sync with retries, discards, and reconnect-driven queue updates.
final permanentlyFailedCountProvider = FutureProvider<int>((ref) async {
  final sync = ref.watch(syncServiceProvider);
  final failed = await sync.permanentlyFailedUploads();
  return failed.length;
});

/// Open-request channel for the transfer overlay. A non-null value asks
/// the overlay to restore itself and expand (so a dismissed or hidden
/// overlay becomes visible again after the user taps an external entry
/// point). The overlay consumes the request and resets this back to null.
class TransferOverlayRequest {
  const TransferOverlayRequest({this.scrollToFailed = false});

  final bool scrollToFailed;
}

final transferOverlayRequestProvider = StateProvider<TransferOverlayRequest?>(
  (ref) => null,
);

/// [FileOperations] service for the active session, or null if prerequisites
/// are missing (no API client, no private key, no public key).
///
/// Uses `ref.read` for [transferManagerProvider], [workerManagerProvider], and
/// [offlineManagerProvider] to avoid rebuilding on every ChangeNotifier update.
/// These are long-lived singleton-like objects — we only need the reference.
/// The provider still rebuilds correctly on login/logout/account-switch via
/// [apiClientProvider], [decryptedPrivateKeyProvider], and
/// [activeAccountProvider].
/// The shared tar cache, pre-answered when the server has already said it
/// will not serve archives.
///
/// The runner consults this cache before it probes, so seeding it here means
/// a download on such a server goes straight to per-chunk rather than
/// spending a refused request to learn what the capability already said. The
/// probe-and-fall-back path stays exactly as it was for servers that do not
/// advertise either way, and for an operator who flips the switch while a
/// transfer is already running.
TarCapabilityCache _tarCacheFor(Ref ref, String baseUrl, Capabilities? caps) {
  final cache = ref.read(tarCapabilityCacheProvider);
  if (caps != null && !caps.tarTransfer) cache.markUnsupported(baseUrl);
  return cache;
}

final fileOperationsProvider = Provider<FileOperations?>((ref) {
  final client = ref.watch(apiClientProvider);
  final pk = ref.watch(decryptedPrivateKeyProvider);
  final account = ref.watch(activeAccountProvider);
  if (client == null || pk == null || account == null) return null;
  final publicKey = account.publicKey;
  if (publicKey == null) return null;
  final tm = ref.read(transferManagerProvider);
  final wm = ref.read(workerManagerProvider);

  final bus = ref.read(backgroundUploadServiceProvider);
  final tarTransfer = ref.read(backgroundTarTransferProvider);
  final chunkTransport = ref.read(chunkDownloadTransportProvider);
  final uploadTarTransport = ref.read(uploadTarTransportProvider);

  // Multi-key routing for uploads into shared folders. Gated on the sharing
  // kill-switch — the same `sharing.enabled` flag the rest of the UI uses — so
  // a server with sharing off, or an older server that doesn't support it,
  // never routes through multi-key and pays nothing. The upload orchestration
  // is null until the session has the crypto to wrap a roster.
  final capabilities = ref.watch(shareCapabilitiesProvider).valueOrNull;
  final sharedTarget = SharedFolderTargetResolver(
    files: client.files,
    sharingEnabled: capabilities?.sharingEnabled ?? false,
  );
  final sharedUpload = ref.watch(sharedFolderUploadProvider);

  final ops = FileOperations(
    client: client,
    privateKeyPem: pk,
    publicKeyPem: publicKey,
    wrappingPrivateKeyPem: ref.watch(decryptedWrappingPrivateKeyProvider),
    wrappingPublicKeyPem: account.wrappingPublicKey,
    crypto: ref.watch(cryptoServiceProvider),
    // Null while the capability probe is still in flight (or offline);
    // the historical default keeps uploads working either way.
    defaultCipher: capabilities?.defaultCipher ?? 'aegis128l',
    transferManager: tm,
    workerManager: wm,
    offlineManager: ref.read(offlineManagerProvider),
    backgroundUploadService: bus,
    // Withheld unless the server says it serves bucket URLs, the same way the
    // web client reads the advertisement. Asking anyway and taking the 400 as
    // the answer works — every path falls back to relaying — but it spends a
    // dead request per upload on every local-disk deployment, which is the
    // default one. The fallback stays regardless: an operator can switch the
    // feature off while a transfer is already in flight.
    directUpload: capabilities?.directTransfer == true
        ? ref.read(directChunkUploadProvider)
        : null,
    directTransfer: capabilities?.directTransfer == true,
    tarCapabilityCache: _tarCacheFor(ref, client.baseUrl, capabilities),
    // Uploads deliberately re-probe rather than cache, so they read the
    // advertisement directly instead of the cache the download side seeds.
    tarSupported: capabilities?.tarTransfer ?? true,
    chunkDownloadTransport: chunkTransport,
    uploadTarTransport: uploadTarTransport,
    database: ref.read(databaseProvider),
    accountId: account.id,
    sharedTarget: sharedTarget,
    sharedUpload: sharedUpload,
  );

  // Wire cancel: UI → TransferManager → WorkerManager + BackgroundUploadService + BackgroundTarTransfer + the two direct-chunk services + FileOperations
  final directChunks = ref.read(directChunkDownloadProvider);
  final directUploads = ref.read(directChunkUploadProvider);
  tm.onCancelRequested = (fileId) {
    wm?.cancelEncryption(fileId);
    bus?.cancelUpload(fileId);
    tarTransfer?.cancel(fileId);
    directChunks.cancel(fileId);
    directUploads.cancel(fileId);
    ops.requestCancel(fileId);
  };

  return ops;
});

/// Narrow view of [fileOperationsProvider] for callers that only need the
/// metadata-mutation surface (createFolder, rename, delete, move). Shares
/// the same lifecycle as the parent — becomes null when the session is
/// gone.
final fileMutatorProvider = Provider<FileMutator?>((ref) {
  return ref.watch(fileOperationsProvider)?.mutator;
});

/// Narrow view of [fileOperationsProvider] for upload callers
/// (uploadFile, createNote, updateNoteContent).
final fileUploaderProvider = Provider<FileUploader?>((ref) {
  return ref.watch(fileOperationsProvider)?.uploader;
});

/// Narrow view of [fileOperationsProvider] for download callers
/// (downloadFile, downloadFileToDisk, downloadAndPinOffline).
final fileDownloaderProvider = Provider<FileDownloader?>((ref) {
  return ref.watch(fileOperationsProvider)?.downloader;
});

/// Whether the MCP server feature is available on this platform.
final mcpAvailableProvider = Provider<bool>((ref) => Platform.isMacOS);

/// MCP server settings for the active account.
/// Re-read on demand; write via [AppDatabase.upsertMcpSettings].
final mcpSettingsProvider = FutureProvider<McpSetting?>((ref) {
  final db = ref.watch(databaseProvider);
  final account = ref.watch(activeAccountProvider);
  if (account == null) return Future.value(null);
  return db.getMcpSettings(account.id);
});

/// The active account's trust-on-first-use set, keyed by the caller's server
/// UUID so it re-scopes when the active account switches. Empty before login
/// resolves a UUID. Single-peer lookups and first-sight writes go straight to
/// the [TrustedFingerprintDao] on [databaseProvider] with the same owner UUID;
/// this is the read-side mirror of [mcpSettingsProvider].
final trustedFingerprintsProvider = FutureProvider<List<TrustedFingerprint>>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  final ownerUserId = ref.watch(activeServerUserIdProvider);
  if (ownerUserId == null) return Future.value(const []);
  return db.getTrustedFingerprintsForOwner(ownerUserId);
});

/// Folder-membership crypto orchestration for the active session, or null when
/// no private key or server UUID is available. Verifies the signed roster
/// before an upload key is wrapped, reconciles fingerprints against the
/// trust-on-first-use store, and signs post-mutation member sets. Auto-wipes on
/// logout via [shareCryptoProvider] and [activeServerUserIdProvider].
final folderMembershipProvider = Provider<FolderMembership?>((ref) {
  final crypto = ref.watch(shareCryptoProvider);
  final ownerUserId = ref.watch(activeServerUserIdProvider);
  if (crypto == null || ownerUserId == null) return null;
  return FolderMembership(
    crypto: crypto,
    db: ref.watch(databaseProvider),
    ownerUserId: ownerUserId,
  );
});

/// Multi-key upload orchestration for the active session, or null when sharing
/// crypto isn't available (no client, no private key, or no server UUID yet).
/// Verifies a destination folder's signed roster, wraps the file key for every
/// member, and signs the upload audit event. Auto-wipes on logout via the
/// providers it derives from.
final sharedFolderUploadProvider = Provider<SharedFolderUpload?>((ref) {
  final client = ref.watch(apiClientProvider);
  final membership = ref.watch(folderMembershipProvider);
  final crypto = ref.watch(shareCryptoProvider);
  final callerUserId = ref.watch(activeServerUserIdProvider);
  if (client == null ||
      membership == null ||
      crypto == null ||
      callerUserId == null) {
    return null;
  }
  return SharedFolderUpload(
    client: client.shares,
    folderMembership: membership,
    shareCrypto: crypto,
    callerUserId: callerUserId,
  );
});

/// Filter criteria for the MCP audit log screen. Empty strings mean "all".
class McpAuditFilter {
  final String? toolName;
  final String? resultStatus;

  const McpAuditFilter({this.toolName, this.resultStatus});

  McpAuditFilter copyWith({String? toolName, String? resultStatus}) {
    return McpAuditFilter(
      toolName: toolName ?? this.toolName,
      resultStatus: resultStatus ?? this.resultStatus,
    );
  }

  McpAuditFilter clearToolName() =>
      McpAuditFilter(toolName: null, resultStatus: resultStatus);
  McpAuditFilter clearResultStatus() =>
      McpAuditFilter(toolName: toolName, resultStatus: null);
}

/// Filter state driving the audit log screen's query parameters.
final mcpAuditFilterProvider = StateProvider<McpAuditFilter>(
  (ref) => const McpAuditFilter(),
);

/// Streams audit-log entries matching [mcpAuditFilterProvider]. The settings
/// screen tails this stream so new entries appear without a manual refresh.
final mcpAuditLogProvider = StreamProvider<List<McpAuditLogData>>((ref) {
  final db = ref.watch(databaseProvider);
  final filter = ref.watch(mcpAuditFilterProvider);
  return db.watchMcpAuditEntries(
    limit: 100,
    toolName: filter.toolName,
    resultStatus: filter.resultStatus,
  );
});

/// Drops audit-log rows beyond the retention window. Kept behind a provider
/// so lifecycle listeners, quick-action buttons, and tests can share one
/// instance instead of each newing up their own against the same database.
final mcpAuditRetentionProvider = Provider<McpAuditRetention>((ref) {
  return McpAuditRetention(ref.watch(databaseProvider));
});

/// Tool names present in the audit log. Powers the filter dropdown.
final mcpAuditToolNamesProvider = FutureProvider<List<String>>((ref) {
  // Re-resolve whenever the log itself changes so newly-seen tools show
  // up in the filter without requiring a screen pop.
  ref.watch(mcpAuditLogProvider);
  final db = ref.watch(databaseProvider);
  return db.getDistinctMcpAuditToolNames();
});

/// The MCP server instance. Created when:
/// - Platform is macOS
/// - User is logged in
///
/// Auto-stops on logout or account switch (provider rebuilds → ref.onDispose
/// fires). Auto-starts if the account has MCP enabled in saved settings.
final mcpServerProvider = Provider<McpServer?>((ref) {
  if (!Platform.isMacOS) return null;
  final loggedIn = ref.watch(isLoggedInProvider);
  if (!loggedIn) return null;

  final server = McpServer(ref);
  ref.onDispose(() => server.stop());

  // Auto-start if settings say enabled. fireImmediately ensures the
  // callback runs for the current value, not just future changes.
  ref.listen<AsyncValue<McpSetting?>>(mcpSettingsProvider, (prev, next) {
    final settings = next.valueOrNull;
    if (settings == null || !settings.enabled) return;
    if (server.isRunning) return;

    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    final token = settings.bearerToken.isEmpty
        ? null
        : decryptMcpTokenWith(
            account: account,
            crypto: ref.read(cryptoServiceProvider),
            identityPrivateKey: ref.read(decryptedPrivateKeyProvider),
            wrappingPrivateKey: ref.read(decryptedWrappingPrivateKeyProvider),
            ciphertext: settings.bearerToken,
          );
    if (token == null || token.isEmpty) return;

    server.start(port: settings.port, bearerToken: token);
  }, fireImmediately: true);

  return server;
});
