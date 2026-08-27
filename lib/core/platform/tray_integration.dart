import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/services/mcp_token_crypto.dart';
import '../auth/auth_service.dart';
import '../auth/auth_state.dart';
import '../mcp/mcp_server.dart';
import '../providers.dart';
import '../storage/database.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';
import 'tray_service.dart';
import 'window_control.dart';
import 'tray_state_watcher.dart';

export 'tray_service.dart' show TrayService;

const _log = Logger('platform.tray-integration');

/// Wire the desktop tray up on first frame and keep it reactive to MCP
/// state. Returns the [TrayService] so the caller can dispose it; returns
/// null on iOS / Android.
///
/// Call once from `main.dart` during `initState`. The returned service is
/// driven by [ref.listenManual] subscriptions that auto-cancel when the
/// owning widget tears down, so the caller only needs to remember to
/// dispose the service itself.
TrayService? attachMcpTray({required WidgetRef ref, required GoRouter router}) {
  if (!isDesktop) return null;

  TrayServerState readState() {
    // mcpServerProvider is created from setLoggedIn. A listenManual on
    // mcpSettingsProvider can fire *while* that provider is still building;
    // reading it then throws StateError and used to abort MCP auto-start.
    McpServer? server;
    try {
      server = ref.read(mcpServerProvider);
    } on StateError {
      server = null;
    }
    final account = ref.read(activeAccountProvider);
    final settings = ref.read(mcpSettingsProvider).valueOrNull;
    return TrayServerState(
      running: server?.isRunning ?? false,
      port: server?.port,
      enabled: settings?.enabled ?? false,
      canLockSession: account?.pinEncryptedPrivateKey != null,
    );
  }

  late final TrayStateWatcher watcher;
  final service = TrayService(
    callbacks: TrayCallbacks(
      serverState: readState,
      onSetEnabled: (enabled) => _setMcpEnabled(ref, enabled),
      onOpenApp: () => unawaited(_bringAppToFront()),
      onOpenSettings: () {
        unawaited(router.push('/mcp-settings'));
        unawaited(_bringAppToFront());
      },
      onOpenAuditLog: () {
        unawaited(router.push('/account/ai-access/audit-log'));
        unawaited(_bringAppToFront());
      },
      onLockSession: () => _lockCurrentSession(ref, router),
      onQuit: () => SystemNavigator.pop(),
    ),
    onDispose: () async => watcher.stop(),
  );

  void refreshTray() {
    scheduleMicrotask(() {
      try {
        service.refresh();
      } catch (e) {
        _log.warn('tray refresh skipped', fields: {'error': e.toString()});
      }
    });
  }

  watcher = TrayStateWatcher(
    readState: () {
      final state = readState();
      return TrayObservedState(running: state.running, port: state.port);
    },
    onChanged: (_) => service.refresh(),
  );
  watcher.start();

  ref.listenManual(mcpServerProvider, (_, _) => refreshTray());
  ref.listenManual(mcpSettingsProvider, (_, _) => refreshTray());

  SchedulerBinding.instance.addPostFrameCallback((_) => service.initialize());
  return service;
}

Future<void> _setMcpEnabled(WidgetRef ref, bool enabled) async {
  final account = ref.read(activeAccountProvider);
  if (account == null) return;

  final db = ref.read(databaseProvider);
  final current = await db.getMcpSettings(account.id);
  final encryptedToken = resolveStoredMcpCiphertext(
    storedCiphertext: current?.bearerToken,
    encrypt: (plaintext) => encryptMcpToken(ref, plaintext),
  );
  if (encryptedToken == null || encryptedToken.isEmpty) return;

  await db.upsertMcpSettings(
    account.id,
    McpSettingsCompanion(
      enabled: Value(enabled),
      port: Value(current?.port ?? kDefaultMcpPort),
      bearerToken: Value(encryptedToken),
      allowReadOnlyWhileLocked: Value(
        current?.allowReadOnlyWhileLocked ?? false,
      ),
      rateLimitRps: Value(current?.rateLimitRps ?? 5),
      rateLimitBurst: Value(current?.rateLimitBurst ?? 20),
      auditRetentionDays: Value(current?.auditRetentionDays ?? 30),
      lastAuditCleanupAt: Value(current?.lastAuditCleanupAt),
    ),
  );
  ref.invalidate(mcpSettingsProvider);

  final server = ref.read(mcpServerProvider);
  if (!enabled) {
    await server?.stop();
    return;
  }

  if (server == null || server.isRunning) return;

  final token = decryptMcpToken(ref, encryptedToken);
  if (token == null || token.isEmpty) return;

  try {
    await server.start(
      port: current?.port ?? kDefaultMcpPort,
      bearerToken: token,
    );
  } catch (e) {
    _log.warn('tray enable failed', fields: {'error': redactException(e)});
  }
}

Future<void> _bringAppToFront() async {
  try {
    await bringAppToFront();
  } catch (e) {
    _log.warn('tray open app failed', fields: {'error': e.toString()});
  }
}

Future<void> _lockCurrentSession(WidgetRef ref, GoRouter router) async {
  final account = ref.read(activeAccountProvider);
  if (account?.pinEncryptedPrivateKey == null) return;

  try {
    final server = ref.read(mcpServerProvider);
    await server?.stop();
  } catch (e) {
    _log.warn('tray lock stop mcp failed', fields: {'error': e.toString()});
  }

  final authService = ref.read(authServiceProvider);
  await authService.logout();

  ref.read(isLockedProvider.notifier).state = false;
  ref.setLoggedOut();

  router.go('/auth/unlock?accountId=${account!.id}');
  await _bringAppToFront();
}
