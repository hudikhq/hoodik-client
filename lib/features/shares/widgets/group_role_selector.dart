import 'package:flutter/material.dart';

import '../../../core/api/share_group_models.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Segmented reader / editor / co-owner picker for a member's *group* role —
/// a different axis from the file [ShareRoleSelector], so the label and copy
/// say "Group role" and describe group management, never file access. The
/// caller passes their own [callerRole]; a co-owner can offer reader/editor but
/// not co-owner (the server's privilege-escalation guard), so the unassignable
/// tiers are dropped from the row rather than shown disabled.
class GroupRoleSelector extends StatelessWidget {
  const GroupRoleSelector({
    super.key,
    required this.value,
    required this.callerRole,
    required this.onChanged,
    this.enabled = true,
  });

  final GroupRole value;
  final GroupRole callerRole;
  final ValueChanged<GroupRole> onChanged;
  final bool enabled;

  static const _assignable = [
    GroupRole.reader,
    GroupRole.editor,
    GroupRole.coOwner,
  ];

  @override
  Widget build(BuildContext context) {
    // The selector drives the add-member flow, where the target has no current
    // group role — the server's `can_set_role(None, role)`. A prospective
    // member is neither owner nor co-owner, so [GroupRole.reader] is the right
    // "not yet a member" baseline for the current-role guard.
    final l10n = AppLocalizations.of(context);
    final roles = _assignable
        .where((role) => callerRole.canSetRoleTo(GroupRole.reader, role))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sharesGroupRoleLabel,
          style: const TextStyle(
            fontSize: 12,
            color: HoodikColors.brownish100,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final role in roles) ...[
              Expanded(child: _chip(role)),
              if (role != roles.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _description(l10n, value),
          style: const TextStyle(fontSize: 12, color: HoodikColors.brownish100),
        ),
      ],
    );
  }

  Widget _chip(GroupRole role) {
    final selected = role == value;
    return InkWell(
      key: ValueKey('group-role-${role.wireString}'),
      onTap: enabled ? () => onChanged(role) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? HoodikColors.redish500 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? HoodikColors.redish500 : HoodikColors.brownish500,
          ),
        ),
        child: Text(
          groupRoleLabel(role),
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? HoodikColors.white : HoodikColors.dirtyWhite,
          ),
        ),
      ),
    );
  }

  static String _description(AppLocalizations l10n, GroupRole role) =>
      switch (role) {
        GroupRole.reader => l10n.sharesGroupRoleReaderDescription,
        GroupRole.editor => l10n.sharesGroupRoleEditorDescription,
        GroupRole.coOwner => l10n.sharesGroupRoleCoOwnerDescription,
        GroupRole.owner => l10n.sharesGroupRoleOwnerDescription,
      };
}

/// Display label for a group role. Shared by the selector and the per-member
/// role chip so the two never drift.
String groupRoleLabel(GroupRole role) => switch (role) {
  GroupRole.reader => ambientL10n.sharesRoleReader,
  GroupRole.editor => ambientL10n.sharesRoleEditor,
  GroupRole.coOwner => ambientL10n.sharesRoleCoOwner,
  GroupRole.owner => ambientL10n.sharesRoleOwner,
};

/// A compact, read-only chip showing a member's group role in the roster.
class GroupRoleChip extends StatelessWidget {
  const GroupRoleChip(this.role, {super.key});

  final GroupRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('group-role-chip-${role.wireString}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: HoodikColors.brownish700,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: HoodikColors.brownish500, width: 0.5),
      ),
      child: Text(
        groupRoleLabel(role),
        style: const TextStyle(fontSize: 11, color: HoodikColors.dirtyWhite),
      ),
    );
  }
}
