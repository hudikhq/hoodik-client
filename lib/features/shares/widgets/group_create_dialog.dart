import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/share_groups_client.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../files/helpers/file_helpers.dart';
import '../controllers/group_controller.dart';

/// Create a new share group. Returns true when a group was created so the
/// groups screen refreshes. A duplicate name surfaces a precise inline message
/// rather than a generic conflict. Mirrors the web `GroupCreateDialog.vue`.
Future<bool> showGroupCreateDialog({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _GroupCreateDialog(),
  );
  return created ?? false;
}

class _GroupCreateDialog extends ConsumerStatefulWidget {
  const _GroupCreateDialog();

  @override
  ConsumerState<_GroupCreateDialog> createState() => _GroupCreateDialogState();
}

class _GroupCreateDialogState extends ConsumerState<_GroupCreateDialog> {
  final _nameController = TextEditingController();
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
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final group = await ref.read(groupControllerProvider).createGroup(name);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppNotification.show(
        context,
        message: l10n.sharesGroupReady(group.name),
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
        _error = l10n.sharesGroupCreateFailed(formatErrorMessage(e));
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
              l10n.sharesNewShareGroup,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            AdaptiveTextField(
              controller: _nameController,
              label: l10n.sharesGroupNameLabel,
              placeholder: l10n.sharesGroupNamePlaceholder,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 10),
            Text(
              l10n.sharesGroupsExplainer,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const AdaptiveLoadingIndicator(radius: 8)
                      : Text(l10n.commonCreate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
