import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/preview_providers.dart';
import '../widgets/preview_toolbar.dart';
import '../widgets/preview_unsupported.dart';
import '../widgets/preview_image.dart';
import '../widgets/preview_video.dart';
import '../widgets/preview_pdf.dart';
import '../widgets/preview_text.dart';

/// Full-screen file preview with gallery navigation.
class PreviewScreen extends ConsumerStatefulWidget {
  final String fileId;

  const PreviewScreen({super.key, required this.fileId});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  late List<FileItem> _files;
  late Map<String, String> _names;
  late Map<String, Uint8List> _keys;
  late PageController _pageController;
  late int _currentIndex;

  bool _toolbarVisible = true;
  Timer? _hideTimer;

  /// Vertical drag offset for swipe-down-to-dismiss.
  double _dragOffset = 0;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    final ctx = ref.read(previewContextProvider);
    _files = List.of(ctx?.files ?? []);
    _names = Map.of(ctx?.names ?? {});
    _keys = Map.of(ctx?.keys ?? {});

    _currentIndex = _files.indexWhere((f) => f.id == widget.fileId);
    if (_currentIndex < 0) _currentIndex = 0;

    _pageController = PageController(initialPage: _currentIndex);

    // Set immersive UI — transparent status bar, edge-to-edge
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _resetHideTimer();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pageController.dispose();
    _focusNode.dispose();

