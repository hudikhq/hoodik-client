import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';

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
          color: context.colors.recess,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.colors.iconEmber.withValues(alpha: 0.6),
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
            Icon(AppIcons.move, size: 16, color: context.colors.iconEmber),
            const SizedBox(width: 8),
            Text(
              count > 1
                  ? AppLocalizations.of(context).filesMoveItems(count)
                  : (label ?? AppLocalizations.of(context).filesMoveItems(1)),
              style: TextStyle(
                color: context.colors.text,
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
