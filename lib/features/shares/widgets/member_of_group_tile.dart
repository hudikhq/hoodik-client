import 'package:flutter/material.dart';

import '../../../core/api/share_group_models.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'group_role_selector.dart' show GroupRoleChip;

/// One "member of" group tile, role-aware. Every member sees the group name,
/// the owner's email, and their own group-role chip. A co-owner can add a
/// member; rename and delete stay owner-only (the owner acts on those from the
/// owned-group card), and per-member set-role and remove stay out because the
/// member-of slice carries no peer roster to act on. An editor sees a hint that
/// they can share files to the group from a file's share menu; the share itself
/// is a client-side fan-out initiated from the share dialog, not here. A reader
/// sees nothing actionable — the whole point of the reader tier.
///
/// The server is the sole authority; this gating is fail-closed convenience so
/// a reader or editor is never shown a button the server would reject.
class MemberOfGroupTile extends StatelessWidget {
  const MemberOfGroupTile({
    super.key,
    required this.group,
    required this.onAddMember,
  });

  final ShareGroupAsMember group;
  final VoidCallback onAddMember;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final role = group.groupRole;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: HoodikColors.dirtyWhite,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.sharesOwnedBy(group.ownerEmail),
                      style: const TextStyle(
                        fontSize: 12,
                        color: HoodikColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GroupRoleChip(role),
              if (role.canManageGroup)
                IconButton(
                  tooltip: l10n.sharesAddMember,
                  icon: const Icon(
                    Icons.person_add_alt,
                    size: 18,
                    color: HoodikColors.iconMuted,
                  ),
                  onPressed: onAddMember,
                ),
            ],
          ),
          if (role.canShareToGroup && !role.canManageGroup) ...[
            const SizedBox(height: 6),
            Text(
              l10n.sharesShareFromShareMenu,
              style: const TextStyle(
                fontSize: 12,
                color: HoodikColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
