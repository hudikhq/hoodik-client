import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/thumbnail_generator.dart';

/// Locks `canGenerateThumbnail`'s platform gate.
///
/// The `video_thumbnail` package only ships Android + iOS implementations
/// — calling it on macOS / Windows / Linux / web throws
/// `MissingPluginException` after dispatching the platform-channel call.
/// The macOS app surfaced this on a real upload of a `.mov` file: the
/// upload succeeded but the log carried a noisy `WARN` per video. The
/// fix is to gate at `canGenerateThumbnail` so the call site in
/// `BinaryUploadMetadata` never even attempts to generate a thumbnail
/// for an unsupported platform.
///
/// Test driver: `debugDefaultTargetPlatformOverride` sets the value
/// `defaultTargetPlatform` returns, no need for actual native context.
void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('canGenerateThumbnail — image MIME types', () {
    test('always supported on every platform — image decode is pure '
        'dart:ui and has no platform plugin dependency', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        for (final mime in const [
          'image/jpeg',
          'image/png',
          'image/gif',
          'image/webp',
          'image/bmp',
          'image/heic',
          'image/heif',
        ]) {
          expect(
            canGenerateThumbnail(mime),
            isTrue,
            reason:
                'image thumbnails should be supported everywhere — '
                '$platform / $mime came back false',
          );
        }
      }
    });

    test('case-insensitive on the MIME string', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(canGenerateThumbnail('IMAGE/JPEG'), isTrue);
      expect(canGenerateThumbnail('Image/Png'), isTrue);
    });
  });

  group('canGenerateThumbnail — video MIME types', () {
    test('Android → true (video_thumbnail ships an Android impl)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(canGenerateThumbnail('video/quicktime'), isTrue);
      expect(canGenerateThumbnail('video/mp4'), isTrue);
    });

    test('iOS → true (video_thumbnail ships an iOS impl)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(canGenerateThumbnail('video/mp4'), isTrue);
      expect(canGenerateThumbnail('video/x-matroska'), isTrue);
    });

    test('macOS → true (the app ships its own native AVAssetImageGenerator '
        'channel — see macos/Runner/VideoThumbnailChannel.swift)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(
        canGenerateThumbnail('video/quicktime'),
        isTrue,
        reason:
            'macOS got a native bridge so .mov uploads from the macOS '
            'app produce thumbnails instead of just logging '
            'MissingPluginException',
      );
      expect(canGenerateThumbnail('video/mp4'), isTrue);
      expect(canGenerateThumbnail('video/webm'), isTrue);
    });

    test('Windows / Linux / Fuchsia → false (no video_thumbnail impl)', () {
      for (final platform in const [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          canGenerateThumbnail('video/mp4'),
          isFalse,
          reason: '$platform should not attempt video thumbnails',
        );
      }
    });
  });

  group('canGenerateThumbnail — unsupported MIME types', () {
    test('PDFs, plaintext, audio etc. → false on every platform', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        for (final mime in const [
          'application/pdf',
          'text/plain',
          'text/markdown',
          'audio/mpeg',
          'application/octet-stream',
          '',
        ]) {
          expect(
            canGenerateThumbnail(mime),
            isFalse,
            reason: '$platform / $mime should not claim support',
          );
        }
      }
    });
  });
}
