import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/hoodik_scheme.dart';
import 'adaptive.dart';
import 'app_icons.dart';
import 'menu_anchor.dart';

/// One entry in an adaptive menu.
class AdaptiveMenuAction {
  const AdaptiveMenuAction({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.isDestructive = false,
    this.sectionBreak = false,
    this.isSelected = false,
    this.key,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  /// Renders in the platform's destructive treatment where it has one.
  final bool isDestructive;

  /// Starts a new group on the surfaces that draw separators.
  final bool sectionBreak;

  /// Marks the current value when the menu is a choice rather than a list of
  /// commands — a sort field, a view mode, a filter.
  final bool isSelected;

  /// Stable handle for tests, carried onto whichever widget the platform
  /// branch ends up rendering.
  final Key? key;
}

/// An icon that opens an adaptive menu anchored to itself.
///
/// Replaces [PopupMenuButton] so a trigger doesn't have to know which surface
/// its platform prefers. [builder] runs at press time, so entries can depend
/// on state that changed since the last frame.
class AdaptiveMenuButton extends StatelessWidget {
  const AdaptiveMenuButton({
    super.key,
    required this.builder,
    required this.icon,
    this.title,
    this.tooltip,
    this.iconSize = 20,
    this.iconColor,
  });

  final List<AdaptiveMenuAction> Function(BuildContext context) builder;
  final IconData icon;
  final String? title;
  final String? tooltip;
  final double iconSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        size: iconSize,
        color: iconColor ?? context.colors.iconMuted,
      ),
      tooltip: tooltip,
      onPressed: () {
        final box = context.findRenderObject() as RenderBox?;
        showAdaptiveMenu(
          context: context,
          title: title,
          anchor: box != null && box.hasSize
              ? box.localToGlobal(box.size.center(Offset.zero))
              : null,
          actions: builder(context),
        );
      },
    );
  }
}

/// Present [actions] in the idiom the host platform expects.
///
/// iOS answers a list of choices one way — the action sheet — no matter what
/// opened it, so [anchor] is ignored there. macOS and Android both put the
/// menu under the pointer when the gesture had one, and fall back to a sheet
/// when it didn't. Routing every menu through here is what stops the same
/// file growing two different-looking menus depending on whether the user
/// tapped the row or its kebab.
Future<void> showAdaptiveMenu({
  required BuildContext context,
  required List<AdaptiveMenuAction> actions,
  String? title,
  Offset? anchor,
  List<String> sectionHeaders = const [],
}) {
  if (actions.isEmpty) return Future.value();

  if (isApplePlatform && (Platform.isIOS || anchor == null)) {
    return _showActionSheet(context, title: title, actions: actions);
  }
  if (anchor != null) {
    return _showAnchoredMenu(context, anchor: anchor, actions: actions);
  }
  return _showBottomSheet(
    context,
    title: title,
    actions: actions,
    sectionHeaders: sectionHeaders,
  );
}

Future<void> _showActionSheet(
  BuildContext context, {
  String? title,
  required List<AdaptiveMenuAction> actions,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: title != null ? Text(title) : null,
      actions: [
        for (final action in actions)
          CupertinoActionSheetAction(
            key: action.key,
            isDestructiveAction: action.isDestructive,
            isDefaultAction: action.isSelected,
            onPressed: () {
              Navigator.pop(ctx);
              action.onTap();
            },
            child: Text(action.label),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(ctx),
        child: Text(AppLocalizations.of(ctx).commonCancel),
      ),
    ),
  );
}

Future<void> _showAnchoredMenu(
  BuildContext context, {
  required Offset anchor,
  required List<AdaptiveMenuAction> actions,
}) {
  return showMenu<void>(
    context: context,
    position: menuAnchorAt(context, anchor),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: context.colors.seam, width: 0.5),
    ),
    items: [
      for (final action in actions)
        PopupMenuItem<void>(
          key: action.key,
          onTap: action.onTap,
          child: Row(
            children: [
              Icon(action.icon, color: action.iconColor, size: 20),
              const SizedBox(width: 12),
              // Menus are width-capped, and a long label would otherwise
              // overflow the row rather than shorten.
              Flexible(
                child: Text(
                  action.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: action.isDestructive
                        ? context.colors.textCrimson
                        : context.colors.text,
                    fontWeight: action.isSelected ? FontWeight.w600 : null,
                  ),
                ),
              ),
              if (action.isSelected) ...[
                const SizedBox(width: 12),
                Icon(
                  AppIcons.check,
                  size: 16,
                  color: context.colors.iconCrimson,
                ),
              ],
            ],
          ),
        ),
    ],
  );
}

Future<void> _showBottomSheet(
  BuildContext context, {
  String? title,
  required List<AdaptiveMenuAction> actions,
  required List<String> sectionHeaders,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      var headerIndex = 0;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.track,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (title != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                for (final action in actions) ...[
                  if (action.sectionBreak && sectionHeaders.isEmpty)
                    const Divider(height: 1),
                  if (sectionHeaders.isNotEmpty &&
                      (identical(action, actions.first) || action.sectionBreak))
                    _sectionHeader(ctx, sectionHeaders[headerIndex++]),
                  ListTile(
                    key: action.key,
                    leading: Icon(action.icon, color: action.iconColor),
                    title: Text(
                      action.label,
                      style: action.isDestructive
                          ? TextStyle(color: context.colors.textCrimson)
                          : null,
                    ),
                    trailing: action.isSelected
                        ? Icon(
                            AppIcons.check,
                            color: context.colors.iconCrimson,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      action.onTap();
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _sectionHeader(BuildContext context, String label) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    ),
  );
}
