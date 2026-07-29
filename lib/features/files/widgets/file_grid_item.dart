import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../shares/shared_constants.dart';
import '../helpers/file_helpers.dart';

/// Single cell in the icon/grid view of the files screen.
///
/// Shows a large thumbnail (or type-specific icon) on top and the file
/// name below. Mirrors [FileListItem]'s interaction surface — tap,
/// context menu, selection toggle — so the host can swap between views
/// without re-plumbing handlers.
class FileGridItem extends StatelessWidget {
  final FileItem file;
  final String displayName;
  final Uint8List? thumbnailBytes;
  final bool isSelected;
  final bool isOffline;
  final bool selectionMode;

  /// When false the share badge is suppressed — mirrors [FileListItem], so a
  /// server that doesn't speak the sharing protocol surfaces no affordance.
  final bool sharingEnabled;
  final VoidCallback onTap;
  final VoidCallback onToggleSelection;
  final void Function(Offset globalPosition) onContextMenu;

  const FileGridItem({
    super.key,
    required this.file,
    required this.displayName,
    this.thumbnailBytes,
    required this.isSelected,
    required this.isOffline,
    required this.selectionMode,
    this.sharingEnabled = false,
    required this.onTap,
    required this.onToggleSelection,
    required this.onContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final color = fileIconColor(file, displayName: displayName);
    final shareIcon = shareIndicatorIcon(file, sharingEnabled: sharingEnabled);

    return GestureDetector(
      onSecondaryTapUp: (details) => onContextMenu(details.globalPosition),
      onLongPressStart: (details) {
        if (selectionMode) {
          onToggleSelection();
        } else {
          onContextMenu(details.globalPosition);
        }
      },
      child: Material(
        color: isSelected
            ? HoodikColors.redish900.withValues(alpha: 0.3)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: selectionMode ? onToggleSelection : onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildThumbnail(color)),
                      if (!file.isDir && isOffline)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: HoodikColors.brownish900,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.offline_pin,
                              size: 12,
                              color: HoodikColors.greeny400.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ),
                      if (file.hasPendingEdit)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: HoodikColors.brownish900,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.cloud_sync_outlined,
                              size: 12,
                              color: HoodikColors.orangy400.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                        ),
                      if (shareIcon != null)
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: HoodikColors.brownish900,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              shareIcon,
                              size: 12,
                              color: HoodikColors.blueish300,
                            ),
                          ),
                        ),
                      if (selectionMode)
                        Positioned(
                          left: 4,
                          top: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: HoodikColors.brownish900.withValues(
                                alpha: 0.85,
                              ),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: isSelected
                                  ? HoodikColors.redish400
                                  : HoodikColors.brownish100,
                            ),
                          ),
                        )
                      // The "Shared with me" virtual folder has no row
                      // actions (buildFileMenuActions returns none for it), so
                      // showing a kebab that opens an empty menu is a dead
                      // affordance — omit the trigger entirely.
                      else if (file.id != sharedWithMeDirId)
                        // Kebab menu — touch equivalent of right-click,
                        // since long-press is now bound to drag-to-move.
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Builder(
                            builder: (ctx) => Material(
                              color: HoodikColors.brownish900.withValues(
                                alpha: 0.7,
                              ),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  final box =
                                      ctx.findRenderObject() as RenderBox?;
                                  final position = box != null && box.hasSize
                                      ? box.localToGlobal(
                                          box.size.center(Offset.zero),
                                        )
                                      : Offset.zero;
                                  onContextMenu(position);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.more_vert,
                                    size: 16,
                                    color: HoodikColors.dirtyWhite,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: HoodikColors.dirtyWhite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(Color accent) {
    final thumb = thumbnailBytes;
    if (thumb != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          thumb,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildIconTile(accent),
        ),
      );
    }
    return _buildIconTile(accent);
  }

  Widget _buildIconTile(Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Icon(
          fileIcon(file, displayName: displayName),
          color: accent,
          size: 36,
        ),
      ),
    );
  }
}
