import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/services/transfer_manager.dart';
import '../../../core/utils/format.dart' as fmt;
import '../../../core/theme/hoodik_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/preview_loader.dart';
import 'preview_loading.dart';

/// Max bytes to decode for text preview (1 MB).
const int _kMaxTextBytes = 1024 * 1024;

/// Text/code file preview — monospace, scrollable, selectable.
class PreviewText extends ConsumerStatefulWidget {
  final FileItem file;
  final String fileName;
  final Uint8List? fileKey;

  const PreviewText({
    super.key,
    required this.file,
    required this.fileName,
    this.fileKey,
  });

  @override
  ConsumerState<PreviewText> createState() => _PreviewTextState();
}

class _PreviewTextState extends ConsumerState<PreviewText> {
  String? _text;
  bool _truncated = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadText();
  }

  Future<void> _loadText() async {
    try {
      final bytes = await loadPreviewBytes(
        ref,
        widget.file,
        widget.fileKey,
        'txt',
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

      _decodeAndShow(bytes);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _decodeAndShow(Uint8List bytes) {
    Uint8List toDecode = bytes;
    bool truncated = false;
    if (bytes.length > _kMaxTextBytes) {
      toDecode = bytes.sublist(0, _kMaxTextBytes);
      truncated = true;
    }

    // Try UTF-8 first, fall back to Latin-1
    String text;
    try {
      text = utf8.decode(toDecode, allowMalformed: true);
    } catch (_) {
      text = latin1.decode(toDecode);
    }

    if (mounted) {
      setState(() {
        _text = text;
        _truncated = truncated;
        _loading = false;
      });
    }
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

    return SafeArea(
      child: Column(
        children: [
          if (_truncated)
            Container(
              width: double.infinity,
              color: HoodikColors.brownish700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                AppLocalizations.of(
                  context,
                ).previewShowingFirstMb(fmt.formatBytes(widget.file.size ?? 0)),
                style: const TextStyle(
                  color: HoodikColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _text ?? '',
                style: const TextStyle(
                  color: HoodikColors.dirtyWhite,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
