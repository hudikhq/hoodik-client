import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/shares_models.dart';
import '../../../core/crypto/share_crypto.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../controllers/folder_share_controller.dart';
import 'recipient_discovery.dart';
import 'recipient_email_field.dart';
import 'share_fingerprint_tile.dart';
import 'share_role_selector.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Add a member to [folder], or change an existing member's role. Discovers the
/// recipient by email, gates on the trust-on-first-use fingerprint state
/// (mismatch is a hard stop until acknowledged), and submits through
/// [FolderShareController.shareFolder] — which walks the subtree, signs the
/// post-mutation roster, and POSTs. Returns true when the roster changed so the
/// members screen can refresh.
///
/// [prefillEmail]/[prefillRole] seed the form for a "Change role" action; the
/// email field is locked in that mode so the change targets the same member.
Future<bool> showFolderMemberAddSheet({
  required BuildContext context,
  required WidgetRef ref,
  required FileItem folder,
  String? prefillEmail,
  ShareRole? prefillRole,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FolderMemberAddSheet(
      folder: folder,
      prefillEmail: prefillEmail,
      prefillRole: prefillRole,
    ),
  );
  return changed ?? false;
}

class _FolderMemberAddSheet extends ConsumerStatefulWidget {
  const _FolderMemberAddSheet({
    required this.folder,
    this.prefillEmail,
    this.prefillRole,
  });

  final FileItem folder;
  final String? prefillEmail;
  final ShareRole? prefillRole;

  @override
  ConsumerState<_FolderMemberAddSheet> createState() =>
      _FolderMemberAddSheetState();
}

class _FolderMemberAddSheetState extends ConsumerState<_FolderMemberAddSheet> {
  late final TextEditingController _emailController = TextEditingController(
    text: widget.prefillEmail ?? '',
  );

  bool get _emailLocked => widget.prefillEmail != null;

  bool _discovering = false;
  bool _submitting = false;
  String? _discoverError;
  int _wrapDone = 0;
  int _wrapTotal = 0;

  DiscoveredUser? _recipient;
  String _formattedFingerprint = '';
  ShareTrustStatus _trustStatus = ShareTrustStatus.firstSight;
  String? _cachedFingerprint;
  bool _mismatchAcknowledged = false;

  late ShareRole _role = widget.prefillRole ?? ShareRole.reader;

  @override
  void initState() {
    super.initState();
    if (_emailLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _discover());
    }
  }

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
      setState(() => _discoverError = l10n.sharesEnterRecipientEmailFirst);
      return;
    }
    if (!looksLikeEmail(email)) {
      setState(() => _discoverError = l10n.sharesInvalidEmail);
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

    setState(() {
      _submitting = true;
      _wrapDone = 0;
      _wrapTotal = 0;
    });
    final outcome = await ref
        .read(folderShareControllerProvider)
        .shareFolder(
          folder: widget.folder,
          recipient: recipient,
          role: _role,
          onProgress: (done, total) {
            if (mounted) {
              setState(() {
                _wrapDone = done;
                _wrapTotal = total;
              });
            }
          },
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
          ).sharesSharedWith(recipient.email),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _emailLocked ? l10n.sharesChangeRole : l10n.sharesAddMember,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              RecipientEmailField(
                controller: _emailController,
                label: l10n.sharesRecipientEmailLabel,
                placeholder: l10n.sharesEmailPlaceholder,
                enabled: !_submitting && !_emailLocked,
                onSelected: _discover,
                onSubmitted: _discover,
              ),
              if (!_emailLocked) ...[
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
              ],
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
                ShareRoleSelector(
                  value: _role,
                  available: roles,
                  enabled: !_submitting,
                  onChanged: (r) => setState(() => _role = r),
                ),
                const SizedBox(height: 12),
                _AllowAddFilesHint(role: _role),
              ],
              if (_submitting && _wrapTotal > 0) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.sharesPreparingAccess(_wrapDone, _wrapTotal),
                  style: const TextStyle(fontSize: 12),
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
                        : Text(_emailLocked ? l10n.commonSave : l10n.commonAdd),
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

/// States what the picked role grants for adding files. The permission is
/// carried by the role itself — Editor and Co-owner may upload, Reader is
/// view-only — so this is a plain caption, not a control. (It used to
/// render a permanently disabled checkbox, which read as broken.)
class _AllowAddFilesHint extends StatelessWidget {
  const _AllowAddFilesHint({required this.role});

  final ShareRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canAddFiles = role != ShareRole.reader;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          canAddFiles ? Icons.check_circle_outline : Icons.block,
          size: 16,
          color: canAddFiles
              ? context.colors.textSage
              : context.colors.iconMuted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            canAddFiles
                ? l10n.sharesAllowAddFiles
                : l10n.sharesPickEditorToEnable,
            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
          ),
        ),
      ],
    );
  }
}
