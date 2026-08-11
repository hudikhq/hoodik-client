import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../../../core/widgets/adaptive_menu.dart';

/// What field to sort files by.
enum SortField { name, size, type, date }

/// Sort direction.
enum SortOrder { asc, desc }

/// Sort a list of files by [field] and [order].
///
/// Directories always appear before files regardless of sort.
/// [displayName] is called to resolve decrypted names for name/type sorting.
List<FileItem> sortFiles({
  required List<FileItem> files,
  required SortField field,
  required SortOrder order,
  required String Function(FileItem) displayName,
}) {
  final dirs = files.where((f) => f.isDir).toList();
  final items = files.where((f) => !f.isDir).toList();

  int Function(FileItem, FileItem) comparator;

  switch (field) {
    case SortField.name:
      comparator = (a, b) {
        final nameA = displayName(a).toLowerCase();
        final nameB = displayName(b).toLowerCase();
        return nameA.compareTo(nameB);
      };
    case SortField.date:
      comparator = (a, b) {
        final dateA = a.fileModifiedAt ?? a.createdAt ?? 0;
        final dateB = b.fileModifiedAt ?? b.createdAt ?? 0;
        return dateA.compareTo(dateB);
      };
    case SortField.size:
      comparator = (a, b) {
        final sizeA = a.size ?? 0;
        final sizeB = b.size ?? 0;
        return sizeA.compareTo(sizeB);
      };
    case SortField.type:
      comparator = (a, b) {
        return a.mime.compareTo(b.mime);
      };
  }

  dirs.sort(comparator);
  items.sort(comparator);

  if (order == SortOrder.desc) {
    return [...dirs.reversed, ...items.reversed];
  }
  return [...dirs, ...items];
}

/// A popup menu button that lets the user pick a sort field.
///
/// Tapping the currently active field toggles the sort direction.
class FileSortButton extends StatelessWidget {
  final SortField currentField;
  final SortOrder currentOrder;
  final ValueChanged<SortField> onFieldSelected;

  const FileSortButton({
    super.key,
    required this.currentField,
    required this.currentOrder,
    required this.onFieldSelected,
  });

  @override
  Widget build(BuildContext context) {
    final icon = currentOrder == SortOrder.asc
        ? AppIcons.sortAscending
        : AppIcons.sortDescending;
    final l10n = AppLocalizations.of(context);

    return AdaptiveMenuButton(
      icon: icon,
      tooltip: l10n.filesSortTooltip,
      builder: (ctx) => [
        for (final (field, fieldIcon, label) in <(SortField, IconData, String)>[
          (SortField.name, Icons.sort_by_alpha, l10n.filesNameLabel),
          (SortField.date, AppIcons.schedule, l10n.filesDateLabel),
          (SortField.size, AppIcons.storage, l10n.filesSizeLabel),
          (SortField.type, Icons.category, l10n.filesTypeLabel),
        ])
          AdaptiveMenuAction(
            icon: fieldIcon,
            iconColor: field == currentField
                ? ctx.colors.iconEmber
                : ctx.colors.iconMuted,
            label: label,
            isSelected: field == currentField,
            onTap: () => onFieldSelected(field),
          ),
      ],
    );
  }
}
