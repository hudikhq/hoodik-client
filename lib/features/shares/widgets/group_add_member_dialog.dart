import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/share_group_models.dart';
import '../../../core/api/shares_models.dart' show DiscoveredUser;
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../controllers/group_controller.dart';
import 'group_role_selector.dart';
import 'recipient_discovery.dart';
import 'share_fingerprint_tile.dart';

/// Add a member to the group named [groupName]. Discovers the recipient by
/// email, gates on the trust-on-first-use fingerprint state (mismatch is a hard
/// stop until acknowledged), lets the caller pick the member's **group** role
/// (bounded by [callerRole] — a co-owner can't mint a co-owner), and submits
/// through [GroupController.addMember]. A group is a saved recipient selection,
/// so this is a plain roster insert — no file keys move. Returns true when a
/// member was added so the groups screen refreshes. Mirrors the web
/// `GroupAddMemberDialog`.
Future<bool> showGroupAddMemberDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String groupId,
  required String groupName,
  GroupRole callerRole = GroupRole.owner,
}) async {
  final added = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GroupAddMemberDialog(
      groupId: groupId,
      groupName: groupName,
      callerRole: callerRole,
    ),
  );
  return added ?? false;
}

class _GroupAddMemberDialog extends ConsumerStatefulWidget {
  const _GroupAddMemberDialog({
    required this.groupId,
    required this.groupName,
    required this.callerRole,
  });

  final String groupId;
  final String groupName;
  final GroupRole callerRole;

  @override
  ConsumerState<_GroupAddMemberDialog> createState() =>
      _GroupAddMemberDialogState();
}

class _GroupAddMemberDialogState extends ConsumerState<_GroupAddMemberDialog> {
  final _emailController = TextEditingController();

  bool _discovering = false;
  bool _submitting = false;
  String? _discoverError;

  DiscoveredUser? _recipient;
  String _formattedFingerprint = '';
  ShareTrustStatus _trustStatus = ShareTrustStatus.firstSight;
  String? _cachedFingerprint;
  bool _mismatchAcknowledged = false;

  GroupRole _role = GroupRole.reader;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_recipient == null || _submitting) return false;
    if (_trustStatus == ShareTrustStatus.mismatch && !_mismatchAcknowledged) {
      return false;
    }
    return true;
  }

  Future<void> _discover() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _discoverError = l10n.sharesEnterMemberEmailFirst);
      return;
    }
    setState(() {
      _discovering = true;
      _discoverError = null;
      _recipient = null;
      _mismatchAcknowledged = false;
    });

    final result = await resolveRecipient(ref, email);
    if (!mounted) return;
    setState(() {
      _discovering = false;
      switch (result) {
        case RecipientResolved():
          _recipient = result.user;
          _formattedFingerprint = result.formattedFingerprint;
          _trustStatus = result.status;
          _cachedFingerprint = result.cachedFingerprint;
        case RecipientLookupFailed(:final message):
          _discoverError = message ?? l10n.sharesNoUserWithEmail;
      }
    });
  }

  Future<void> _submit() async {
    final recipient = _recipient;
    if (recipient == null || !_canSubmit) return;

    setState(() => _submitting = true);
    final outcome = await ref
        .read(groupControllerProvider)
        .addMember(
          groupId: widget.groupId,
          recipient: recipient,
          groupRole: _role,
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (outcome) {
      case FolderShareSuccess():
        Navigator.of(context).pop(true);
        AppNotification.show(
          context,
          message: AppLocalizations.of(
            context,
          ).sharesMemberAddedToGroup(recipient.email, widget.groupName),
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
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.sharesAddMemberToGroup(widget.groupName),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              AdaptiveTextField(
                controller: _emailController,
                label: l10n.sharesMemberEmailLabel,
                placeholder: l10n.sharesEmailPlaceholder,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                enabled: !_submitting,
                onSubmitted: (_) => _discover(),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: AdaptiveTextButton(
                  onPressed: _discovering || _submitting ? null : _discover,
                  child: _discovering
                      ? const AdaptiveLoadingIndicator(radius: 8)
                      : Text(l10n.sharesFindUser),
                ),
              ),
              if (_discoverError != null) ...[
                const SizedBox(height: 6),
                ErrorBanner(message: _discoverError!),
              ],
              if (_recipient != null) ...[
                const SizedBox(height: 12),
                ShareFingerprintTile(
                  email: _recipient!.email,
                  formattedFingerprint: _formattedFingerprint,
                  status: _trustStatus,
                  cachedFingerprint: _cachedFingerprint,
                  mismatchAcknowledged: _mismatchAcknowledged,
                  onAcknowledgeChanged: _submitting
                      ? null
                      : (v) => setState(() => _mismatchAcknowledged = v),
                ),
                const SizedBox(height: 16),
                GroupRoleSelector(
                  value: _role,
                  callerRole: widget.callerRole,
                  enabled: !_submitting,
                  onChanged: (r) => setState(() => _role = r),
                ),
              ],
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
                    onPressed: _canSubmit ? _submit : null,
                    child: _submitting
                        ? const AdaptiveLoadingIndicator(radius: 8)
                        : Text(l10n.sharesAddMember),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
