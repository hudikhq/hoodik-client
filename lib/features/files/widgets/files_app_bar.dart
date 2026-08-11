import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shares/shared_constants.dart';
import '../providers/files_notifier.dart';
import 'failed_uploads_badge.dart';
import 'file_sort_controls.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../../../core/widgets/adaptive_menu.dart';

/// App bar for the files screen with two modes:
/// - Normal: title, refresh, offline chip, view mode, sort,
///   select, and create.
/// - Selection: close, count label, and Move/Delete batch actions.
///
/// The widget is stateless — it takes the flags and listeners it needs
/// and delegates to the parent for every user action.
class FilesAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? dirId;

  /// Decrypted name of [dirId]; null falls back to the generic title.
  final String? dirName;
  final bool selectionMode;
  final int selectionCount;
  final bool busy;
  final bool hasFiles;
  final bool isFromCache;
  final SortField sortField;
  final SortOrder sortOrder;
  final VoidCallback onExitSelection;
  final VoidCallback onMoveSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onEnterSelection;

  /// Opens the create/upload sheet. Lives in the bar rather than a
  /// floating button: iOS has no FAB, and one create affordance in one
  /// corner beats two that move between platforms.
  final void Function(Offset? anchor) onCreate;
  final ValueChanged<SortField> onSortFieldSelected;

  const FilesAppBar({
    super.key,
    required this.dirId,
    this.dirName,
    required this.selectionMode,
    required this.selectionCount,
    required this.busy,
    required this.hasFiles,
    required this.isFromCache,
    required this.sortField,
    required this.sortOrder,
    required this.onExitSelection,
    required this.onMoveSelected,
    required this.onDeleteSelected,
    required this.onEnterSelection,
    required this.onCreate,
    required this.onSortFieldSelected,
  });

  @override
  // Match the app-wide AppBarTheme.toolbarHeight (44, iOS HIG nav bar).
  // Hard-coded here because `preferredSize` is a getter without context.
  Size get preferredSize => const Size.fromHeight(44);

  String _title(AppLocalizations l10n) {
    if (dirId == sharedWithMeDirId) return sharedWithMeDirName;
    if (dirId == null) return l10n.filesMyFiles;
    if (dirName != null && dirName!.isNotEmpty) return dirName!;
    return l10n.filesTitle;
  }

  /// Mobile gets pull-to-refresh; desktop has no equivalent gesture, so
  /// the listing surfaces an explicit refresh control there instead.
  bool _showsRefreshAction(TargetPlatform platform) =>
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (selectionMode) return _buildSelectionAppBar(context, l10n);
    return _buildNormalAppBar(context, ref, l10n);
  }

  Widget _buildSelectionAppBar(BuildContext context, AppLocalizations l10n) {
    return AppBar(
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        icon: Icon(
          adaptiveIcon(
            material: AppIcons.close,
            cupertino: CupertinoIcons.xmark,
          ),
        ),
        onPressed: onExitSelection,
      ),
      title: Text(l10n.filesSelectedCount(selectionCount)),
      actions: [
        IconButton(
          icon: Icon(
            adaptiveIcon(
              material: AppIcons.move,
              cupertino: CupertinoIcons.folder_badge_plus,
            ),
          ),
          tooltip: l10n.commonMove,
          onPressed: busy ? null : onMoveSelected,
        ),
        IconButton(
          icon: Icon(
            adaptiveIcon(
              material: AppIcons.delete,
              cupertino: CupertinoIcons.trash,
            ),
          ),
          tooltip: l10n.commonDelete,
          onPressed: busy ? null : onDeleteSelected,
        ),
      ],
    );
  }

  Widget _buildNormalAppBar(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    return AppBar(
      title: Text(_title(l10n)),
      leading: dirId != null
          ? IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: Icon(
                adaptiveIcon(
                  material: AppIcons.back,
                  cupertino: CupertinoIcons.back,
                ),
              ),
              onPressed: () => context.pop(),
            )
          : null,
      actions: [
        const FailedUploadsBadge(),
        if (_showsRefreshAction(theme.platform))
          IconButton(
            icon: Icon(
              adaptiveIcon(
                material: AppIcons.refresh,
                cupertino: CupertinoIcons.arrow_clockwise,
              ),
            ),
            tooltip: l10n.filesRefresh,
            onPressed: busy
                ? null
                : () => ref.read(filesNotifierProvider(dirId).notifier).load(),
          ),
        if (isFromCache)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Chip(
              label: Text(
                l10n.filesOfflineChip,
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor: context.colors.seam,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: Icon(
                Icons.cloud_off,
                size: 14,
                color: context.colors.iconCrimson,
              ),
            ),
          ),
        if (hasFiles) ...[
          _ViewModeButton(),
          FileSortButton(
            currentField: sortField,
            currentOrder: sortOrder,
            onFieldSelected: onSortFieldSelected,
          ),
          IconButton(
            icon: Icon(
              adaptiveIcon(
                material: Icons.checklist,
                cupertino: CupertinoIcons.checkmark_circle,
              ),
            ),
            tooltip: l10n.filesSelectFilesTooltip,
            onPressed: onEnterSelection,
          ),
        ],
        Builder(
          builder: (ctx) => IconButton(
            icon: Icon(
              adaptiveIcon(
                material: AppIcons.add,
                cupertino: CupertinoIcons.add,
              ),
            ),
            tooltip: l10n.commonCreate,
            onPressed: busy
                ? null
                : () {
                    // A pointer wants the menu under the button it clicked;
                    // touch ignores this and sheets regardless.
                    final box = ctx.findRenderObject() as RenderBox?;
                    onCreate(
                      box != null && box.hasSize
                          ? box.localToGlobal(box.size.center(Offset.zero))
                          : null,
                    );
                  },
          ),
        ),
      ],
    );
  }
}

/// The "list / icons / tree" switcher. Lives here because the chrome
/// around the label (check mark, accent color, font weight) is part
/// of the app bar's visual grammar rather than the listing itself.
class _ViewModeButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(filesViewModeProvider);
    final l10n = AppLocalizations.of(context);
    IconData iconFor(FilesViewMode m) => switch (m) {
      FilesViewMode.list => adaptiveIcon(
        material: Icons.view_list,
        cupertino: CupertinoIcons.list_bullet,
      ),
      FilesViewMode.icons => adaptiveIcon(
        material: Icons.grid_view,
        cupertino: CupertinoIcons.square_grid_2x2,
      ),
      FilesViewMode.tree => Icons.account_tree_outlined,
    };
    String labelFor(FilesViewMode m) => switch (m) {
      FilesViewMode.list => l10n.filesViewList,
      FilesViewMode.icons => l10n.filesViewIcons,
      FilesViewMode.tree => l10n.filesViewTree,
    };

    return AdaptiveMenuButton(
      icon: iconFor(current),
      iconColor: context.colors.text,
      tooltip: l10n.filesViewAsTooltip(labelFor(current)),
      builder: (ctx) => [
        for (final mode in FilesViewMode.values)
          AdaptiveMenuAction(
            icon: iconFor(mode),
            iconColor: mode == current
                ? ctx.colors.iconEmber
                : ctx.colors.iconMuted,
            label: labelFor(mode),
            isSelected: mode == current,
            onTap: () => ref.read(filesViewModeProvider.notifier).set(mode),
          ),
      ],
    );
  }
}
