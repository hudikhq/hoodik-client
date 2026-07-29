import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/services/thumbnail_loader.dart';
import '../../../core/services/transfer_manager.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/preview_loader.dart';
import 'preview_loading.dart';

/// Image preview with thumbnail-first loading and pinch-to-zoom.
class PreviewImage extends ConsumerStatefulWidget {
  final FileItem file;
  final String fileName;
  final Uint8List? fileKey;

  const PreviewImage({
    super.key,
    required this.file,
    required this.fileName,
    this.fileKey,
  });

  @override
  ConsumerState<PreviewImage> createState() => _PreviewImageState();
}

class _PreviewImageState extends ConsumerState<PreviewImage> {
  Uint8List? _thumbnailBytes;
  Uint8List? _fullBytes;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
    _loadFullImage();
  }

  /// Resolve the thumbnail for immediate display while the full image
  /// downloads — from the loader's cache, the offline store, or the
  /// thumbnail route.
  Future<void> _loadThumbnail() async {
    final fileKey = widget.fileKey;
    if (fileKey == null) return;

    try {
      final bytes = await ref
          .read(thumbnailLoaderProvider)
          .loadBytes(widget.file, fileKey);
      if (bytes == null || !mounted || _fullBytes != null) return;
      setState(() => _thumbnailBytes = bytes);
    } catch (_) {
      // Thumbnail is cosmetic — the full image is on its way.
    }
  }

  Future<void> _loadFullImage() async {
    setState(() => _loading = true);

    try {
      final bytes = await loadPreviewBytes(
        ref,
        widget.file,
        widget.fileKey,
        'jpg',
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

      setState(() {
        _fullBytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Full image loaded — show with zoom.
    //
    // Scale range tuned for "photo-app" feel: allow a small pinch-out past
    // contained so the gesture has the rubber-band give users expect, and
    // let zoom-in go to a fixed 6× for inspecting detail (the default
    // `covered * 3` clipped out too early on wide-aspect images).
    //
    // `tightMode` shrinks the gesture-receiving area to the image bounds so
    // horizontal drags on the black letterbox margins still belong to the
    // parent PageView and swipe between images — without it, users hitting
    // the side bars can't advance the gallery.
    //
    // `filterQuality: medium` keeps the bitmap sharp while zoomed without the
    // extra per-frame cost of `high`, which on decoded-in-memory images was
    // noticeably slower on mid-range phones.
    if (_fullBytes != null) {
      return PhotoView(
        imageProvider: MemoryImage(_fullBytes!),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained * 0.85,
        maxScale: PhotoViewComputedScale.contained * 6.0,
        initialScale: PhotoViewComputedScale.contained,
        basePosition: Alignment.center,
        tightMode: true,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, e, s) => _buildFallback(),
      );
    }

    // Loading — show thumbnail + progress from TransferManager
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
        thumbnailBytes: _thumbnailBytes,
      );
    }

    // Error — show thumbnail or error message
    if (_error != null) {
      return _buildFallback();
    }

    return const PreviewLoading();
  }

  Widget _buildFallback() {
    if (_thumbnailBytes != null) {
      return Center(
        child: Image.memory(
          _thumbnailBytes!,
          fit: BoxFit.contain,
          errorBuilder: (_, e, s) => _buildErrorMessage(),
        ),
      );
    }
    return _buildErrorMessage();
  }

  Widget _buildErrorMessage() {
    return Center(
      child: Text(
        _error ?? AppLocalizations.of(context).previewFailedToLoadImage,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}
