import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../utils/logger.dart';

const _log = Logger('ConnectivityService');

/// Monitors network connectivity and notifies listeners on change.
///
/// Uses the `connectivity_plus` package. Does NOT test actual server
/// reachability — only whether a network interface is available.
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true; // optimistic default

  bool get isOnline => _isOnline;

  /// Callback invoked when connectivity transitions from offline to online.
  VoidCallback? onReconnected;

  /// Start listening for connectivity changes.
  void init() {
    _connectivity.checkConnectivity().then(_handleResult);
    _subscription = _connectivity.onConnectivityChanged.listen(_handleResult);
  }

  void _handleResult(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((r) => r != ConnectivityResult.none);

    _log.info(
      'connectivity change',
      fields: {
        'online': _isOnline,
        'results': results.map((r) => r.name).toList(),
      },
    );

    if (!wasOnline && _isOnline) {
      onReconnected?.call();
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