    // Restore the platform default chrome — status bar and nav bar visible.
    // The immersive mode set in initState (edgeToEdge) hides overlays behind
    // the content; leaving it set on dispose would leak the hidden state to
    // every screen the user navigates back to.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  void _toggleToolbar() {
    setState(() => _toolbarVisible = !_toolbarVisible);
    if (_toolbarVisible) {
      _resetHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (_currentIsVideo()) {
      // Pin toolbar on video — media_kit draws its own chrome inside the
      // Video widget; auto-hiding ours would strip the back/download/delete
      // affordances with no way to get them back.
      if (!_toolbarVisible && mounted) {
        setState(() => _toolbarVisible = true);
      }
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toolbarVisible = false);
    });
  }

  bool _currentIsVideo() {
    if (_files.isEmpty) return false;
    return getPreviewType(
          _currentFile.mime,
          fileName: _displayName(_currentFile),
        ) ==
        PreviewType.video;
  }

  FileItem get _currentFile => _files[_currentIndex];

  String _displayName(FileItem file) {
    return _names[file.id] ?? file.id.substring(0, 8);
  }

  void _close() {
    context.pop();
  }

  Future<void> _download() async {
    final file = _currentFile;
    final ops = ref.read(fileOperationsProvider);
    final fileKey = _keys[file.id];
    if (ops == null || fileKey == null) return;

    final fileName = _displayName(file);
    final isMobile = Platform.isIOS || Platform.isAndroid;

    // Capture the share popover origin now, before the async download.
    // iPad requires this for the share sheet popover positioning.
    final shareOrigin = _shareOriginRect();

    String savePath;
    if (isMobile) {
      // On mobile (iOS & Android): download to temp, then open share sheet.
      final tmpDir = await getTemporaryDirectory();
      savePath = p.join(tmpDir.path, fileName);
    } else {
      // On desktop: show a save-file dialog.
      final picked = await FilePicker.platform.saveFile(
        dialogTitle: AppLocalizations.of(context).previewSaveFileTitle,
        fileName: fileName,
      );
      if (picked == null) return; // user dismissed the save dialog — cancel
      savePath = picked;
    }

    ops.downloadFileToDisk(
      file,
      fileKey: fileKey,
      outputPath: savePath,
      displayName: fileName,
      onComplete: isMobile
          ? () async {
              final xFile = XFile(savePath, name: fileName);
              await Share.shareXFiles([
                xFile,
              ], sharePositionOrigin: shareOrigin);
              try {
                await File(savePath).delete();
              } catch (_) {}
            }
          : null,
    );
  }

  /// Build a [Rect] for the share sheet popover origin (required on iPad).
  Rect _shareOriginRect() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final position = box.localToGlobal(Offset.zero);
      return position & box.size;
    }
    // Fallback: screen center.
    final size = MediaQuery.of(context).size;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 0,
      height: 0,
    );
  }

  Future<void> _delete() async {
    final file = _currentFile;
    final ops = ref.read(fileOperationsProvider);
    if (ops == null) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.previewDeleteFileTitle),
        content: Text(l10n.previewDeleteFileBody(_displayName(file))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: HoodikColors.textCrimson,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ops.delete(file.id);
    } catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          message: l10n.previewDeleteFailed('$e'),
          type: NotificationType.error,
        );
      }
      return;
    }

    // Remove from preview cache
    ref.read(previewCacheProvider).remove(file.id);

    // Remove from list and navigate
    setState(() {
      _files.removeAt(_currentIndex);
      _names.remove(file.id);
      _keys.remove(file.id);
    });

    if (_files.isEmpty) {
      _close();
      return;
    }

    if (_currentIndex >= _files.length) {
      _currentIndex = _files.length - 1;
    }
    _pageController.jumpToPage(_currentIndex);
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_currentIndex > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_currentIndex < _files.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_files.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            AppLocalizations.of(context).previewNoPreviewableFiles,
            style: const TextStyle(color: HoodikColors.textMuted),
          ),
        ),
      );
    }

    final file = _currentFile;

    // Only enable swipe-down-to-dismiss for types that don't scroll
    // vertically (image, video). PDF and text need vertical gestures
    // for their own scrolling; future types default to no dismiss.
    final currentType = getPreviewType(file.mime, fileName: _displayName(file));
    final allowDismiss =
        currentType == PreviewType.image || currentType == PreviewType.video;

    // Swipe-down-to-dismiss: fade out and translate as the user drags.
    final screenHeight = MediaQuery.of(context).size.height;
    final dismissProgress = (_dragOffset / (screenHeight * 0.25)).clamp(
      0.0,
      1.0,
    );
    final opacity = 1.0 - dismissProgress * 0.5;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: opacity),
        body: GestureDetector(
          onVerticalDragUpdate: allowDismiss
              ? (details) {
                  // Only track downward drags.
                  final newOffset = _dragOffset + details.delta.dy;
                  if (newOffset >= 0) {
                    setState(() => _dragOffset = newOffset);
                  }
                }
              : null,
          onVerticalDragEnd: allowDismiss
              ? (details) {
                  const dismissThreshold = 120.0;
                  if (_dragOffset > dismissThreshold ||
                      details.velocity.pixelsPerSecond.dy > 800) {
                    _close();
                  } else {
                    setState(() => _dragOffset = 0);
                  }
                }
              : null,
          child: Stack(
            children: [
              // Page view for gallery swiping — translated by drag offset
              Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: GestureDetector(
                    // Video pages defer to media_kit's own tap-to-toggle-controls
                    // handler; swallowing the tap here would leave the chrome
                    // hidden after it auto-hides, with no way to get it back.
                    onTap: currentType == PreviewType.video
                        ? null
                        : _toggleToolbar,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _files.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                          _dragOffset = 0;
                        });
                        _resetHideTimer();
                      },
                      itemBuilder: (context, index) {
                        return _buildPreviewPage(_files[index]);
                      },
                    ),
                  ),
                ),
              ),

              // Toolbar overlay
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: PreviewToolbar(
                  fileName: _displayName(file),
                  currentIndex: _currentIndex,
                  totalCount: _files.length,
                  visible:
                      (_toolbarVisible || currentType == PreviewType.video) &&
                      _dragOffset == 0,
                  onClose: _close,
                  onDownload: _download,
                  onDelete: _delete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewPage(FileItem file) {
    final fileName = _displayName(file);
    final type = getPreviewType(file.mime, fileName: fileName);
    final fileKey = _keys[file.id];

    switch (type) {
      case PreviewType.image:
        return PreviewImage(file: file, fileName: fileName, fileKey: fileKey);
      case PreviewType.video:
        return PreviewVideo(file: file, fileName: fileName, fileKey: fileKey);
      case PreviewType.pdf:
        return PreviewPdf(file: file, fileName: fileName, fileKey: fileKey);
      case PreviewType.markdown:
      // Markdown files open in the dedicated NoteEditorScreen — they
      // shouldn't reach the preview. Fall through to text as a safety net.
      case PreviewType.text:
        return PreviewText(file: file, fileName: fileName, fileKey: fileKey);
      case PreviewType.unsupported:
        return PreviewUnsupported(
          fileName: fileName,
          mime: file.mime,
          onDownload: _download,
        );
    }
  }
}
