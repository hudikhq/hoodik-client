import 'package:flutter/material.dart';

import '../../../core/api/shares_models.dart';
import '../../../core/crypto/share_crypto.dart' show ShareRole;
import '../../../core/widgets/user_avatar.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Confirm moving an owned folder into a shared folder. Returns true when the
/// user proceeds. Shown only for the folder cascade — moving a folder in
/// re-shares it and its whole subtree with the destination's members, which is
/// a bigger consequence than a single-file move, so it gets an explicit gate.
/// Cancelling returns false before any key is wrapped.
///
/// [members] are exactly the people who will receive keys — the destination
/// roster minus the caller, already filtered by the cascade. When it is empty
/// (the caller is the sole member) the list section is omitted and the copy
/// reads as a plain re-parent.
Future<bool> confirmMoveIntoSharedFolder({
  required BuildContext context,
  required String folderName,
  required String destinationName,
  required int itemCount,
  required List<FolderMember> members,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _MoveIntoSharedConfirmDialog(
      folderName: folderName,
      destinationName: destinationName,
      itemCount: itemCount,
      members: members,
    ),
  );
  return result ?? false;
}

class _MoveIntoSharedConfirmDialog extends StatelessWidget {
  const _MoveIntoSharedConfirmDialog({
    required this.folderName,
    required this.destinationName,
    required this.itemCount,
    required this.members,
  });

  final String folderName;
  final String destinationName;
  final int itemCount;
  final List<FolderMember> members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final itemLabel = l10n.sharesItemCount(itemCount);

    return AlertDialog(
      title: Text(l10n.sharesMoveAndShareTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            members.isEmpty
                ? l10n.sharesMoveWillMove(
                    folderName,
                    destinationName,
                    itemLabel,
                  )
                : l10n.sharesMoveWillShare(
                    folderName,
                    destinationName,
                    itemLabel,
                    _summary(l10n, members),
                  ),
          ),
          if (members.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...members.map((m) => _MemberRow(member: m)),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.sharesEveryoneCanRead,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.sharesMoveAndShare),
        ),
      ],
    );
  }

  /// One-line roster summary for the headline sentence: up to two names, then
  /// "and N others" so a large roster doesn't blow out the copy.
  static String _summary(AppLocalizations l10n, List<FolderMember> members) {
    final names = members.map((m) => m.email ?? m.userId).toList();
    if (names.length == 1) return names.first;
    if (names.length == 2) return l10n.sharesTwoNames(names[0], names[1]);
    return l10n.sharesNamesAndOthers(names[0], names[1], names.length - 2);
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final FolderMember member;

  @override
  Widget build(BuildContext context) {
    final label = member.email ?? member.userId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          UserAvatar(email: label, radius: 12),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(
            _roleLabel(AppLocalizations.of(context), member.shareRole),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _roleLabel(AppLocalizations l10n, ShareRole role) {
    switch (role) {
      case ShareRole.reader:
        return l10n.sharesRoleReader;
      case ShareRole.editor:
        return l10n.sharesRoleEditor;
      case ShareRole.coOwner:
        return l10n.sharesRoleCoOwner;
    }
  }
}
