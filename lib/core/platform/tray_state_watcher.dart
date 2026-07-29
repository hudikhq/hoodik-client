import 'dart:async';

/// Immutable snapshot of the tray-relevant server state.
class TrayObservedState {
  final bool running;
  final int? port;

  const TrayObservedState({required this.running, this.port});

  @override
  bool operator ==(Object other) =>
      other is TrayObservedState &&
      other.running == running &&
      other.port == port;

  @override
  int get hashCode => Object.hash(running, port);
}

/// Polls a state reader and invokes [onChanged] when the observed value
/// changes, including when a long-lived object mutates internally without
/// notifying Riverpod/listeners.
class TrayStateWatcher {
  final TrayObservedState Function() _readState;
  final Future<void> Function(TrayObservedState state) _onChanged;
  final Duration _interval;

  Timer? _timer;
  TrayObservedState? _lastState;
  bool _refreshInFlight = false;

  TrayStateWatcher({
    required TrayObservedState Function() readState,
    required Future<void> Function(TrayObservedState state) onChanged,
    Duration interval = const Duration(milliseconds: 300),
  }) : _readState = readState,
       _onChanged = onChanged,
       _interval = interval;

  bool get isRunning => _timer != null;

  void start() {
    if (_timer != null) return;
    _lastState = _readState();
    _timer = Timer.periodic(_interval, (_) async {
      final next = _readState();
      if (next == _lastState || _refreshInFlight) return;
      _lastState = next;
      _refreshInFlight = true;
      try {
        await _onChanged(next);
      } finally {
        _refreshInFlight = false;
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
