import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/platform/tray_service.dart';
import 'package:tray_manager/tray_manager.dart';

class _CapturingBackend implements TrayBackend {
  int iconCalls = 0;
  int tooltipCalls = 0;
  int menuCalls = 0;
  int popupMenuCalls = 0;
  int destroyCalls = 0;
  final List<String> iconPaths = [];
  String? lastIcon;
  String? lastTooltip;
  Menu? lastMenu;
  final List<TrayListener> listeners = [];

  @override
  Future<void> setIcon(String path) async {
    iconCalls++;
    lastIcon = path;
    iconPaths.add(path);
  }

  @override
  Future<void> setToolTip(String text) async {
    tooltipCalls++;
    lastTooltip = text;
  }

  @override
  Future<void> setContextMenu(Menu menu) async {
    menuCalls++;
    lastMenu = menu;
  }

  @override
  Future<void> popUpContextMenu({bool bringAppToFront = false}) async {
    popupMenuCalls++;
  }

  @override
  Future<void> destroy() async {
    destroyCalls++;
  }

  @override
  void addListener(TrayListener listener) => listeners.add(listener);

  @override
  void removeListener(TrayListener listener) => listeners.remove(listener);
}

TrayCallbacks _callbacks({
  required TrayServerState Function() state,
  Future<void> Function(bool enabled)? onSetEnabled,
  Future<void> Function()? onLockSession,
  void Function()? onOpenApp,
  void Function()? onOpenSettings,
  void Function()? onOpenAuditLog,
  void Function()? onQuit,
}) {
  return TrayCallbacks(
    serverState: state,
    onSetEnabled: onSetEnabled ?? (_) async {},
    onLockSession: onLockSession ?? () async {},
    onOpenApp: onOpenApp ?? () {},
    onOpenSettings: onOpenSettings ?? () {},
    onOpenAuditLog: onOpenAuditLog ?? () {},
    onQuit: onQuit ?? () {},
  );
}

