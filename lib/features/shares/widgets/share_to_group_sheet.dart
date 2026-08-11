import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/crypto/share_crypto.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../controllers/share_to_group_controller.dart';
import 'share_role_selector.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Pick a group the caller can share to (editor or above) and a file role,
/// then fan [file] out to every current member through [ShareToGroupController]
/// — a client-side fan-out running the single-share path once per member.
/// Returns nothing; success/failure surface as a notification.
///
/// Reached only when sharing is enabled and the server speaks groups — the
/// share dialog and folder-members screen gate the entry button on
/// `sharingEnabled`, so against a non-sharing server the affordance never
/// appears and this sheet is unreachable.
Future<void> showShareToGroupSheet({
  required BuildContext context,
  required WidgetRef ref,
  required FileItem file,
  void Function()? onShared,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ShareToGroupSheet(file: file, onShared: onShared),
  );
}

class _ShareToGroupSheet extends ConsumerStatefulWidget {
  const _ShareToGroupSheet({required this.file, this.onShared});

  final FileItem file;

  /// Fired after a successful fan-out so the opener can refresh its own view —
  /// the share dialog re-reads the file's recipient roster.
  final void Function()? onShared;

  @override
  ConsumerState<_ShareToGroupSheet> createState() => _ShareToGroupSheetState();
}

class _ShareToGroupSheetState extends ConsumerState<_ShareToGroupSheet> {
  String? _groupId;
  ShareRole _role = ShareRole.reader;
  bool _submitting = false;

  /// Groups the caller may share to: every owned group, plus every member-of
  /// group where their group role is editor or above. Fail-closed — a reader
  /// group never appears, so the server never gets a call it would reject.
  Future<List<({String id, String name})>> _loadEligible() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return const [];
    final response = await client.shareGroups.listGroups();
    return [
      for (final g in response.owned) (id: g.id, name: g.name),
      for (final g in response.memberOf)
        if (g.groupRole.canShareToGroup) (id: g.id, name: g.name),
    ];
  }

  Future<void> _submit() async {
    final groupId = _groupId;
    if (groupId == null) return;
    setState(() => _submitting = true);
    final outcome = await ref
        .read(shareToGroupControllerProvider)
        .shareToGroup(groupId: groupId, file: widget.file, role: _role);
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (outcome) {
      case FolderShareSuccess():
        widget.onShared?.call();
        Navigator.of(context).pop();
        AppNotification.show(
          context,
          message: AppLocalizations.of(context).sharesSharedWithGroup,
          type: NotificationType.success,
        );
      case FolderShareFailure(:final message):
        AppNotification.show(
          context,
          message: message,
          type: NotificationType.error,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles =
        ref.watch(shareCapabilitiesProvider).valueOrNull?.roles ?? const [];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FutureBuilder<List<({String id, String name})>>(
          future: _loadEligible(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: AdaptiveLoadingIndicator(radius: 10)),
              );
            }
            return _form(snapshot.data!, roles);
          },
        ),
      ),
    );
  }

  Widget _form(List<({String id, String name})> groups, List<ShareRole> roles) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sharesShareWithGroup,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        if (groups.isEmpty)
          Text(
            l10n.sharesNotGroupEditor,
            style: TextStyle(fontSize: 13, color: context.colors.textMuted),
          )
        else ...[
          Text(
            l10n.sharesGroupLabel,
            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
          ),
          const SizedBox(height: 8),
          for (final g in groups) _groupOption(g),
          const SizedBox(height: 12),
          ShareRoleSelector(
            value: _role,
            available: roles,
            enabled: !_submitting,
            onChanged: (r) => setState(() => _role = r),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: (_groupId == null || _submitting) ? null : _submit,
              child: _submitting
                  ? const AdaptiveLoadingIndicator(radius: 8)
                  : Text(l10n.commonShare),
            ),
          ],
        ),
      ],
    );
  }

  Widget _groupOption(({String id, String name}) g) {
    final selected = g.id == _groupId;
    return InkWell(
      key: ValueKey('share-to-group-${g.id}'),
      onTap: _submitting ? null : () => setState(() => _groupId = g.id),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected
                  ? context.colors.iconCrimson
                  : context.colors.iconMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                g.name,
                style: TextStyle(fontSize: 14, color: context.colors.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
