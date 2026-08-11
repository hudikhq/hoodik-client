import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/storage/database.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shares/shared_constants.dart';
import '../providers/files_notifier.dart';
import 'failed_uploads_badge.dart';
import 'file_sort_controls.dart';

/// App bar for the files screen with two modes:
/// - Normal: title, search, refresh, offline chip, view mode, sort,
///   select, and the account avatar shortcut.
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
  final Account? account;
  final VoidCallback onExitSelection;
  final VoidCallback onMoveSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onEnterSelection;
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
    required this.account,
    required this.onExitSelection,
    required this.onMoveSelected,
    required this.onDeleteSelected,
    required this.onEnterSelection,
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
          adaptiveIcon(material: Icons.close, cupertino: CupertinoIcons.xmark),
        ),
        onPressed: onExitSelection,
      ),
      title: Text(l10n.filesSelectedCount(selectionCount)),
      actions: [
        IconButton(
          icon: Icon(
            adaptiveIcon(
              material: Icons.drive_file_move_outline,
              cupertino: CupertinoIcons.folder_badge_plus,
            ),
          ),
          tooltip: l10n.commonMove,
          onPressed: busy ? null : onMoveSelected,
        ),
        IconButton(
          icon: Icon(
            adaptiveIcon(
              material: Icons.delete_outline,
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
                  material: Icons.arrow_back,
                  cupertino: CupertinoIcons.back,
                ),
              ),
              onPressed: () => context.pop(),
            )
          : null,
      actions: [
        const FailedUploadsBadge(),
        IconButton(
          icon: Icon(
            adaptiveIcon(
              material: Icons.search,
              cupertino: CupertinoIcons.search,
            ),
          ),
          tooltip: l10n.commonSearch,
          onPressed: () => context.go('/search'),
        ),
        if (_showsRefreshAction(theme.platform))
          IconButton(
            icon: Icon(
              adaptiveIcon(
                material: Icons.refresh,
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
              backgroundColor: HoodikColors.brownish600,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: Icon(
                Icons.cloud_off,
                size: 14,
                color: HoodikColors.iconCrimson,
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
        if (account != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => context.go('/account'),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: HoodikColors.redish700,
                child: Text(
                  (account!.email.isNotEmpty ? account!.email[0] : '?')
                      .toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
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

    return PopupMenuButton<FilesViewMode>(
      tooltip: l10n.filesViewAsTooltip(labelFor(current)),
      icon: Icon(iconFor(current)),
      onSelected: (mode) => ref.read(filesViewModeProvider.notifier).set(mode),
      itemBuilder: (_) => FilesViewMode.values.map((mode) {
        final selected = mode == current;
        return PopupMenuItem<FilesViewMode>(
          value: mode,
          child: Row(
            children: [
              Icon(
                iconFor(mode),
                size: 18,
                color: selected
                    ? HoodikColors.orangy500
                    : HoodikColors.iconMuted,
              ),
              const SizedBox(width: 12),
              Text(
                labelFor(mode),
                style: TextStyle(
                  color: selected
                      ? HoodikColors.dirtyWhite
                      : HoodikColors.textMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (selected) ...[
                const Spacer(),
                const Icon(
                  Icons.check,
                  size: 16,
                  color: HoodikColors.orangy500,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
