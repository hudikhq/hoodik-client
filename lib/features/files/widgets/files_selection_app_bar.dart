import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shares/shared_constants.dart';
import '../providers/files_notifier.dart';

/// Selection-mode app bar: Close, count, Select all/Clear, Export, Offline,
/// Move, Delete.
class FilesSelectionAppBar extends ConsumerWidget
    implements PreferredSizeWidget {
  final String? dirId;
  final int selectionCount;
  final bool busy;
  final VoidCallback onExitSelection;
  final VoidCallback onExportSelected;
  final VoidCallback onMakeOfflineSelected;
  final VoidCallback onMoveSelected;
  final VoidCallback onDeleteSelected;

  const FilesSelectionAppBar({
    super.key,
    required this.dirId,
    required this.selectionCount,
    required this.busy,
    required this.onExitSelection,
    required this.onExportSelected,
    required this.onMakeOfflineSelected,
    required this.onMoveSelected,
    required this.onDeleteSelected,
  });

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(filesNotifierProvider(dirId));
    final selectableCount = [
      for (final file in state.files ?? const [])
        if (canSelectFile(file)) file,
    ].length;
    final allSelected =
        selectableCount > 0 && state.selectedIds.length >= selectableCount;
    final actionsEnabled = !busy && selectionCount > 0;

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
        AdaptiveTextButton(
          onPressed: selectableCount == 0
              ? null
              : () => ref
                    .read(filesNotifierProvider(dirId).notifier)
                    .toggleSelectAllOrClear(),
          child: Text(allSelected ? l10n.filesClear : l10n.filesSelectAll),
        ),
        IconButton(
          icon: Icon(
            adaptiveIcon(
              material: AppIcons.download,
              cupertino: CupertinoIcons.arrow_down,
            ),
          ),
          tooltip: l10n.filesExport,
          onPressed: actionsEnabled ? onExportSelected : null,
        ),
        IconButton(
          icon: Icon(
            adaptiveIcon(
              material: AppIcons.cloudDownload,
              cupertino: CupertinoIcons.cloud_download,
            ),
          ),
          tooltip: l10n.filesMakeAvailableOffline,
          onPressed: actionsEnabled ? onMakeOfflineSelected : null,
        ),
        IconButton(
          icon: Icon(
            adaptiveIcon(
              material: AppIcons.move,
              cupertino: CupertinoIcons.folder_badge_plus,
            ),
          ),
          tooltip: l10n.commonMove,
          onPressed: actionsEnabled ? onMoveSelected : null,
        ),
        IconButton(
          icon: Icon(
            adaptiveIcon(
              material: AppIcons.delete,
              cupertino: CupertinoIcons.trash,
            ),
          ),
          tooltip: l10n.commonDelete,
          onPressed: actionsEnabled ? onDeleteSelected : null,
        ),
      ],
    );
  }
}
