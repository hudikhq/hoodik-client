import 'dart:io';
import 'dart:ui' show VoidCallback;

import 'package:tray_manager/tray_manager.dart';

import '../utils/logger.dart';

const Logger _log = Logger('platform.tray');

/// True when the current platform has a system tray / menu bar we can
/// attach to. iOS and Android have neither, so [TrayService] becomes a
/// no-op there; the Dart code compiles everywhere, but the native plugin
/// only ships with the macOS/Linux/Windows builds.
bool get isDesktop =>
    Platform.isMacOS || Platform.isLinux || Platform.isWindows;

/// Shape of the backing tray. Real on desktop, stub on mobile. Extracted
/// so tests can swap in a capturing fake without reaching for mirrors or
/// relying on the platform-channel plugin being registered.
abstract class TrayBackend {
  Future<void> setIcon(String path);
  Future<void> setToolTip(String text);
  Future<void> setContextMenu(Menu menu);
  Future<void> popUpContextMenu();
  Future<void> destroy();
  void addListener(TrayListener listener);
  void removeListener(TrayListener listener);
}

/// Default backend: delegates to the shared [trayManager] singleton from
/// the `tray_manager` plugin. Only instantiated when [isDesktop] is true.
class _RealTrayBackend implements TrayBackend {
  @override
  Future<void> setIcon(String path) => trayManager.setIcon(path);

  @override
  Future<void> setToolTip(String text) => trayManager.setToolTip(text);

  @override
  Future<void> setContextMenu(Menu menu) => trayManager.setContextMenu(menu);

  @override
  Future<void> popUpContextMenu() => trayManager.popUpContextMenu();

  @override
  Future<void> destroy() => trayManager.destroy();

  @override
  void addListener(TrayListener listener) => trayManager.addListener(listener);

  @override
  void removeListener(TrayListener listener) =>
      trayManager.removeListener(listener);
}

/// Mobile fallback — every method is a no-op so callers don't need a
/// `isDesktop` guard. Kept visible so tests can assert "on mobile we
/// installed a stub" without any platform channels running.
class NoopTrayBackend implements TrayBackend {
  int setIconCalls = 0;
  int setContextMenuCalls = 0;

  @override
  Future<void> setIcon(String path) async {
    setIconCalls++;
  }

  @override
  Future<void> setToolTip(String text) async {}

  @override
  Future<void> setContextMenu(Menu menu) async {
    setContextMenuCalls++;
  }

  @override
  Future<void> popUpContextMenu() async {}

  @override
  Future<void> destroy() async {}

  @override
  void addListener(TrayListener listener) {}

  @override
  void removeListener(TrayListener listener) {}
}

/// Callbacks the tray needs to ask the rest of the app about server state
/// and to execute the user's selection. Injected so the service itself
/// never imports UI widgets or Riverpod scopes directly.
class TrayCallbacks {
  /// Returns the current MCP server state. Called whenever the tray menu
  /// rebuilds — needs to be cheap (no I/O).
  final TrayServerState Function() serverState;

  final Future<void> Function(bool enabled) onSetEnabled;
  final Future<void> Function() onLockSession;
  final VoidCallback onOpenApp;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAuditLog;
  final VoidCallback onQuit;

  TrayCallbacks({
    required this.serverState,
    required this.onSetEnabled,
    required this.onLockSession,
    required this.onOpenApp,
    required this.onOpenSettings,
    required this.onOpenAuditLog,
    required this.onQuit,
  });
}

/// Snapshot of MCP server state, packaged so the menu-builder stays
/// decoupled from the Riverpod provider layer. Kept a class rather than a
/// tuple so future additions (last-activity timestamp, paused/locked
/// flags) slot in without breaking call sites.
class TrayServerState {
  final bool running;
  final bool enabled;
  final int? port;
  final bool canLockSession;

  const TrayServerState({
    required this.running,
    this.enabled = false,
    this.port,
    this.canLockSession = false,
  });
}

/// Keys the context menu uses to route clicks back to the callbacks.
/// Exposed so tests can navigate the menu by key rather than index.
class TrayMenuKeys {
  static const status = 'mcp.status';
  static const toggleEnabled = 'mcp.toggle_enabled';
  static const lockSession = 'mcp.lock_session';
  static const openApp = 'mcp.open_app';
  static const openSettings = 'mcp.open_settings';
  static const openAuditLog = 'mcp.open_audit_log';
  static const quit = 'mcp.quit';
}

