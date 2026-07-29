import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/services/transfer_manager.dart';
import '../../../core/utils/logger.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/preview_loader.dart';
import 'preview_loading.dart';

const _log = Logger('PreviewVideo');

/// Video preview — downloads, decrypts, plays with media_kit (FFmpeg backend).
///
/// Uses media_kit instead of video_player for broad codec support including
/// MKV (Matroska), H.265/HEVC, and other formats that AVFoundation doesn't
/// handle natively on iOS/macOS.
///
/// The playback chrome (play/pause, seek, fullscreen, speed, volume, subtitle
/// track) is handled by media_kit's [AdaptiveVideoControls] — Material on
/// Android/iOS, MaterialDesktop on macOS/Windows/Linux — which ships with a
/// built-in fullscreen button that pushes its own route and manages
/// orientation + immersive system UI on its own.
class PreviewVideo extends ConsumerStatefulWidget {
  final FileItem file;
  final String fileName;
  final Uint8List? fileKey;

  const PreviewVideo({
    super.key,
    required this.file,
    required this.fileName,
    this.fileKey,
  });

  @override
  ConsumerState<PreviewVideo> createState() => _PreviewVideoState();
}

class _PreviewVideoState extends ConsumerState<PreviewVideo> {
  Player? _player;
  VideoController? _videoController;
  bool _downloading = true;
  String? _error;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  String _extensionFromMime(String mime) {
    const map = {
      'video/mp4': 'mp4',
      'video/quicktime': 'mov',
      'video/webm': 'webm',
      'video/x-msvideo': 'avi',
      'video/x-matroska': 'mkv',
    };
    return map[mime.toLowerCase()] ?? 'mp4';
  }

  Future<void> _loadVideo() async {
    final ext = _extensionFromMime(widget.file.mime);

    try {
      final path = await loadPreviewPath(
        ref,
        widget.file,
        widget.fileKey,
        ext,
        displayName: widget.fileName,
      );

      if (!mounted) return;

      if (path == null) {
        setState(() {
          _error = AppLocalizations.of(context).previewCannotDecrypt;
          _downloading = false;
        });
        return;
      }

      await _initPlayer(path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _downloading = false;
        });
      }
    }
  }

  Future<void> _initPlayer(String path) async {
    try {
      final player = Player();
      final controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          // Wait for video parameters before attaching the Android Surface.
          // Without this, the surface can be attached before MPV knows the
          // video dimensions, which causes blank video on many Android devices.
          androidAttachSurfaceAfterVideoParameters: true,
        ),
      );

      _subscriptions.addAll([
        player.stream.error.listen((error) {
          if (error.isEmpty) return;
          _log.warn('media_kit player error', fields: {'error_message': error});
          if (mounted) setState(() => _error = error);
        }),
        player.stream.log.listen((log) {
          if (log.level == 'error' || log.level == 'fatal') {
            _log.warn(
              'media_kit diagnostic',
              fields: {
                'level': log.level,
                'prefix': log.prefix,
                'text': log.text,
              },
            );
          }
        }),
      ]);

      if (!mounted) {
        await player.dispose();
        return;
      }

      // Mount the Video widget BEFORE opening media. On Android, the
      // AndroidVideoController sets vo=null when no native Surface exists
      // (wid == 0). If player.open() runs before the Video widget mounts,
      // MPV starts decoding with no video output and MP4 never renders.
      setState(() {
        _player = player;
        _videoController = controller;
        _downloading = false;
      });

      // Wait for the next frame to be drawn so the Video widget has actually
      // laid out and created its native Surface / texture. `Future.delayed
      // (zero)` only flushes microtasks — Flutter's frame pipeline runs
      // afterwards, so the surface may not exist yet when player.open fires.
      await WidgetsBinding.instance.endOfFrame;

      if (!mounted) {
        await player.dispose();
        return;
      }

      await player.open(Media(path));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _downloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_downloading) {
      final manager = ref.watch(transferManagerProvider);
      final transfer = manager.transfers
          .where(
            (t) =>
                t.fileId == widget.file.id && t.status == TransferStatus.active,
          )
          .firstOrNull;

      return PreviewLoading(
        progress: transfer?.progress,
        stage: transfer?.type.label,
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final controller = _videoController;
    if (controller == null) {
      return const PreviewLoading();
    }

    // Bottom-only SafeArea: the preview screen runs under `edgeToEdge`
    // system UI, which lets the Video widget extend under the iOS home
    // indicator. AdaptiveVideoControls anchors its button bar to the
    // widget's bottom, so without this inset the seek/fullscreen/time
    // row sits half under the indicator and is hard to tap.
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Video(
        controller: controller,
        controls: AdaptiveVideoControls,
        onEnterFullscreen: _onEnterFullscreen,
        onExitFullscreen: _onExitFullscreen,
      ),
    );
  }

  /// Fullscreen entry that respects device rotation.
  ///
  /// media_kit's default locks the device to `[landscapeLeft, landscapeRight]`,
  /// so once the video enters fullscreen the user can't rotate back to
  /// portrait. We mirror the immersive system UI side of the default but
  /// allow every orientation the app supports — the phone then follows
  /// the accelerometer in either direction.
  Future<void> _onEnterFullscreen() async {
    await Future.wait([
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: const [],
      ),
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    ]);
  }

  /// Restore the default system UI + clear orientation preferences so the
  /// host app's Info.plist supported-orientations list takes over again.
  Future<void> _onExitFullscreen() async {
    await Future.wait([
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      ),
      SystemChrome.setPreferredOrientations(const []),
    ]);
  }
}
