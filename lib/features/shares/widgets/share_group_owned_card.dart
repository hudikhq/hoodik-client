import 'package:flutter/material.dart';

import '../../../core/api/share_group_models.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'folder_member_tile.dart' show FolderMemberTile;
import 'group_role_selector.dart' show GroupRoleChip, groupRoleLabel;

/// One owned-group card on the share-groups screen: the group name + member
/// count, add/delete/rename actions, and the member roster with a per-member
/// group-role chip, set-role control, and remove control. The owner sees every
/// management affordance. Mirrors the owned-group list item in the web
/// `ShareHubGroups`.
class ShareGroupOwnedCard extends StatelessWidget {
  const ShareGroupOwnedCard({
    super.key,
    required this.group,
    required this.onAddMember,
    required this.onRename,
    required this.onDelete,
    required this.onRemoveMember,
    required this.onSetRole,
  });

  final ShareGroup group;
  final VoidCallback onAddMember;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final ValueChanged<ShareGroupMember> onRemoveMember;
  final void Function(ShareGroupMember member, GroupRole role) onSetRole;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = group.members.length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HoodikColors.brownish800,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HoodikColors.brownish600, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.group_outlined,
                size: 18,
                color: HoodikColors.brownish100,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: HoodikColors.dirtyWhite,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                l10n.sharesMemberCount(count),
                style: const TextStyle(
                  fontSize: 11,
                  color: HoodikColors.brownish100,
                ),
              ),
              IconButton(
                tooltip: l10n.sharesAddMember,
                icon: const Icon(
                  Icons.person_add_alt,
                  size: 18,
                  color: HoodikColors.brownish100,
                ),
                onPressed: onAddMember,
              ),
              IconButton(
                tooltip: l10n.sharesRenameGroup,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: HoodikColors.brownish100,
                ),
                onPressed: onRename,
              ),
              IconButton(
                tooltip: l10n.sharesDeleteGroup,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: HoodikColors.redish400,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
          if (count == 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 26),
              child: Text(
                l10n.sharesNoMembersYet,
                style: const TextStyle(
                  fontSize: 12,
                  color: HoodikColors.brownish100,
                ),
              ),
            )
          else
            for (final member in group.members)
              _MemberRow(
                member: member,
                onRemove: () => onRemoveMember(member),
                onSetRole: (role) => onSetRole(member, role),
              ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.onRemove,
    required this.onSetRole,
  });

  final ShareGroupMember member;
  final VoidCallback onRemove;
  final ValueChanged<GroupRole> onSetRole;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 26),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: HoodikColors.dirtyWhite,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _shortFingerprint(member.fingerprint),
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: HoodikColors.brownish100,
                  ),
                ),
              ],
            ),
          ),
          GroupRoleChip(member.groupRole),
          PopupMenuButton<GroupRole>(
            tooltip: AppLocalizations.of(context).sharesSetGroupRole,
            icon: const Icon(
              Icons.expand_more,
              size: 18,
              color: HoodikColors.brownish100,
            ),
            onSelected: onSetRole,
            itemBuilder: (context) => [
              for (final role in const [
                GroupRole.reader,
                GroupRole.editor,
                GroupRole.coOwner,
              ])
                CheckedPopupMenuItem<GroupRole>(
                  key: ValueKey('set-group-role-${role.wireString}'),
                  value: role,
                  checked: role == member.groupRole,
                  child: Text(groupRoleLabel(role)),
                ),
            ],
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).sharesRemoveMember,
            icon: const Icon(
              Icons.person_remove_outlined,
              size: 18,
              color: HoodikColors.redish400,
            ),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  /// First two quad-groups of the formatted fingerprint, matching the web's
  /// `shortFingerprint` (`ShareHubGroups.vue`). Reuses [FolderMemberTile]'s
  /// crypto-free formatter so display is identical to the folder roster.
  static String _shortFingerprint(String hexFp) {
    return FolderMemberTile.formatFingerprint(
      hexFp,
    ).split('-').take(2).join('-');
  }
}
