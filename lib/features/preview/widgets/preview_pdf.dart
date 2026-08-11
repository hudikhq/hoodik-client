import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/services/transfer_manager.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/preview_loader.dart';
import 'preview_loading.dart';

/// PDF preview — downloads, writes to temp file, renders with pdfx.
class PreviewPdf extends ConsumerStatefulWidget {
  final FileItem file;
  final String fileName;
  final Uint8List? fileKey;

  const PreviewPdf({
    super.key,
    required this.file,
    required this.fileName,
    this.fileKey,
  });

  @override
  ConsumerState<PreviewPdf> createState() => _PreviewPdfState();
}

class _PreviewPdfState extends ConsumerState<PreviewPdf> {
  PdfControllerPinch? _pdfController;
  bool _downloading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    try {
      final path = await loadPreviewPath(
        ref,
        widget.file,
        widget.fileKey,
        'pdf',
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

      await _initPdfViewer(path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _downloading = false;
        });
      }
    }
  }

  Future<void> _initPdfViewer(String path) async {
    try {
      final documentFuture = PdfDocument.openFile(path);
      final controller = PdfControllerPinch(document: documentFuture);
      final document = await documentFuture;

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _pdfController = controller;
        _totalPages = document.pagesCount;
        _downloading = false;
      });
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

    final controller = _pdfController;
    if (controller == null) {
      return const PreviewLoading();
    }

    return Stack(
      children: [
        PdfViewPinch(
          controller: controller,
          onPageChanged: (page) {
            setState(() => _currentPage = page);
          },
          builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(),
            documentLoaderBuilder: (_) => const PreviewLoading(),
            pageLoaderBuilder: (_) => const Center(
              child: CircularProgressIndicator(
                color: HoodikColors.iconCrimson,
                strokeWidth: 2,
              ),
            ),
            errorBuilder: (_, error) => Center(
              child: Text(
                AppLocalizations.of(
                  context,
                ).previewFailedToRenderPage('$error'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),

        // Page counter at bottom
        if (_totalPages > 1)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Color(0x00000000)],
                  ),
                ),
                child: Text(
                  AppLocalizations.of(
                    context,
                  ).previewPageCounter(_currentPage, _totalPages),
                  style: const TextStyle(
                    color: HoodikColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
