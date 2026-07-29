import 'package:flutter/material.dart';

import '../../../core/theme/hoodik_colors.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Pill shown under the cursor/finger while a file or selection is
/// being dragged. Small so it doesn't cover the drop target, labelled
/// with a count for multi-item drags and with the file name for solo
/// drags.
class FilesDragFeedback extends StatelessWidget {
  final int count;
  final String? label;

  const FilesDragFeedback({super.key, required this.count, this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: HoodikColors.brownish700,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: HoodikColors.orangy500.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.drive_file_move_outline,
              size: 16,
              color: HoodikColors.orangy500,
            ),
            const SizedBox(width: 8),
            Text(
              count > 1
                  ? AppLocalizations.of(context).filesMoveItems(count)
                  : (label ?? AppLocalizations.of(context).filesMoveItems(1)),
              style: const TextStyle(
                color: HoodikColors.dirtyWhite,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
