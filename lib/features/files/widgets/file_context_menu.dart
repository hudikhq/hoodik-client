import 'package:flutter/material.dart';

import '../../../core/theme/hoodik_scheme.dart';
import '../../../core/widgets/menu_anchor.dart';

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

  await showMenu<void>(
    context: context,
    position: menuAnchorAt(context, position),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: context.colors.seam, width: 0.5),
    ),
    items: actions.map((action) {
      return PopupMenuItem<void>(
        onTap: action.onTap,
        child: Row(
          children: [
            Icon(action.icon, color: action.iconColor, size: 20),
            const SizedBox(width: 12),
            Text(action.label, style: TextStyle(color: context.colors.text)),
          ],
        ),
      );
    }).toList(),
  );
}
