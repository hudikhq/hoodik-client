import 'package:flutter/material.dart';

import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Fallback widget for file types that cannot be previewed.
class PreviewUnsupported extends StatelessWidget {
  final String fileName;
  final String mime;
  final VoidCallback onDownload;

  const PreviewUnsupported({
    super.key,
    required this.fileName,
    required this.mime,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isApplePlatform
                  ? Icons.insert_drive_file
                  : Icons.insert_drive_file_outlined,
              size: 64,
              color: context.colors.iconMuted,
            ),
            const SizedBox(height: 24),
            Text(
              fileName,
              style: TextStyle(
                color: context.colors.text,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              mime,
              style: TextStyle(color: context.colors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.previewNoPreviewAvailable,
              style: TextStyle(color: context.colors.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            AdaptiveButton(
              onPressed: onDownload,
              child: Text(l10n.previewExport),
            ),
          ],
        ),
      ),
    );
  }
}
