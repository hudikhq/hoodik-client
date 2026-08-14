import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'core/platform/tray_integration.dart';
import 'core/services/connect_link.dart';
import 'core/services/file_downloader_config.dart';
import 'core/services/preferences.dart';
import 'core/services/share_handler.dart';
import 'core/storage/at_rest_cipher.dart';
import 'core/storage/no_backup.dart';
import 'core/theme/hoodik_theme.dart';
import 'core/utils/app_session.dart';
import 'core/utils/bundled_licenses.dart';
import 'core/utils/log_file_sink.dart';
import 'core/utils/log_redact.dart';
import 'core/utils/logger.dart';
import 'package:intl/intl.dart' show Intl;
import 'core/widgets/adaptive.dart';
import 'core/widgets/keyboard_dismiss.dart';
import 'core/widgets/privacy_shield.dart';
import 'l10n/generated/app_localizations.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/auth_state.dart';
import 'core/providers.dart';
import 'features/auth/widgets/lock_overlay.dart';
import 'features/files/widgets/folder_picker_dialog.dart';
import 'src/rust/frb_generated.dart';
import 'router.dart';

/// Global router instance — created once in [_HoodikAppState].
late GoRouter appRouter;

const _log = Logger('HoodikApp');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await RustLib.init();

  // Stamp the session boundary before anything else — the bug-report
  // export uses this to filter "current session only" logs.
  AppSession.start();

  registerBundledEditorLicenses();

  // Every build writes to the rotating on-disk sink so the Privacy &
  // Diagnostics export always has something to show — this matters in
  // debug as much as in release, because macOS devs running the app from
  // `flutter run` still need to reproduce the bug-report flow. Debug
  // builds additionally mirror records to stdout for live tailing.
  final sinks = <LogSink>[];
  if (kDebugMode) {
    sinks.add(stdoutLogSink);
  }
  try {
    final fileSink = await LogFileSink.open();
    sinks.add(fileSink.record);
    unawaited(fileSink.pruneOlderThan(const Duration(days: 3)));
  } catch (_) {
    // Best-effort — never block app start on a logging failure.
  }
  configureLogging(
    minLevel: kDebugMode ? Level.debug : Level.info,
    sinks: sinks,
  );

  // Purges orphaned downloads from a killed-then-restarted session that would compete for bandwidth.
  await cleanUpFileDownloader();

  // Loaded synchronously so early provider reads (view mode, landing branch) don't need to await.
  final preferences = await Preferences.load();

  runApp(
    ProviderScope(
      overrides: [preferencesProvider.overrideWithValue(preferences)],
      child: const HoodikApp(),
    ),
  );
}

class HoodikApp extends ConsumerStatefulWidget {
  const HoodikApp({super.key});

  @override
  ConsumerState<HoodikApp> createState() => _HoodikAppState();
}

