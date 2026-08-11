import 'package:flutter/material.dart';

import '../../../core/crypto/share_crypto.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Segmented reader / editor / co-owner picker for a share grant. The caller
/// passes the roles the server advertises so an instance that disabled a tier
/// never offers it; an empty list falls back to all three.
class ShareRoleSelector extends StatelessWidget {
  const ShareRoleSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.available = const [],
    this.enabled = true,
  });

  final ShareRole value;
  final ValueChanged<ShareRole> onChanged;
  final List<ShareRole> available;
  final bool enabled;

  static const _all = [ShareRole.reader, ShareRole.editor, ShareRole.coOwner];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roles = available.isEmpty
        ? _all
        : _all.where(available.contains).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sharesRoleLabel,
          style: TextStyle(
            fontSize: 12,
            color: context.colors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final role in roles) ...[
              Expanded(child: _chip(context, l10n, role)),
              if (role != roles.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _description(l10n, value),
          style: TextStyle(fontSize: 12, color: context.colors.textMuted),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, AppLocalizations l10n, ShareRole role) {
    final selected = role == value;
    return InkWell(
      onTap: enabled ? () => onChanged(role) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? context.colors.dangerFill : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? context.colors.dangerFill
                : context.colors.seamStrong,
          ),
        ),
        child: Text(
          _label(l10n, role),
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? context.colors.onFill : context.colors.text,
          ),
        ),
      ),
    );
  }

  static String _label(AppLocalizations l10n, ShareRole role) => switch (role) {
    ShareRole.reader => l10n.sharesRoleReader,
    ShareRole.editor => l10n.sharesRoleEditor,
    ShareRole.coOwner => l10n.sharesRoleCoOwner,
  };

  static String _description(AppLocalizations l10n, ShareRole role) =>
      switch (role) {
        ShareRole.reader => l10n.sharesRoleReaderDescription,
        ShareRole.editor => l10n.sharesRoleEditorDescription,
        ShareRole.coOwner => l10n.sharesRoleCoOwnerDescription,
      };
}
