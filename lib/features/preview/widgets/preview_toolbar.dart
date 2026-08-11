import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Animated toolbar overlay shown at the top of the preview screen.
class PreviewToolbar extends StatelessWidget {
  final String fileName;
  final int currentIndex;
  final int totalCount;
  final bool visible;
  final VoidCallback onClose;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const PreviewToolbar({
    super.key,
    required this.fileName,
    required this.currentIndex,
    required this.totalCount,
    required this.visible,
    required this.onClose,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !visible,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Color(0x00000000)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  // Close button
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: Icon(
                      isApplePlatform ? CupertinoIcons.xmark : AppIcons.close,
                      color: Colors.white,
                    ),
                    onPressed: onClose,
                  ),

                  // File name + counter
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (totalCount > 1)
                          Text(
                            '${currentIndex + 1} / $totalCount',
                            style: TextStyle(
                              color: context.colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Download button
                  IconButton(
                    tooltip: AppLocalizations.of(context).filesExport,
                    icon: Icon(
                      isApplePlatform
                          ? CupertinoIcons.arrow_down_to_line
                          : Icons.download,
                      color: Colors.white,
                    ),
                    onPressed: onDownload,
                  ),

                  // Delete button
                  IconButton(
                    tooltip: AppLocalizations.of(context).commonDelete,
                    icon: Icon(
                      isApplePlatform ? CupertinoIcons.trash : AppIcons.delete,
                      color: context.colors.iconCrimson,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