class _HoodikAppState extends ConsumerState<HoodikApp>
    with WidgetsBindingObserver {
  bool _initialized = false;
  final ShareHandler _shareHandler = ShareHandler();
  final ConnectLinkHandler _connectLinks = ConnectLinkHandler();

  /// File paths received via share intent while the app was locked.
  /// Processed once the user unlocks and [isLoggedInProvider] becomes true.
  List<String> _pendingSharedFiles = [];

  /// Timestamp when the app was last paused (backgrounded).
  /// Used with a grace period to avoid false-positive PIN prompts from
  /// brief system interruptions (permission dialogs, share sheets).
  DateTime? _pausedAt;
  TrayService? _tray;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appRouter = buildRouter(() => ref.read(isLoggedInProvider));
    _init();

    // Auto-init worker isolates whenever a new WorkerManager appears
    // (i.e. after login/unlock from any screen). Handles both null→WM
    // and WM_old→WM_new transitions to guard against provider rebuilds.
    ref.listenManual(workerManagerProvider, (prev, next) {
      if (next != null && next != prev) {
        _initWorkers();
      }
    });

    // Configure BackgroundDownloadService when it becomes available (login).
    ref.listenManual(backgroundDownloadServiceProvider, (prev, next) {
      if (next != null && next != prev) {
        next.configure().catchError((e) {
          _log.warn(
            'background download service configure failed',
            fields: {'error': redactException(e)},
          );
        });
      }
    });

    // Process any pending shared files once the user logs in or unlocks.
    // Delayed so the route transition (unlock → home) finishes before we
    // show the folder picker dialog — otherwise go('/') dismisses it.
    ref.listenManual(isLoggedInProvider, (prev, next) {
      if (next == true && _pendingSharedFiles.isNotEmpty) {
        final paths = _pendingSharedFiles;
        _pendingSharedFiles = [];
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showUploadPicker(paths);
        });
      }
    });

    // Listen for files shared into the app from other apps (mobile only).
    if (Platform.isAndroid || Platform.isIOS) {
      _shareHandler.onFilesReceived = _handleSharedFiles;
      _shareHandler.init();
    }

    _connectLinks.onLink = _handleConnectLink;
    _connectLinks.init();
    _tray = attachMcpTray(ref: ref, router: appRouter);
  }

  @override
  void dispose() {
    _shareHandler.dispose();
    _connectLinks.dispose();
    _tray?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    appRouter.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retry loading the at-rest key on resume: a background launch before the
    // device's first unlock leaves the keychain unreadable, so the cipher would
    // otherwise run the whole session unkeyed and drop every sealed write to
    // NULL. Idempotent — a no-op once the key is in memory.
    if (state == AppLifecycleState.resumed) {
      unawaited(AtRestCipher.instance.ensureInitialized());
    }

    final client = ref.read(authServiceProvider).activeClient;
    if (client == null) return;

    if (state == AppLifecycleState.resumed) {
      client.startSessionRefreshTimer();
      client.ensureFreshSession();
      _maybeShowLockScreen();

      // Push fresh session cookies to worker isolates so transfers can
      // continue without waiting for a 401. Also restarts crashed workers.
      ref.read(workerManagerProvider)?.notifyResumed();

      // Replay buffered OS download events so the UI catches up on progress.
      ref.read(backgroundDownloadServiceProvider)?.resumeFromBackground();
      ref.read(backgroundTarTransferProvider)?.resumeFromBackground();

      // Prune MCP audit entries past the user's retention window. Debounced
      // to 24h inside the retention helper so a burst of resume events from
      // brief backgrounding doesn't thrash the database.
      _maybeRunMcpRetention();
    } else if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      client.stopSessionRefreshTimer();
    } else if (state == AppLifecycleState.inactive) {
      // Don't record _pausedAt for inactive — it fires for permission
      // dialogs, notification shade, etc. Only true backgrounding (paused)
      // should trigger a lock.
      client.stopSessionRefreshTimer();
    }
  }

  /// Check if the app should be locked behind a PIN overlay after resuming.
  Future<void> _maybeShowLockScreen() async {
    // Skip if not logged in or already locked.
    final loggedIn = ref.read(isLoggedInProvider);
    if (!loggedIn) return;
    if (ref.read(isLockedProvider)) return;

    // Only lock when the app was actually backgrounded (paused). Skip if
    // _pausedAt is null — that means no real backgrounding occurred (e.g.
    // an inactive→resumed from Face ID dialog or notification shade).
    if (_pausedAt == null) return;

    final elapsed = DateTime.now().difference(_pausedAt!);
    _pausedAt = null;

    // Grace period: ignore brief pauses (<3 seconds) caused by permission
    // dialogs, share sheets, or other system UI.
    if (elapsed.inSeconds < 3) return;

    // Check if the active account has a PIN configured.
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    final authService = ref.read(authServiceProvider);
    final hasPin = await authService.hasPinSetup(account.id);
    if (!hasPin) return;

    if (mounted) {
      ref.read(isLockedProvider.notifier).state = true;
    }
  }

  Future<void> _init() async {
    try {
      await _startAuthFlow();
    } catch (e) {
      _log.warn('auth flow failed', fields: {'error': redactException(e)});
    }

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  /// Run the PIN-unlock / session-restore flow.
  /// Called from [_init] on startup.
  Future<void> _startAuthFlow() async {
    final authService = ref.read(authServiceProvider);

    // Migrate any legacy plaintext biometric PINs from SQLite to the
    // platform keychain/keystore. Safe to call on every launch — it's a
    // no-op if there's nothing to migrate.
    await authService.migrateBiometricPins();

    // The DB file exists now (the migration above queried it), so mark it as
    // excluded from iCloud/iTunes backups. Best-effort and non-blocking.
    unawaited(excludeDatabaseFromBackup());

    authService.onSessionExpired = () async {
      if (!mounted) return;
      ref.read(isLockedProvider.notifier).state = false;
      ref.setLoggedOut();
      // Mirror the startup decision below: a session expiring mid-use should
      // offer PIN unlock when this device has a PIN-protected account, instead
      // of bouncing the user all the way back to server selection.
      final pinAccount = await authService.getAccountWithPinKey();
      if (!mounted) return;
      appRouter.go(pinAccount != null ? '/auth/unlock' : '/setup/server');
    };

    // Check for PIN-locked account first (prefers active/last-used).
    final pinAccount = await authService.getAccountWithPinKey();
    if (pinAccount != null) {
      // Ensure the DB and providers agree on which account is being unlocked.
      final db = ref.read(databaseProvider);
      await db.setActiveAccount(pinAccount.id);

      // The account email is NOT interpolated into the log message — the
      // per-line account-context prefix renders the identity once the
      // unlock flow sets it, so repeating it here would duplicate.
      _log.info('PIN-encrypted key found — showing unlock screen');
      if (mounted) {
        setState(() => _initialized = true);
      }
      _goUnlessConnectPending('/auth/unlock');
      return;
    }

    // No PIN setup — try to restore the session normally.
    final restored = await authService.tryRestoreSession();

    if (restored) {
      final pk = authService.decryptedPrivateKey;
      ref.setLoggedIn(
        account: authService.activeAccount!,
        server: authService.activeServer,
        privateKey: pk,
        wrappingPrivateKey: authService.decryptedWrappingPrivateKey,
      );
      _log.info('session restored', fields: {'has_private_key': pk != null});

      _goUnlessConnectPending('/');
    } else {
      _log.info('no session to restore');
      _goUnlessConnectPending('/setup/server');
    }
  }

  /// A scanned connect QR lands here: stash the details for the add-server
  /// and login screens, then open the start of that flow.
  void _handleConnectLink(ConnectLink link) {
    ref.read(pendingConnectProvider.notifier).state = link;
    appRouter.go('/setup/server');
  }

  /// Startup navigation yields to a connect link that arrived while the auth
  /// flow was still running — the user asked for that screen explicitly, and
  /// the link can land either side of these awaits.
  ///
  /// This holds even when the route matches where the link already went:
  /// routing to the same path replaces it, disposing the screen mid-connect,
  /// and the navigation that follows a successful connect is then dropped for
  /// being unmounted.
  void _goUnlessConnectPending(String route) {
    if (ref.read(pendingConnectProvider) != null) return;
    appRouter.go(route);
  }

  void _handleSharedFiles(List<String> paths) {
    final loggedIn = ref.read(isLoggedInProvider);
    if (!loggedIn) {
      // App is locked or not yet authenticated. Hold onto the files and
      // process them after the user unlocks (see isLoggedInProvider listener).
      _pendingSharedFiles = [..._pendingSharedFiles, ...paths];
      _log.info(
        'queued shared files — waiting for unlock',
        fields: {'count': paths.length},
      );
      return;
    }
    // Show folder picker, then upload to chosen directory.
    _showUploadPicker(paths);
  }

  Future<void> _showUploadPicker(List<String> paths) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final client = ref.read(apiClientProvider);
    final fileCrypto = ref.read(fileCryptoProvider);
    if (client == null) return;

    final l10n = AppLocalizations.of(context);
    final result = await showFolderPicker(
      context: context,
      client: client,
      fileCrypto: fileCrypto,
      title: l10n.filesUploadTo,
      confirmLabel: l10n.filesUploadHere,
    );
    if (result == null) return; // user cancelled

    final syncService = ref.read(syncServiceProvider);

    for (final path in paths) {
      try {
        await syncService.uploadFileOrQueue(
          localPath: path,
          parentDirId: result.folderId,
        );
      } catch (e) {
        // The local path is NOT logged — it usually contains the user's
        // original filename and may include the account's sandbox path.
        _log.warn(
          'shared file upload failed',
          fields: {'error': redactException(e)},
        );
      }
    }
  }

  /// Trigger the MCP retention pass for the active account, if any. Fires
  /// on app foreground; no-op when logged out or when no account is active.
  void _maybeRunMcpRetention() {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    final retention = ref.read(mcpAuditRetentionProvider);
    retention.maybeRun(account.id).catchError((e) {
      _log.warn(
        'MCP retention pass failed',
        fields: {'error': redactException(e)},
      );
      return 0;
    });
  }

  void _initWorkers() {
    final client = ref.read(apiClientProvider);
    final wm = ref.read(workerManagerProvider);
    if (client == null || wm == null) return;

    wm
        .init(baseUrl: client.baseUrl)
        .then((_) {
          _log.info('worker isolates initialized');
        })
        .catchError((e) {
          _log.warn(
            'worker init failed — main-thread fallback in effect',
            fields: {'error': redactException(e)},
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final appLocale = ref.watch(appLocaleProvider);

    // Non-widget code (formatters, background services) reads the active
    // language through `Intl.defaultLocale` instead of a BuildContext, so
    // keep it in lockstep with what the MaterialApps resolve to.
    Intl.defaultLocale = _resolvedLocale(appLocale).languageCode;

    if (!_initialized) {
      // Splash / loading — adaptive spinner.
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: HoodikTheme.dark(),
        locale: appLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: isApplePlatform
                ? const CupertinoActivityIndicator(radius: 14)
                : const CircularProgressIndicator(),
          ),
        ),
      );
    }

    final isLocked = ref.watch(isLockedProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        MaterialApp.router(
          title: 'Hoodik',
          debugShowCheckedModeBanner: false,
          theme: HoodikTheme.light(),
          darkTheme: HoodikTheme.dark(),
          themeMode: themeMode,
          locale: appLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: appRouter,
          // Wrap every navigator child with the privacy shield so the
          // app switcher snapshot (and any brief out-of-focus moment
          // on mobile) hides sensitive content behind a blur, and with
          // tap-to-dismiss so any tap on empty space drops the keyboard.
          builder: (context, child) => KeyboardDismissOnTap(
            child: PrivacyShield(child: child ?? const SizedBox.shrink()),
          ),
        ),
        if (isLocked)
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: HoodikTheme.light(),
            darkTheme: HoodikTheme.dark(),
            themeMode: themeMode,
            locale: appLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) =>
                KeyboardDismissOnTap(child: child ?? const SizedBox.shrink()),
            home: const LockOverlay(),
          ),
      ],
    );
  }

  /// The locale the app will actually render in: the explicit preference
  /// when set, otherwise the first device language we support, else English.
  Locale _resolvedLocale(Locale? preference) {
    if (preference != null) return preference;
    for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
      if (AppLocaleNotifier.supported.contains(locale.languageCode)) {
        return Locale(locale.languageCode);
      }
    }
    return const Locale('en');
  }
}