void main() {
  group('TrayService.buildMenu', () {
    test('enabled running state shows port and Disable entry', () {
      final service = TrayService(
        callbacks: _callbacks(
          state: () =>
              const TrayServerState(running: true, port: 19548, enabled: true),
        ),
        backend: _CapturingBackend(),
      );

      final menu = service.buildMenu(
        const TrayServerState(running: true, port: 19548, enabled: true),
      );

      final items = menu.items!;
      expect(items.length, 9);
      expect(items[0].key, TrayMenuKeys.status);
      expect(items[0].label, contains('🟢'));
      expect(items[0].label, contains('19548'));
      expect(items[0].disabled, isTrue);
      expect(items[1].key, TrayMenuKeys.toggleEnabled);
      expect(items[1].label, 'Disable MCP');
      expect(items[2].key, TrayMenuKeys.lockSession);
      expect(items[2].label, 'Lock current session');
      expect(items[2].disabled, isTrue);
      expect(items[3].type, 'separator');
      expect(items[4].key, TrayMenuKeys.openApp);
      expect(items[5].key, TrayMenuKeys.openSettings);
      expect(items[6].key, TrayMenuKeys.openAuditLog);
      expect(items[7].type, 'separator');
      expect(items[8].key, TrayMenuKeys.quit);
    });

    test('disabled state shows "off" and Enable entry', () {
      final service = TrayService(
        callbacks: _callbacks(
          state: () => const TrayServerState(running: false, enabled: false),
        ),
        backend: _CapturingBackend(),
      );

      final menu = service.buildMenu(
        const TrayServerState(running: false, enabled: false),
      );

      final items = menu.items!;
      expect(items[0].label, 'MCP server: off');
      expect(items[0].label, isNot(contains('🟢')));
      expect(items[1].key, TrayMenuKeys.toggleEnabled);
      expect(items[1].label, 'Enable MCP');
      expect(items[2].key, TrayMenuKeys.lockSession);
      expect(items[2].label, 'Lock current session');
      expect(items[2].disabled, isTrue);
    });
  });

  group('TrayService.initialize', () {
    test('mobile path short-circuits before touching the backend', () async {
      final noop = NoopTrayBackend();
      final service = _MobileTrayService(
        callbacks: _callbacks(
          state: () => const TrayServerState(running: false),
        ),
        backend: noop,
      );

      await service.initialize();
      await service.refresh();

      expect(noop.setIconCalls, 0);
      expect(noop.setContextMenuCalls, 0);
    });

    test('real backend receives icon + listener + menu on init', () async {
      final backend = _CapturingBackend();
      final service = _DesktopTrayService(
        callbacks: _callbacks(
          state: () =>
              const TrayServerState(running: true, port: 4242, enabled: true),
        ),
        backend: backend,
      );

      await service.initialize();

      expect(backend.iconCalls, 1);
      expect(backend.lastIcon, 'assets/icon_mcp_running.png');
      expect(backend.menuCalls, 1);
      expect(backend.tooltipCalls, 1);
      expect(backend.lastTooltip, contains('🟢'));
      expect(backend.lastTooltip, contains('4242'));
      expect(backend.listeners.length, 1);
    });

    test('initialize is idempotent', () async {
      final backend = _CapturingBackend();
      final service = _DesktopTrayService(
        callbacks: _callbacks(
          state: () => const TrayServerState(running: false),
        ),
        backend: backend,
      );

      await service.initialize();
      await service.initialize();

      expect(backend.iconCalls, 1);
      expect(backend.listeners.length, 1);
    });
  });

  group('TrayService.refresh', () {
    test('updates tooltip and menu when server state changes', () async {
      var running = false;
      final backend = _CapturingBackend();
      final service = _DesktopTrayService(
        callbacks: _callbacks(
          state: () =>
              TrayServerState(running: running, port: 19548, enabled: running),
        ),
        backend: backend,
      );

      await service.initialize();
      final initialMenuCalls = backend.menuCalls;
      final initialTooltip = backend.lastTooltip;

      running = true;
      await service.refresh();

      expect(backend.menuCalls, greaterThan(initialMenuCalls));
      expect(backend.lastTooltip, isNot(initialTooltip));
      expect(backend.lastTooltip, contains('🟢'));
      expect(backend.lastTooltip, contains('running'));
    });

    test('switches the tray icon between off and running assets', () async {
      var running = false;
      final backend = _CapturingBackend();
      final service = _DesktopTrayService(
        callbacks: _callbacks(
          state: () => TrayServerState(running: running, port: 19548),
        ),
        backend: backend,
      );

      await service.initialize();
      final initialIcon = backend.lastIcon;
      expect(initialIcon, isNotNull);

      running = true;
      await service.refresh();

      expect(backend.iconCalls, greaterThanOrEqualTo(2));
      expect(backend.lastIcon, isNot(initialIcon));
      expect(backend.iconPaths.first, equals(initialIcon));
      expect(backend.iconPaths.last, equals(backend.lastIcon));
    });

    test('left click opens the app without popping the context menu', () async {
      var openCalls = 0;
      final backend = _CapturingBackend();
      final service = _DesktopTrayService(
        callbacks: _callbacks(
          state: () => const TrayServerState(running: false, enabled: false),
          onOpenApp: () {
            openCalls++;
          },
        ),
        backend: backend,
      );

      await service.initialize();
      service.onTrayIconMouseDown();

      expect(openCalls, 1);
      expect(backend.popupMenuCalls, 0);
    });

    test('right click pops the context menu', () async {
      final backend = _CapturingBackend();
      final service = _DesktopTrayService(
        callbacks: _callbacks(
          state: () => const TrayServerState(running: false, enabled: false),
        ),
        backend: backend,
      );

      await service.initialize();
      service.onTrayIconRightMouseDown();

      expect(backend.popupMenuCalls, 1);
    });

    test(
      'toggle enabled menu item calls the enable/disable callback',
      () async {
        final seen = <bool>[];
        final backend = _CapturingBackend();
        final service = _DesktopTrayService(
          callbacks: _callbacks(
            state: () => const TrayServerState(
              running: true,
              port: 19548,
              enabled: true,
            ),
            onSetEnabled: (enabled) async {
              seen.add(enabled);
            },
          ),
          backend: backend,
        );

        await service.initialize();
        service.onTrayMenuItemClick(
          MenuItem(key: TrayMenuKeys.toggleEnabled, label: 'Disable MCP'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(seen, equals([false]));
      },
    );

    test('lock session menu item calls the lock callback', () async {
      var lockCalls = 0;
      final backend = _CapturingBackend();
      final service = _DesktopTrayService(
        callbacks: _callbacks(
          state: () => const TrayServerState(
            running: true,
            port: 19548,
            enabled: true,
            canLockSession: true,
          ),
          onLockSession: () async {
            lockCalls++;
          },
        ),
        backend: backend,
      );

      await service.initialize();
      service.onTrayMenuItemClick(
        MenuItem(key: TrayMenuKeys.lockSession, label: 'Lock session'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(lockCalls, 1);
    });
  });

  group('TrayService.dispose', () {
    test('removes listener and calls destroy on desktop backend', () async {
      final backend = _CapturingBackend();
      final service = _DesktopTrayService(
        callbacks: _callbacks(
          state: () => const TrayServerState(running: false),
        ),
        backend: backend,
      );

      await service.initialize();
      expect(backend.listeners.length, 1);

      await service.dispose();

      expect(backend.listeners, isEmpty);
      expect(backend.destroyCalls, 1);
    });

    test('runs the optional dispose callback', () async {
      final backend = _CapturingBackend();
      var disposed = false;
      final service = _DesktopTrayService(
        callbacks: _callbacks(
          state: () => const TrayServerState(running: false),
        ),
        backend: backend,
        onDispose: () async {
          disposed = true;
        },
      );

      await service.initialize();
      await service.dispose();

      expect(disposed, isTrue);
    });
  });
}

/// Subclass that forces `isSupported=true` so we can exercise the
/// desktop code paths on a CI host running the unit test on any OS.
class _DesktopTrayService extends TrayService {
  _DesktopTrayService({
    required super.callbacks,
    required super.backend,
    super.onDispose,
  });

  @override
  bool get isSupported => true;
}

/// Subclass that forces `isSupported=false` so we can verify the mobile
/// fallback path even on a desktop CI runner.
class _MobileTrayService extends TrayService {
  _MobileTrayService({required super.callbacks, required super.backend});

  @override
  bool get isSupported => false;
}
