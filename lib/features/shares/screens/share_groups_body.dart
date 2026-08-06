import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/share_group_models.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../controllers/group_controller.dart';
import '../providers/groups_notifier.dart';
import '../widgets/group_add_member_dialog.dart';
import '../widgets/group_create_dialog.dart';
import '../widgets/group_rename_dialog.dart';
import '../widgets/group_role_selector.dart';
import '../widgets/member_of_group_tile.dart';
import '../widgets/share_group_owned_card.dart';

/// Re-fetches the caller's share groups and refreshes the list. Shared by the
/// Share hub's "Groups" tab (its AppBar "New group" action) and the in-list
/// add/delete/remove handlers so a fresh group always lands on screen.
Future<void> createShareGroup(BuildContext context, WidgetRef ref) async {
  final created = await showGroupCreateDialog(context: context, ref: ref);
  if (created) await ref.read(groupsNotifierProvider.notifier).refresh();
}

/// Share-groups management: the caller's owned groups (create, delete,
/// add/remove members) and the groups they belong to (read-only). Drives its
/// own [groupsNotifierProvider] so it renders inside the Share hub's "Groups"
/// tab without a Scaffold. Mirrors the web `ShareHubGroups`.
class ShareGroupsBody extends ConsumerWidget {
  const ShareGroupsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupsNotifierProvider);
    return state.when(
      loading: () => const Center(child: AdaptiveLoadingIndicator(radius: 12)),
      error: (_, _) => const _ErrorBody(),
      data: (groups) => _GroupsList(groups: groups),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppLocalizations.of(context).sharesGroupsLoadFailed,
          textAlign: TextAlign.center,
          style: const TextStyle(color: HoodikColors.brownish100),
        ),
      ),
    );
  }
}

class _GroupsList extends ConsumerWidget {
  const _GroupsList({required this.groups});

  final GroupsResponse groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: () => ref.read(groupsNotifierProvider.notifier).refresh(),
      child: ListView(
        // Keep the list draggable even when it fits the viewport, so the
        // refresh gesture always works.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _sectionLabel(l10n.sharesOwnedGroupsHeader),
          const SizedBox(height: 8),
          if (groups.owned.isEmpty)
            _emptyCard(
              l10n.sharesNoOwnedGroups,
              key: const ValueKey('owned-empty'),
            )
          else
            for (final group in groups.owned)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ShareGroupOwnedCard(
                  group: group,
                  onAddMember: () => _addMember(context, ref, group),
                  onRename: () => _renameGroup(context, ref, group),
                  onDelete: () => _deleteGroup(context, ref, group),
                  onRemoveMember: (member) =>
                      _removeMember(context, ref, group, member),
                  onSetRole: (member, role) =>
                      _setMemberRole(context, ref, group, member, role),
                ),
              ),
          const SizedBox(height: 16),
          _sectionLabel(l10n.sharesMemberOfHeader),
          const SizedBox(height: 8),
          if (groups.memberOf.isEmpty)
            _emptyCard(
              l10n.sharesNoMemberOfGroups,
              key: const ValueKey('member-of-empty'),
            )
          else
            for (final group in groups.memberOf)
              MemberOfGroupTile(
                group: group,
                onAddMember: () => _addMemberOf(context, ref, group),
              ),
        ],
      ),
    );
  }

  Future<void> _addMemberOf(
    BuildContext context,
    WidgetRef ref,
    ShareGroupAsMember group,
  ) async {
    final added = await showGroupAddMemberDialog(
      context: context,
      ref: ref,
      groupId: group.id,
      groupName: group.name,
      callerRole: group.groupRole,
    );
    if (added) await ref.read(groupsNotifierProvider.notifier).refresh();
  }

  Future<void> _addMember(
    BuildContext context,
    WidgetRef ref,
    ShareGroup group,
  ) async {
    final added = await showGroupAddMemberDialog(
      context: context,
      ref: ref,
      groupId: group.id,
      groupName: group.name,
      callerRole: GroupRole.owner,
    );
    if (added) await ref.read(groupsNotifierProvider.notifier).refresh();
  }

  Future<void> _renameGroup(
    BuildContext context,
    WidgetRef ref,
    ShareGroup group,
  ) async {
    await showGroupRenameDialog(
      context: context,
      ref: ref,
      groupId: group.id,
      currentName: group.name,
    );
  }

  Future<void> _setMemberRole(
    BuildContext context,
    WidgetRef ref,
    ShareGroup group,
    ShareGroupMember member,
    GroupRole role,
  ) async {
    if (role == member.groupRole) return;
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(groupControllerProvider)
          .setMemberRole(group.id, member.userId, role);
      if (!context.mounted) return;
      AppNotification.show(
        context,
        message: l10n.sharesMemberNowRole(member.email, groupRoleLabel(role)),
        type: NotificationType.success,
      );
      await ref.read(groupsNotifierProvider.notifier).refresh();
    } catch (_) {
      if (!context.mounted) return;
      AppNotification.show(
        context,
        message: l10n.sharesMemberRoleChangeFailed,
        type: NotificationType.error,
      );
    }
  }

  Future<void> _deleteGroup(
    BuildContext context,
    WidgetRef ref,
    ShareGroup group,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.sharesDeleteGroupTitle,
      content: l10n.sharesDeleteGroupBody(group.name),
      actions: [
        AdaptiveDialogAction(label: l10n.commonCancel, value: false),
        AdaptiveDialogAction(
          label: l10n.commonDelete,
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(groupControllerProvider).deleteGroup(group.id);
      if (!context.mounted) return;
      AppNotification.show(
        context,
        message: l10n.sharesGroupDeleted(group.name),
        type: NotificationType.success,
      );
      await ref.read(groupsNotifierProvider.notifier).refresh();
    } catch (_) {
      if (!context.mounted) return;
      AppNotification.show(
        context,
        message: l10n.sharesGroupDeleteFailed,
        type: NotificationType.error,
      );
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    ShareGroup group,
    ShareGroupMember member,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.sharesRemoveMemberTitle,
      content: l10n.sharesRemoveMemberBody(member.email, group.name),
      actions: [
        AdaptiveDialogAction(label: l10n.commonCancel, value: false),
        AdaptiveDialogAction(
          label: l10n.commonRemove,
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(groupControllerProvider)
          .removeMember(group.id, member.userId);
      if (!context.mounted) return;
      AppNotification.show(
        context,
        message: l10n.sharesMemberRemoved,
        type: NotificationType.success,
      );
      await ref.read(groupsNotifierProvider.notifier).refresh();
    } catch (_) {
      if (!context.mounted) return;
      AppNotification.show(
        context,
        message: l10n.sharesMemberRemoveFailed,
        type: NotificationType.error,
      );
    }
  }

  static Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      letterSpacing: 0.5,
      color: HoodikColors.brownish100,
    ),
  );

  static Widget _emptyCard(String text, {Key? key}) => Container(
    key: key,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: HoodikColors.brownish800,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: HoodikColors.brownish600, width: 0.5),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: HoodikColors.brownish100),
    ),
  );
}
