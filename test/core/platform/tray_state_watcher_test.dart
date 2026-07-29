import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/platform/tray_state_watcher.dart';

void main() {
  group('TrayStateWatcher', () {
    test('does not refresh when state stays unchanged', () async {
      var refreshCalls = 0;
      const state = TrayObservedState(running: false);

      final watcher = TrayStateWatcher(
        readState: () => state,
        onChanged: (_) async {
          refreshCalls++;
        },
        interval: const Duration(milliseconds: 25),
      );

      watcher.start();
      await Future<void>.delayed(const Duration(milliseconds: 90));
      watcher.stop();

      expect(refreshCalls, 0);
    });

    test('refreshes when running flips from off to on', () async {
      var refreshCalls = 0;
      var state = const TrayObservedState(running: false);

      final watcher = TrayStateWatcher(
        readState: () => state,
        onChanged: (_) async {
          refreshCalls++;
        },
        interval: const Duration(milliseconds: 25),
      );

      watcher.start();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      state = const TrayObservedState(running: true, port: 19548);

      await Future<void>.delayed(const Duration(milliseconds: 90));
      watcher.stop();

      expect(refreshCalls, 1);
    });

    test('refreshes when port changes while still running', () async {
      var refreshCalls = 0;
      var state = const TrayObservedState(running: true, port: 19548);

      final watcher = TrayStateWatcher(
        readState: () => state,
        onChanged: (_) async {
          refreshCalls++;
        },
        interval: const Duration(milliseconds: 25),
      );

      watcher.start();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      state = const TrayObservedState(running: true, port: 19600);

      await Future<void>.delayed(const Duration(milliseconds: 90));
      watcher.stop();

      expect(refreshCalls, 1);
    });

    test('stops polling after stop', () async {
      var refreshCalls = 0;
      var state = const TrayObservedState(running: false);

      final watcher = TrayStateWatcher(
        readState: () => state,
        onChanged: (_) async {
          refreshCalls++;
        },
        interval: const Duration(milliseconds: 25),
      );

      watcher.start();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      watcher.stop();

      state = const TrayObservedState(running: true, port: 19548);
      await Future<void>.delayed(const Duration(milliseconds: 90));

      expect(refreshCalls, 0);
    });

    test('passes the new state to onChanged', () async {
      final seenStates = <TrayObservedState>[];
      var state = const TrayObservedState(running: false);

      final watcher = TrayStateWatcher(
        readState: () => state,
        onChanged: (next) async {
          seenStates.add(next);
        },
        interval: const Duration(milliseconds: 25),
      );

      watcher.start();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      state = const TrayObservedState(running: true, port: 19548);
      await Future<void>.delayed(const Duration(milliseconds: 90));
      watcher.stop();

      expect(
        seenStates,
        equals([const TrayObservedState(running: true, port: 19548)]),
      );
    });

    test('start is idempotent', () async {
      var refreshCalls = 0;
      var state = const TrayObservedState(running: false);

      final watcher = TrayStateWatcher(
        readState: () => state,
        onChanged: (_) async {
          refreshCalls++;
        },
        interval: const Duration(milliseconds: 25),
      );

      watcher.start();
      watcher.start();

      await Future<void>.delayed(const Duration(milliseconds: 40));
      state = const TrayObservedState(running: true, port: 19548);

      await Future<void>.delayed(const Duration(milliseconds: 90));
      watcher.stop();

      expect(refreshCalls, 1);
    });
  });
}
