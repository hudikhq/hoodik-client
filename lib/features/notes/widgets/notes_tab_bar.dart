import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/editor_tab.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Horizontally scrollable tab bar for open notes.
///
/// Only shown on desktop-width layouts where multiple notes can be open
/// simultaneously. Mobile uses a single-tab model and hides this bar.
class NotesTabBar extends StatelessWidget {
  final List<EditorTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  /// If set, a button appears at the leading edge that re-expands the
  /// collapsed sidebar. When the sidebar is visible, pass `null`.
  final VoidCallback? onExpandSidebar;

  const NotesTabBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
    this.onExpandSidebar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: context.colors.canvas,
        border: Border(
          bottom: BorderSide(color: context.colors.seam, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (onExpandSidebar != null)
            _ExpandSidebarButton(onTap: onExpandSidebar!),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, i) {
                final tab = tabs[i];
                final isActive = i == activeIndex;
                return _TabItem(
                  tab: tab,
                  isActive: isActive,
                  onTap: () => onSelect(i),
                  onClose: () => onClose(i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandSidebarButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ExpandSidebarButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context).notesShowSidebar,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: context.colors.seam, width: 0.5),
            ),
          ),
          child: Icon(Icons.menu, size: 18, color: context.colors.iconMuted),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final EditorTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? context.colors.panel : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220, minWidth: 120),
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: context.colors.seam, width: 0.5),
              bottom: BorderSide(
                color: isActive
                    ? context.colors.crimsonFill
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  tab.fileName,
                  style: TextStyle(
                    color: isActive
                        ? context.colors.text
                        : context.colors.textMuted,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (tab.isDirty && !tab.isSaving)
                Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    CupertinoIcons.circle_fill,
                    size: 6,
                    color: context.colors.iconEmber,
                  ),
                ),
              if (tab.isSaving)
                Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: context.colors.iconEmber,
                    ),
                  ),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onClose,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    isApplePlatform ? CupertinoIcons.xmark : AppIcons.close,
                    size: 12,
                    color: context.colors.iconMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
