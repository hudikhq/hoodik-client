import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shares/shared_constants.dart';
import '../helpers/file_helpers.dart';

/// A single row in the file list, displaying a file or folder.
class FileListItem extends StatelessWidget {
  final FileItem file;
  final String displayName;
  final Uint8List? thumbnailBytes;
  final bool isSelected;
  final bool isOffline;
  final bool selectionMode;

  /// When false the share badges ("Owned by", "Shared with N") are
  /// suppressed — a server that doesn't speak the sharing protocol should
  /// never surface sharing affordances.
  final bool sharingEnabled;
  final VoidCallback onTap;
  final void Function(Offset globalPosition) onContextMenu;
  final VoidCallback onToggleSelection;

  const FileListItem({
    super.key,
    required this.file,
    required this.displayName,
    this.thumbnailBytes,
    required this.isSelected,
    required this.isOffline,
    required this.selectionMode,
    this.sharingEnabled = false,
    required this.onTap,
    required this.onContextMenu,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final ownedByLabel = _ownedByLabel(l10n);
    final sharedWithLabel = _sharedWithLabel(l10n);

    return GestureDetector(
      onSecondaryTapUp: (details) => onContextMenu(details.globalPosition),
      onLongPressStart: (details) {
        if (selectionMode) {
          onToggleSelection();
        } else {
          onContextMenu(details.globalPosition);
        }
      },
      child: ListTile(
        leading: selectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => onToggleSelection(),
                activeColor: HoodikColors.redish500,
              )
            : _buildLeading(),
        title: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            if (!file.isDir && isOffline) ...[
              Icon(
                Icons.offline_pin,
                size: 13,
                color: HoodikColors.greeny400.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
            ],
            // Surfaced when another session is in the middle of saving
            // this note. Helpful before the user tries to edit and runs
            // into a 409 conflict prompt.
            if (file.hasPendingEdit) ...[
              Icon(
                Icons.cloud_sync_outlined,
                size: 13,
                color: HoodikColors.orangy400.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 4),
            ],
            if (ownedByLabel != null) ...[
              _SharePill(
                icon: Icons.account_circle_outlined,
                label: ownedByLabel,
              ),
              const SizedBox(width: 6),
            ],
            if (sharedWithLabel != null) ...[
              _SharePill(icon: Icons.group_outlined, label: sharedWithLabel),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                _subtitleText(l10n),
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: selectionMode
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Kebab menu — keeps the per-row actions (rename, delete,
                  // share, etc.) reachable now that long-press is bound to
                  // drag-to-move. Desktop users still get the same menu via
                  // right-click; this button is the touch equivalent. The
                  // "Shared with me" virtual folder carries no actions, so its
                  // kebab would open an empty menu — omit the trigger for it.
                  if (file.id != sharedWithMeDirId)
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: l10n.filesMoreActions,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final box = ctx.findRenderObject() as RenderBox?;
                          final position = box != null && box.hasSize
                              ? box.localToGlobal(box.size.center(Offset.zero))
                              : Offset.zero;
                          onContextMenu(position);
                        },
                      ),
                    ),
                  if (file.isDir) const Icon(Icons.chevron_right),
                ],
              ),
        selected: isSelected,
        selectedTileColor: HoodikColors.redish900.withValues(alpha: 0.3),
        onTap: onTap,
      ),
    );
  }

  /// "Owned by X" for a row the caller received via a share. Suppressed for
  /// the synthetic root (which carries no owner) and when sharing is off.
  String? _ownedByLabel(AppLocalizations l10n) {
    if (!showsRecipientShareIndicator(file, sharingEnabled: sharingEnabled)) {
      return null;
    }
    return l10n.filesOwnedBy('${file.ownerEmail ?? file.sharedByEmail}');
  }

  /// "Shared with N" for a file the caller owns and has shared out.
  String? _sharedWithLabel(AppLocalizations l10n) {
    if (!showsOwnerShareIndicator(file, sharingEnabled: sharingEnabled)) {
      return null;
    }
    return l10n.filesSharedWith(file.sharedWithCount ?? 0);
  }

  String _subtitleText(AppLocalizations l10n) {
    if (file.isDir) return l10n.filesFolderLabel;
    if (file.isUploading) {
      return l10n.filesUploadingChunks(
        file.chunksStored ?? 0,
        file.chunks ?? 0,
      );
    }
    return '${formatFileSize(file.size)} ${formatFileDate(file.createdAt)}';
  }

  Widget _buildLeading() {
    if (thumbnailBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Image.memory(
            thumbnailBytes!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildIcon(),
          ),
        ),
      );
    }
    return _buildIcon();
  }

  Widget _buildIcon() {
    final color = fileIconColor(file, displayName: displayName);
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(fileIcon(file, displayName: displayName), color: color),
    );
  }
}

/// Compact inline chip for a row's sharing context ("Owned by X",
/// "Shared with N"). Shrinks to its content so it sits inside the subtitle
/// row next to the size/date text.
class _SharePill extends StatelessWidget {
  const _SharePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = HoodikColors.blueish300;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
