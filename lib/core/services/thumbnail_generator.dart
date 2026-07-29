import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/foundation.dart' as foundation show TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:video_thumbnail/video_thumbnail.dart';

import '../utils/log_redact.dart';
import '../utils/logger.dart';

const _log = Logger('ThumbnailGenerator');

/// Maximum dimension (width or height) for generated thumbnails.
/// Matches the web frontend's IMAGE_THUMBNAIL_SIZE_PX.
const int kThumbnailMaxDimension = 200;

/// MIME types that support image thumbnail generation.
///
/// HEIC/HEIF decode through the platform codec behind
/// `instantiateImageCodec` on Apple platforms and Android 28+; elsewhere
/// the decode throws and generation falls through to null, which is the
/// same "no thumbnail" outcome as not attempting at all.
const Set<String> _imageMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'image/bmp',
  'image/heic',
  'image/heif',
};

/// MIME types that support video thumbnail generation.
const Set<String> _videoMimeTypes = {
  'video/mp4',
  'video/quicktime',
  'video/x-msvideo',
  'video/x-matroska',
  'video/webm',
  'video/ogg',
};

/// Native macOS channel — backed by `VideoThumbnailChannel.swift` which
/// uses `AVAssetImageGenerator` to extract a single PNG-encoded frame.
/// We can't use the `video_thumbnail` package on macOS (no impl), so the
/// macOS app gets its own thin native bridge living next to the
/// existing `io.hoodik.app/window` channel.
const MethodChannel _macThumbnailChannel = MethodChannel(
  'io.hoodik.app/thumbnail',
);

/// Whether the platform can produce a video thumbnail at all.
///
/// On Android + iOS the `video_thumbnail` package handles it.
/// On macOS the app ships its own `VideoThumbnailChannel.swift` impl.
/// Windows / Linux / web have no implementation today — generating
/// there would just throw `MissingPluginException`, so we gate them off
/// here and the upload metadata builder skips the thumbnail entirely
/// rather than producing a noisy log line per video.
bool _videoThumbnailSupportedOnThisPlatform() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == foundation.TargetPlatform.android ||
      defaultTargetPlatform == foundation.TargetPlatform.iOS ||
      defaultTargetPlatform == foundation.TargetPlatform.macOS;
}

/// Returns true if a thumbnail can be generated for the given MIME type
/// on the current platform.
bool canGenerateThumbnail(String mime) {
  final lower = mime.toLowerCase();
  if (_imageMimeTypes.contains(lower)) return true;
  if (_videoMimeTypes.contains(lower)) {
    return _videoThumbnailSupportedOnThisPlatform();
  }
  return false;
}

/// Generate a thumbnail from an image or video file and return it as a
/// base64 data URL.
///
/// Returns `data:image/png;base64,...` or null if generation fails (or
/// is impossible on this platform — e.g. video on macOS, where the
/// `video_thumbnail` package has no implementation).
Future<String?> generateThumbnail(String filePath, String mime) async {
  final lower = mime.toLowerCase();

  if (_videoMimeTypes.contains(lower)) {
    if (!_videoThumbnailSupportedOnThisPlatform()) return null;
    return _generateVideoThumbnail(filePath);
  }

  if (!_imageMimeTypes.contains(lower)) return null;

  return _generateImageThumbnail(filePath);
}

/// Generate a thumbnail from an image file.
///
/// Runs on the main thread because `dart:ui` (instantiateImageCodec) requires
/// the Flutter engine, which is only available on the root isolate. Resizing
/// a 200px thumbnail is fast enough (~5-20ms) to not cause jank.
Future<String?> _generateImageThumbnail(String filePath) async {
  try {
    final bytes = await File(filePath).readAsBytes();

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: kThumbnailMaxDimension,
      targetHeight: kThumbnailMaxDimension,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    codec.dispose();

    if (byteData == null) return null;

    final b64 = base64Encode(byteData.buffer.asUint8List());
    return 'data:image/png;base64,$b64';
  } catch (e) {
    _log.warn(
      'image thumbnail generation failed',
      fields: {'error': describeError(e)},
    );
    return null;
  }
}

/// Generate a thumbnail from a video file by extracting a frame at ~1 second.
///
/// Dispatches by platform:
///   - macOS → custom `VideoThumbnailChannel.swift`
///     (`AVAssetImageGenerator`).
///   - Android / iOS → `video_thumbnail` package
///     (MediaMetadataRetriever / AVAssetImageGenerator respectively).
Future<String?> _generateVideoThumbnail(String filePath) async {
  if (defaultTargetPlatform == foundation.TargetPlatform.macOS) {
    return _generateVideoThumbnailMacOS(filePath);
  }
  try {
    final Uint8List? bytes = await VideoThumbnail.thumbnailData(
      video: filePath,
      imageFormat: ImageFormat.PNG,
      maxWidth: kThumbnailMaxDimension,
      timeMs: 1000,
      quality: 75,
    );

    if (bytes == null || bytes.isEmpty) return null;

    final b64 = base64Encode(bytes);
    return 'data:image/png;base64,$b64';
  } catch (e) {
    _log.warn(
      'video thumbnail generation failed',
      fields: {'error': describeError(e)},
    );
    return null;
  }
}

/// macOS-specific path: hand the file path to the native channel and let
/// AVFoundation extract the frame. Returns null on any failure (the
/// thumbnail is an optional UI nicety — the upload itself doesn't
/// depend on this).
Future<String?> _generateVideoThumbnailMacOS(String filePath) async {
  try {
    final result = await _macThumbnailChannel.invokeMethod<Uint8List>(
      'videoThumbnail',
      {
        'path': filePath,
        'maxDimension': kThumbnailMaxDimension,
        'timeMs': 1000,
      },
    );
    if (result == null || result.isEmpty) return null;
    return 'data:image/png;base64,${base64Encode(result)}';
  } on PlatformException catch (e) {
    _log.warn(
      'macos video thumbnail generation failed',
      fields: {
        'platform_code': e.code,
        'platform_message': e.message,
        'platform_details': describeError(e),
      },
    );
    return null;
  } catch (e) {
    _log.warn(
      'macos video thumbnail generation failed',
      fields: {'error': describeError(e)},
    );
    return null;
  }
}
