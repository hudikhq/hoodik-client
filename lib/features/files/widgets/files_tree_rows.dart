import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/adaptive.dart';
import '../helpers/file_helpers.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// A folder row inside [FilesTreeView]: chevron, folder glyph, decrypted
/// name, and an optional share glyph. A single tap navigates into the folder;
/// a double tap (and the chevron) toggles expansion in place. Supplying both
/// recognizers on one [InkWell] lets the gesture arena hold the first tap until
/// it knows a second isn't coming, so a double tap expands without also firing
/// the navigate.
class TreeFolderRow extends StatelessWidget {
  final FileItem file;
  final String name;
  final int depth;
  final bool expanded;
  final bool loading;
  final bool isActive;

  /// The share glyph for this row, or null when none applies. Resolved by the
  /// host so the tree, list, and icon views agree on when it shows.
  final IconData? shareIcon;
  final VoidCallback onExpand;
  final VoidCallback onTap;

  /// Toggle expand/collapse in place. Wired to both the double tap and, via
  /// [onExpand], the chevron — both are the same in-place action.
  final VoidCallback onDoubleTap;
  final void Function(Offset globalPosition) onContextMenu;

  const TreeFolderRow({
    super.key,
    required this.file,
    required this.name,
    required this.depth,
    required this.expanded,
    required this.loading,
    required this.isActive,
    required this.shareIcon,
    required this.onExpand,
    required this.onTap,
    required this.onDoubleTap,
    required this.onContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final chevron = isApplePlatform
        ? (expanded
              ? CupertinoIcons.chevron_down
              : CupertinoIcons.chevron_right)
        : (expanded ? AppIcons.expand : AppIcons.chevronForward);

    return GestureDetector(
      onSecondaryTapUp: (details) => onContextMenu(details.globalPosition),
      onLongPressStart: (details) => onContextMenu(details.globalPosition),
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8 + depth * 16.0, 4, 8, 4),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onExpand,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    chevron,
                    size: 16,
                    color: context.colors.iconMuted,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                expanded ? AppIcons.folderOpen : AppIcons.folder,
                size: 18,
                color: context.colors.emberFill,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive
                        ? context.colors.iconEmber
                        : context.colors.text,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (shareIcon != null) TreeShareIndicator(icon: shareIcon!),
              if (loading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A file row inside [FilesTreeView]: type glyph, decrypted name, and an
/// optional share glyph. Indented past the folder chevron column so file
/// names line up under their parent's name.
class TreeFileRow extends StatelessWidget {
  final FileItem file;
  final String name;
  final int depth;
  final bool isActive;

  /// The share glyph for this row, or null when none applies.
  final IconData? shareIcon;
  final VoidCallback onTap;
  final void Function(Offset globalPosition) onContextMenu;

  const TreeFileRow({
    super.key,
    required this.file,
    required this.name,
    required this.depth,
    required this.isActive,
    required this.shareIcon,
    required this.onTap,
    required this.onContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final color = fileIconColor(context, file, displayName: name);

    return GestureDetector(
      onSecondaryTapUp: (details) => onContextMenu(details.globalPosition),
      onLongPressStart: (details) => onContextMenu(details.globalPosition),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8 + depth * 16.0 + 20, 4, 8, 4),
          child: Row(
            children: [
              Icon(fileIcon(file, displayName: name), size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive
                        ? context.colors.iconEmber
                        : context.colors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              if (shareIcon != null) TreeShareIndicator(icon: shareIcon!),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trailing share glyph for a tree row. Bare icon rather than the icon view's
/// circular chip — the tree is a flat text list whose other glyphs (folder,
/// file type, chevron) are also bare, so a chip would read as foreign here.
class TreeShareIndicator extends StatelessWidget {
  const TreeShareIndicator({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Icon(icon, size: 14, color: context.colors.iconSlate),
    );
  }
}
