import 'package:flutter/material.dart';

import '../../../core/theme/hoodik_colors.dart';

/// A single action in the file context menu.
class FileMenuAction {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const FileMenuAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });
}

/// Show a context menu at [position] with the given [actions].
///
/// Used for both right-click (desktop) and long-press (mobile).
Future<void> showFileContextMenu({
  required BuildContext context,
  required Offset position,
  required List<FileMenuAction> actions,
}) async {
  if (actions.isEmpty) return;

  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

  await showMenu<void>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      overlay.size.width - position.dx,
      overlay.size.height - position.dy,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: HoodikColors.brownish600, width: 0.5),
    ),
    items: actions.map((action) {
      return PopupMenuItem<void>(
        onTap: action.onTap,
        child: Row(
          children: [
            Icon(action.icon, color: action.iconColor, size: 20),
            const SizedBox(width: 12),
            Text(
              action.label,
              style: const TextStyle(color: HoodikColors.dirtyWhite),
            ),
          ],
        ),
      );
    }).toList(),
  );
}
