import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../../../core/widgets/adaptive_menu.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../l10n/generated/app_localizations.dart';

class VersionRow extends StatelessWidget {
  final FileVersion version;
  final String dateLabel;
  final bool busy;
  final VoidCallback onPreview;
  final VoidCallback onRestore;
  final VoidCallback onFork;
  final VoidCallback onDelete;

  const VersionRow({
    super.key,
    required this.version,
    required this.dateLabel,
    required this.busy,
    required this.onPreview,
    required this.onRestore,
    required this.onFork,
    required this.onDelete,
  });

  String _author(FileVersion v, AppLocalizations l10n) {
    if (v.isAnonymous) return l10n.notesAuthorAnonymous;
    return v.userId == null ? l10n.commonUnknown : l10n.notesAuthorYou;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      title: Row(
        children: [
          Text(
            'v${version.version}',
            style: TextStyle(
              color: context.colors.iconEmber,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dateLabel,
              style: TextStyle(color: context.colors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${_author(version, l10n)} · ${l10n.notesChunkCount(version.chunks)}',
        style: TextStyle(color: context.colors.textMuted, fontSize: 12),
      ),
      trailing: busy
          ? null
          : AdaptiveMenuButton(
              icon: AppIcons.overflowVertical,
              tooltip: l10n.notesMore,
              builder: (ctx) => [
                AdaptiveMenuAction(
                  icon: AppIcons.preview,
                  iconColor: ctx.colors.sageFill,
                  label: l10n.notesPreview,
                  onTap: onPreview,
                ),
                AdaptiveMenuAction(
                  icon: AppIcons.history,
                  iconColor: ctx.colors.iconEmber,
                  label: l10n.notesRestoreHere,
                  onTap: onRestore,
                ),
                AdaptiveMenuAction(
                  icon: AppIcons.noteEdit,
                  iconColor: ctx.colors.iconSlate,
                  label: l10n.notesRestoreAsNew,
                  onTap: onFork,
                ),
                AdaptiveMenuAction(
                  icon: AppIcons.delete,
                  iconColor: ctx.colors.iconCrimson,
                  label: l10n.notesDeleteThisVersion,
                  onTap: onDelete,
                  isDestructive: true,
                ),
              ],
            ),
      onTap: busy ? null : onPreview,
    );
  }
}
