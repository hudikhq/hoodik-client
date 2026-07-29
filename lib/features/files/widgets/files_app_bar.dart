import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
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
    return dirId == null ? l10n.filesMyFiles : l10n.filesTitle;
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
    if (selectionMode) return _buildSelectionAppBar(l10n);
    return _buildNormalAppBar(context, ref, l10n);
  }

  Widget _buildSelectionAppBar(AppLocalizations l10n) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onExitSelection,
      ),
      title: Text(l10n.filesSelectedCount(selectionCount)),
      actions: [
        IconButton(
          icon: const Icon(Icons.drive_file_move_outline),
          tooltip: l10n.commonMove,
          onPressed: busy ? null : onMoveSelected,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
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
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            )
          : null,
      actions: [
        const FailedUploadsBadge(),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: l10n.commonSearch,
          onPressed: () => context.go('/search'),
        ),
        if (_showsRefreshAction(theme.platform))
          IconButton(
            icon: const Icon(Icons.refresh),
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
                color: theme.colorScheme.primary,
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
            icon: const Icon(Icons.checklist),
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
      FilesViewMode.list => Icons.view_list,
      FilesViewMode.icons => Icons.grid_view,
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
                    : HoodikColors.brownish100,
              ),
              const SizedBox(width: 12),
              Text(
                labelFor(mode),
                style: TextStyle(
                  color: selected
                      ? HoodikColors.dirtyWhite
                      : HoodikColors.brownish100,
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
