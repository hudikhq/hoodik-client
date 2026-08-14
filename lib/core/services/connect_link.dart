import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/log_redact.dart';
import '../utils/logger.dart';

const _log = Logger('ConnectLink');

/// Server details scanned from the QR code the web drive shows a signed-in
/// user: `hoodik://connect#s=<server-url>&e=<email>`.
///
/// Both values ride in the fragment rather than the query string. A phone
/// with no app installed opens the https form of the same link on hoodik.io,
/// and fragments are never sent in an HTTP request — so the page that catches
/// the scan can't leak which instance the user is on, or who they are.
class ConnectLink {
  const ConnectLink({
    required this.serverUrl,
    this.email,
    this.autoConnect = true,
  });

  final String serverUrl;
  final String? email;

  /// Whether the add-server screen should still connect on its own. Cleared
  /// once it has, so backing out of the login screen doesn't throw the user
  /// straight forward again.
  final bool autoConnect;

  ConnectLink get connected =>
      ConnectLink(serverUrl: serverUrl, email: email, autoConnect: false);

  /// Longest address RFC 5321 permits. Past this the QR is malformed, not
  /// an address worth prefilling.
  static const _maxEmailLength = 254;

  /// Returns null for anything that isn't a well-formed connect link. QR
  /// content is attacker-controlled, so a bad payload has to be inert
  /// rather than a crash or a request to an arbitrary scheme.
  static ConnectLink? parse(Uri uri) {
    if (uri.scheme != 'hoodik' || uri.host != 'connect') return null;

    final Map<String, String> params;
    try {
      params = Uri.splitQueryString(uri.fragment);
    } on FormatException {
      return null;
    }

    final server = Uri.tryParse(params['s'] ?? '');
    if (server == null || server.host.isEmpty) return null;
    if (server.scheme != 'https' && server.scheme != 'http') return null;

    final email = params['e'];
    final usable =
        email != null && email.contains('@') && email.length <= _maxEmailLength;

    return ConnectLink(
      serverUrl: server.toString(),
      email: usable ? email : null,
    );
  }
}

/// Set when a connect link arrives; read by the add-server and login screens
/// to prefill what the user would otherwise have to type.
final pendingConnectProvider = StateProvider<ConnectLink?>((ref) => null);

/// Receives `hoodik://connect` links from the OS, both at cold start and
/// while the app is already running.
class ConnectLinkHandler {
  StreamSubscription<Uri>? _subscription;

  void Function(ConnectLink link)? onLink;

  void init() {
    // The stream replays the link that cold-started the app, so there's no
    // separate initial-link call to make.
    _subscription = AppLinks().uriLinkStream.listen(
      (uri) {
        // Neither line carries the link itself, for the same reason it rides
        // in a fragment. "I scanned it and nothing happened" is answerable
        // from which of the two turned up.
        final link = ConnectLink.parse(uri);
        if (link == null) {
          _log.warn('ignored unrecognised deep link');
          return;
        }
        _log.info(
          'connect link received',
          fields: {'has_email': link.email != null},
        );
        onLink?.call(link);
      },
      onError: (e) => _log.warn(
        'deep link stream error',
        fields: {'error': redactException(e)},
      ),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
