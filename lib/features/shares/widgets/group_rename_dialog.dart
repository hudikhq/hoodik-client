import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/share_groups_client.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../files/helpers/file_helpers.dart';
import '../controllers/group_controller.dart';
import '../providers/groups_notifier.dart';

/// Rename a share group (co-owner+). Refreshes the groups list on success and
/// surfaces a duplicate name as a precise inline message. Takes id + name
/// rather than a group object so both the owned card and the member-of tile —
/// which carry different model types — can open it. Mirrors the web rename
/// affordance in `ShareHubGroups`.
Future<void> showGroupRenameDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String groupId,
  required String currentName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _GroupRenameDialog(groupId: groupId, currentName: currentName),
  );
}

class _GroupRenameDialog extends ConsumerStatefulWidget {
  const _GroupRenameDialog({required this.groupId, required this.currentName});

  final String groupId;
  final String currentName;

  @override
  ConsumerState<_GroupRenameDialog> createState() => _GroupRenameDialogState();
}

class _GroupRenameDialogState extends ConsumerState<_GroupRenameDialog> {
  late final _nameController = TextEditingController(text: widget.currentName);
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.sharesGiveGroupName);
      return;
    }
    if (name == widget.currentName) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(groupControllerProvider).renameGroup(widget.groupId, name);
      await ref.read(groupsNotifierProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppNotification.show(
        context,
        message: l10n.sharesRenamedTo(name),
        type: NotificationType.success,
      );
    } on GroupNameTakenError {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = l10n.sharesGroupNameTaken;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = l10n.sharesGroupRenameFailed(formatErrorMessage(e));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sharesRenameGroup,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            AdaptiveTextField(
              controller: _nameController,
              label: l10n.sharesGroupNameLabel,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const AdaptiveLoadingIndicator(radius: 8)
                      : Text(l10n.commonRename),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
