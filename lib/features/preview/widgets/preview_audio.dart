import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/services/transfer_manager.dart';
import '../../../core/utils/logger.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/preview_loader.dart';
import '../services/preview_stream_resolver.dart';
import 'preview_loading.dart';
import '../../../core/theme/hoodik_scheme.dart';

const _log = Logger('PreviewAudio');

class PreviewAudio extends ConsumerStatefulWidget {
  final FileItem file;
  final String fileName;
  final Uint8List? fileKey;

  const PreviewAudio({
    super.key,
    required this.file,
    required this.fileName,
    this.fileKey,
  });

  @override
  ConsumerState<PreviewAudio> createState() => _PreviewAudioState();
}

class _PreviewAudioState extends ConsumerState<PreviewAudio> {
  Player? _player;

  PreviewStreamHandle? _stream;

  final List<StreamSubscription<dynamic>> _subs = [];

  bool _loading = true;
  bool _playing = false;
  bool _buffering = false;
  bool _seeking = false;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _player?.dispose();
    unawaited(_stream?.release());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final Media media;
      final prefetched = ref.read(previewCacheProvider).get(widget.file);
      final stream = prefetched != null
          ? null
          : await openPreviewStream(
              ref,
              file: widget.file,
              fileKey: widget.fileKey,
              fileName: widget.fileName,
            );

      if (prefetched != null) {
        media = await Media.memory(prefetched);
      } else if (stream != null) {
        _stream = stream;
        media = Media(stream.uri.toString());
      } else {
        final bytes = await loadPreviewBytes(
          ref,
          widget.file,
          widget.fileKey,
          displayName: widget.fileName,
        );
        if (!mounted) return;
        if (bytes == null) {
          setState(() {
            _error = AppLocalizations.of(context).previewCannotDecrypt;
            _loading = false;
          });
          return;
        }
        media = await Media.memory(bytes);
      }

      if (!mounted) return;

      final player = Player();
      _player = player;
      _subs.addAll([
        player.stream.position.listen((position) {
          if (mounted && !_seeking) setState(() => _position = position);
        }),
        player.stream.duration.listen((duration) {
          if (mounted) setState(() => _duration = duration);
        }),
        player.stream.playing.listen((playing) {
          if (mounted) setState(() => _playing = playing);
        }),
        player.stream.buffering.listen((buffering) {
          if (mounted) setState(() => _buffering = buffering);
        }),
        player.stream.completed.listen((completed) {
          if (mounted && completed) {
            setState(() {
              _position = _duration;
              _playing = false;
            });
          }
        }),
        player.stream.error.listen((error) {
          if (error.isEmpty) return;
          _log.warn('media_kit audio error', fields: {'error_message': error});
          if (mounted) setState(() => _error = error);
        }),
      ]);

      setState(() => _loading = false);
      await player.open(media);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _seekRelative(int seconds) {
    final player = _player;
    if (player == null) return;
    var target = _position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    player.seek(target);
  }

  static String _format(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final minutes = (totalSeconds ~/ 60) % 60;
    if (duration.inHours > 0) {
      return '${duration.inHours}:${minutes.toString().padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
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

    final colors = context.colors;
    final durationMs = _duration.inMilliseconds;
    final positionMs = durationMs <= 0
        ? 0
        : _position.inMilliseconds.clamp(0, durationMs);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.recess,
                    border: Border.all(color: colors.seam),
                  ),
                  child: Icon(
                    Icons.music_note,
                    size: 56,
                    color: colors.iconEmber,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: colors.iconEmber,
                    thumbColor: colors.iconEmber,
                    inactiveTrackColor: colors.track,
                    overlayColor: colors.iconEmber.withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    value: positionMs.toDouble(),
                    max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                    onChanged: durationMs <= 0
                        ? null
                        : (value) {
                            setState(() {
                              _seeking = true;
                              _position = Duration(milliseconds: value.round());
                            });
                          },
                    onChangeEnd: durationMs <= 0
                        ? null
                        : (value) {
                            _seeking = false;
                            _player?.seek(
                              Duration(milliseconds: value.round()),
                            );
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _format(_position),
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        durationMs <= 0 ? '--:--' : _format(_duration),
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_buffering)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.iconEmber,
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 36,
                      color: colors.text,
                      onPressed: () => _seekRelative(-10),
                      icon: const Icon(Icons.replay_10),
                    ),
                    const SizedBox(width: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.emberFill,
                      ),
                      child: IconButton(
                        iconSize: 40,
                        color: colors.onEmberFill,
                        onPressed: () => _player?.playOrPause(),
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      iconSize: 36,
                      color: colors.text,
                      onPressed: () => _seekRelative(10),
                      icon: const Icon(Icons.forward_10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
