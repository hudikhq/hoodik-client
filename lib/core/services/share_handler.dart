import 'dart:async';
import 'dart:io';

import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';

import '../utils/log_redact.dart';
import '../utils/logger.dart';

const _log = Logger('ShareHandler');

/// Handles incoming file shares from other apps (mobile only).
///
/// On Android: receives files via intent filters (SEND / SEND_MULTIPLE).
/// On iOS: receives files shared via the system share sheet.
///
/// Usage:
/// 1. Create an instance and set [onFilesReceived].
/// 2. Call [init] after the Flutter binding is ready (on mobile only).
/// 3. The callback fires whenever files are shared into the app.
/// 4. Call [dispose] when the handler is no longer needed.
class ShareHandler {
  StreamSubscription<List<SharedFile>>? _subscription;

  /// Called when one or more files are received via a share intent.
  /// The list contains absolute file paths.
  void Function(List<String> paths)? onFilesReceived;

  /// Initialize the share handler. No-op on desktop platforms.
  void init() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // Handle files shared at cold start (app wasn't running).
    FlutterSharingIntent.instance
        .getInitialSharing()
        .then(_handleMedia)
        .catchError((e) {
          _log.warn(
            'share intent initial media error',
            fields: {'error': redactException(e)},
          );
        });

    // Handle files shared while the app is already running (warm start).
    _subscription = FlutterSharingIntent.instance.getMediaStream().listen(
      _handleMedia,
      onError: (e) {
        _log.warn(
          'share intent stream error',
          fields: {'error': redactException(e)},
        );
      },
    );
  }

  void _handleMedia(List<SharedFile> media) {
    if (media.isEmpty) return;

    final paths = media
        .map((m) => m.value)
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toList();

    if (paths.isEmpty) return;

    _log.info('received shared files', fields: {'count': paths.length});

    onFilesReceived?.call(paths);

    // Reset so the same intent isn't processed again on next getInitialSharing.
    FlutterSharingIntent.instance.reset();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
