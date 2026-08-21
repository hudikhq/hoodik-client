import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One selected asset, announced the moment the picker sheet closes —
/// before its bytes exist anywhere we can read them.
class PickedMediaItem {
  final int index;
  final String name;

  const PickedMediaItem({required this.index, required this.name});
}

sealed class MediaPickEvent {
  const MediaPickEvent();
}

/// The sheet is gone; [items] is what the user chose (empty = cancelled).
class MediaPickSelection extends MediaPickEvent {
  final List<PickedMediaItem> items;

  const MediaPickSelection(this.items);
}

/// Export/download progress for one item, 0.0–1.0.
class MediaPickProgress extends MediaPickEvent {
  final int index;
  final double fraction;

  const MediaPickProgress({required this.index, required this.fraction});
}

/// The item's file is in our container, ready to upload.
class MediaPickReady extends MediaPickEvent {
  final int index;
  final String path;

  const MediaPickReady({required this.index, required this.path});
}

class MediaPickFailed extends MediaPickEvent {
  final int index;
  final String message;

  const MediaPickFailed({required this.index, required this.message});
}

/// Bridge to the native Photos picker that reports per-item load progress.
///
/// The plugin picker's future only completes once every asset is exported,
/// with nothing to show meanwhile. The native side returns the selection
/// immediately and streams each item's export as it happens, so the
/// transfer overlay can carry the wait — see MediaPickerChannel.swift for
/// the event contract. The stream closes after the last item settles.
class MediaPickerChannel {
  static const _method = MethodChannel('io.hoodik.app/media_picker');
  static const _events = EventChannel('io.hoodik.app/media_picker/events');

  /// Only iOS prepares assets asynchronously; everywhere else the plugin
  /// picker returns real paths immediately and stays in use. Overridable
  /// so tests can exercise the channel flow on the host platform.
  @visibleForTesting
  static bool? supportedOverride;

  static bool get isSupported =>
      supportedOverride ?? (!kIsWeb && Platform.isIOS);

  Stream<MediaPickEvent> pickMedia() {
    final controller = StreamController<MediaPickEvent>();
    late StreamSubscription<dynamic> subscription;

    Future<void> close() async {
      await subscription.cancel();
      await controller.close();
    }

    subscription = _events.receiveBroadcastStream().listen(
      (raw) {
        final event = _parse(raw);
        if (event != null) {
          controller.add(event);
        } else if (raw is Map && raw['type'] == 'done') {
          close();
        }
      },
      onError: controller.addError,
      onDone: () => close(),
    );

    _method.invokeMethod<bool>('pick').catchError((Object e) {
      controller.addError(e);
      close();
      return false;
    });

    return controller.stream;
  }

  static MediaPickEvent? _parse(dynamic raw) {
    if (raw is! Map) return null;
    switch (raw['type']) {
      case 'picked':
        final items = (raw['items'] as List? ?? const [])
            .cast<Map>()
            .map(
              (m) => PickedMediaItem(
                index: m['index'] as int,
                name: m['name'] as String,
              ),
            )
            .toList();
        return MediaPickSelection(items);
      case 'progress':
        return MediaPickProgress(
          index: raw['index'] as int,
          fraction: (raw['fraction'] as num).toDouble(),
        );
      case 'ready':
        return MediaPickReady(
          index: raw['index'] as int,
          path: raw['path'] as String,
        );
      case 'failed':
        return MediaPickFailed(
          index: raw['index'] as int,
          message: raw['message'] as String? ?? 'load failed',
        );
      default:
        return null;
    }
  }
}