/// Desktop tray / menu-bar integration for Hoodik. Renders an MCP-state
/// entry plus quick actions (pause/resume, open settings, open audit
/// log, quit). Methods are no-ops on iOS and Android so the call sites in
/// `main.dart` don't need to branch on platform.
class TrayService with TrayListener {
  final TrayBackend _backend;
  final TrayCallbacks _callbacks;
  final String _iconAssetPath;
  final String _runningIconAssetPath;
  final Future<void> Function()? _onDispose;
  bool _initialized = false;

  TrayService({
    required TrayCallbacks callbacks,
    TrayBackend? backend,
    String iconAssetPath = 'assets/icon.png',
    String runningIconAssetPath = 'assets/icon_mcp_running.png',
    Future<void> Function()? onDispose,
  }) : _callbacks = callbacks,
       _backend =
           backend ?? (isDesktop ? _RealTrayBackend() : NoopTrayBackend()),
       _iconAssetPath = iconAssetPath,
       _runningIconAssetPath = runningIconAssetPath,
       _onDispose = onDispose;

  /// True on desktop platforms where the tray actually installs.
  bool get isSupported => isDesktop;

  /// Visible for tests.
  TrayBackend get backend => _backend;

  Future<void> initialize() async {
    if (!isSupported) return;
    if (_initialized) return;
    _initialized = true;

    try {
      _backend.addListener(this);
      await refresh();
    } catch (e) {
      _log.error('tray init failed', fields: {'error': e.toString()});
      _initialized = false;
    }
  }

  /// Refresh the tooltip + menu against the current server state. Safe to
  /// call on every MCP server transition (start/stop/pause) without
  /// worrying about duplicating work — the backend batches under the hood.
  Future<void> refresh() async {
    if (!isSupported || !_initialized) return;
    final state = _callbacks.serverState();
    try {
      await _backend.setIcon(_iconPathFor(state));
      await _backend.setToolTip(_tooltipFor(state));
      await _backend.setContextMenu(buildMenu(state));
    } catch (e) {
      _log.warn('tray refresh failed', fields: {'error': e.toString()});
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    _initialized = false;
    try {
      await _onDispose?.call();
      _backend.removeListener(this);
      await _backend.destroy();
    } catch (_) {
      // The platform side may already be gone (app is shutting down).
    }
  }

  /// Builds the tray context menu for the given [state]. Public so unit
  /// tests can assert on item keys, labels, and enabled/disabled flags
  /// without spinning up a backend.
  Menu buildMenu(TrayServerState state) {
    final running = state.running;
    final statusLabel = running
        ? '🟢 MCP server: running on :${state.port ?? '?'}'
        : 'MCP server: off';

    return Menu(
      items: [
        MenuItem(key: TrayMenuKeys.status, label: statusLabel, disabled: true),
        MenuItem(
          key: TrayMenuKeys.toggleEnabled,
          label: state.enabled ? 'Disable MCP' : 'Enable MCP',
        ),
        MenuItem(
          key: TrayMenuKeys.lockSession,
          label: 'Lock current session',
          disabled: !state.canLockSession,
        ),
        MenuItem.separator(),
        MenuItem(key: TrayMenuKeys.openApp, label: 'Open Hoodik'),
        MenuItem(key: TrayMenuKeys.openSettings, label: 'Open MCP settings'),
        MenuItem(key: TrayMenuKeys.openAuditLog, label: 'View audit log'),
        MenuItem.separator(),
        MenuItem(key: TrayMenuKeys.quit, label: 'Quit Hoodik'),
      ],
    );
  }

  String _iconPathFor(TrayServerState state) {
    return state.running ? _runningIconAssetPath : _iconAssetPath;
  }

  String _tooltipFor(TrayServerState state) {
    if (state.running) {
      return 'Hoodik \u2022 🟢 MCP running on :${state.port ?? '?'}';
    }
    return 'Hoodik \u2022 MCP off';
  }

  @override
  void onTrayIconMouseDown() {
    _callbacks.onOpenApp();
  }

  @override
  void onTrayIconRightMouseDown() {
    _backend.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case TrayMenuKeys.toggleEnabled:
        final state = _callbacks.serverState();
        _callbacks.onSetEnabled(!state.enabled).whenComplete(refresh);
      case TrayMenuKeys.lockSession:
        _callbacks.onLockSession().whenComplete(refresh);
      case TrayMenuKeys.openApp:
        _callbacks.onOpenApp();
      case TrayMenuKeys.openSettings:
        _callbacks.onOpenSettings();
      case TrayMenuKeys.openAuditLog:
        _callbacks.onOpenAuditLog();
      case TrayMenuKeys.quit:
        _callbacks.onQuit();
    }
  }
}
