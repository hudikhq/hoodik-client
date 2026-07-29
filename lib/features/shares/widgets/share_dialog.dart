import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/shares_models.dart';
import '../../../core/crypto/share_crypto.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../files/controllers/files_share_controller.dart';
import '../../files/providers/files_notifier.dart';
import '../services/trusted_fingerprint_dao.dart';
import 'share_fingerprint_tile.dart';
import 'share_recipients_list.dart';
import 'share_role_selector.dart';
import 'share_to_group_sheet.dart';

/// Open the share dialog for an owned [file]. [dirId] is the directory the
/// browser is currently in, so the controller reads the already-decrypted file
/// key from that listing rather than re-deriving it.
Future<void> showShareDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String? dirId,
  required FileItem file,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ShareDialog(dirId: dirId, file: file),
  );
}

class _ShareDialog extends ConsumerStatefulWidget {
  const _ShareDialog({required this.dirId, required this.file});

  final String? dirId;
  final FileItem file;

  @override
  ConsumerState<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends ConsumerState<_ShareDialog> {
  final _emailController = TextEditingController();
  final _recipientsKey = GlobalKey<ShareRecipientsListState>();

  bool _discovering = false;
  bool _submitting = false;
  String? _discoverError;

  DiscoveredUser? _recipient;
  String _formattedFingerprint = '';
  ShareTrustStatus _trustStatus = ShareTrustStatus.firstSight;
  String? _cachedFingerprint;
  bool _mismatchAcknowledged = false;

  ShareRole _role = ShareRole.reader;

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

  void _clearRecipient() {
    _recipient = null;
    _formattedFingerprint = '';
    _trustStatus = ShareTrustStatus.firstSight;
    _cachedFingerprint = null;
    _mismatchAcknowledged = false;
  }

  Future<void> _discover() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _discoverError = l10n.sharesEnterRecipientEmailFirst);
      return;
    }
    final client = ref.read(apiClientProvider);
    final shareCrypto = ref.read(shareCryptoProvider);
    final ownerId = ref.read(activeServerUserIdProvider);
    if (client == null || shareCrypto == null || ownerId == null) {
      setState(() => _discoverError = l10n.sharesNotAuthenticated);
      return;
    }

    setState(() {
      _discovering = true;
      _discoverError = null;
      _clearRecipient();
    });

    try {
      final user = await client.shares.discoverUser(email);
      if (!mounted) return;
      if (user == null) {
        setState(() => _discoverError = l10n.sharesNoUserWithEmail);
        return;
      }
      await _onDiscovered(user, shareCrypto, ownerId);
    } on DiscoverException catch (e) {
      if (!mounted) return;
      setState(() => _discoverError = _discoverMessage(l10n, e.kind));
    } catch (_) {
      if (!mounted) return;
      setState(() => _discoverError = l10n.sharesLookupFailed);
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  /// Server's fingerprint claim must match the actual public key (hard stop),
  /// then trust-on-first-use against the local store decides the banner.
  Future<void> _onDiscovered(
    DiscoveredUser user,
    ShareCrypto shareCrypto,
    String ownerId,
  ) async {
    final localFingerprint = shareCrypto.computeFingerprint(
      user.pubkey,
      keyType: user.keyType,
    );
    if (localFingerprint.toLowerCase() != user.fingerprint.toLowerCase()) {
      setState(() {
        _discoverError = AppLocalizations.of(
          context,
        ).sharesKeyFingerprintMismatch;
      });
      return;
    }

    final trusted = await ref
        .read(databaseProvider)
        .getTrustedFingerprint(ownerId, user.userId);
    if (!mounted) return;

    final ShareTrustStatus status;
    String? cached;
    if (trusted == null) {
      status = ShareTrustStatus.firstSight;
    } else if (trusted.fingerprint.toLowerCase() ==
        user.fingerprint.toLowerCase()) {
      status = ShareTrustStatus.verified;
    } else {
      status = ShareTrustStatus.mismatch;
      cached = shareCrypto.formatFingerprint(trusted.fingerprint);
    }

    setState(() {
      _recipient = user;
      _formattedFingerprint = shareCrypto.formatFingerprint(user.fingerprint);
      _trustStatus = status;
      _cachedFingerprint = cached;
      _mismatchAcknowledged = false;
    });
  }

  Future<void> _submit() async {
    final recipient = _recipient;
    if (recipient == null || !_canSubmit) return;

    setState(() => _submitting = true);
    final outcome = await ref
        .read(filesShareControllerProvider(widget.dirId))
        .shareFile(file: widget.file, recipient: recipient, role: _role);
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (outcome) {
      case ShareSuccess():
        // Flip the row's shared-out state locally so the "shared with" icon
        // appears at once across the list, grid, and tree views — no manual
        // refresh. The exact count reconciles on the next listing load.
        ref
            .read(filesNotifierProvider(widget.dirId).notifier)
            .markFileSharedOut(widget.file.id);
        // Keep the dialog open and re-fetch the roster so the grant (or a role
        // change on an existing recipient) shows up right away, then clear the
        // add form so the next recipient starts from a blank slate.
        _recipientsKey.currentState?.reload();
        setState(() {
          _emailController.clear();
          _clearRecipient();
        });
        AppNotification.show(
          context,
          message: AppLocalizations.of(
            context,
          ).sharesSharedWith(recipient.email),
          type: NotificationType.success,
        );
      case ShareFailure(:final message):
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
    final caps = ref.watch(shareCapabilitiesProvider).valueOrNull;
    final roles = caps?.roles ?? const [];
    final canShareToGroup =
        (caps?.sharingEnabled ?? false) && (caps?.shareGroups ?? false);
    return AlertDialog(
      title: Text(l10n.sharesShareFileTitle),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdaptiveTextField(
                controller: _emailController,
                label: l10n.sharesRecipientEmailLabel,
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
                ShareRoleSelector(
                  value: _role,
                  available: roles,
                  enabled: !_submitting,
                  onChanged: (r) => setState(() => _role = r),
                ),
              ],
              if (canShareToGroup) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AdaptiveTextButton(
                    key: const ValueKey('share-with-group-button'),
                    onPressed: _submitting
                        ? null
                        : () => showShareToGroupSheet(
                            context: context,
                            ref: ref,
                            file: widget.file,
                            onShared: () =>
                                _recipientsKey.currentState?.reload(),
                          ),
                    child: Text(l10n.sharesShareWithGroup),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Divider(height: 1, color: HoodikColors.brownish600),
              const SizedBox(height: 16),
              ShareRecipientsList(
                key: _recipientsKey,
                controller: ref.read(
                  filesShareControllerProvider(widget.dirId),
                ),
                fileId: widget.file.id,
                dirId: widget.dirId,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
        TextButton(
          onPressed: _canSubmit ? _submit : null,
          child: _submitting
              ? const AdaptiveLoadingIndicator(radius: 8)
              : Text(l10n.commonShare),
        ),
      ],
    );
  }

  static String _discoverMessage(
    AppLocalizations l10n,
    DiscoverErrorKind kind,
  ) => switch (kind) {
    DiscoverErrorKind.cannotDiscoverSelf => l10n.sharesCannotShareWithSelf,
    DiscoverErrorKind.rateLimited => l10n.sharesTooManyLookups,
    DiscoverErrorKind.sharingDisabled => l10n.sharesSharingDisabled,
  };
}
