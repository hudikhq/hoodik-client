import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/shares_models.dart';
import '../../../core/crypto/share_crypto.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../files/controllers/files_share_controller.dart';
import '../../files/providers/files_notifier.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Recipient roster for a file the caller owns, with per-recipient revoke.
///
/// Loads through [FilesShareController.listRecipients] and re-fetches after a
/// confirmed revoke so the list reflects the server. The fingerprint is shown
/// abbreviated; the [shareCryptoProvider] formats it the same way as the add
/// flow so the same recipient reads identically in both places.
class ShareRecipientsList extends ConsumerStatefulWidget {
  const ShareRecipientsList({
    super.key,
    required this.controller,
    required this.fileId,
    required this.dirId,
  });

  final FilesShareController controller;
  final String fileId;

  /// The directory the file lives in, so revoking the last recipient can clear
  /// the owner's shared-out badge on the right listing.
  final String? dirId;

  @override
  ConsumerState<ShareRecipientsList> createState() =>
      ShareRecipientsListState();
}

class ShareRecipientsListState extends ConsumerState<ShareRecipientsList> {
  late Future<List<AppShare>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.listRecipients(widget.fileId);
  }

  /// Re-fetch the roster from the server. The add flow lives in the parent
  /// dialog, so it calls this through a [GlobalKey] after a successful grant to
  /// surface the new recipient without forcing the user to reopen the dialog.
  void reload() {
    setState(() {
      _future = widget.controller.listRecipients(widget.fileId);
    });
  }

  Future<void> _revoke(AppShare recipient) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.sharesRevokeAccessTitle,
      content: l10n.sharesRevokeFileBody(recipient.recipientEmail),
      actions: [
        AdaptiveDialogAction(label: l10n.commonCancel, value: false),
        AdaptiveDialogAction(
          label: l10n.sharesRevoke,
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    // The roster the list is currently showing — the source of truth for
    // whether this is the last recipient. Reading it before the revoke avoids
    // depending on a post-revoke re-fetch that can still return the removed row
    // under read-after-write lag and leave the badge stuck on.
    final loadedRoster = await _future;
    if (!mounted) return;

    final outcome = await widget.controller.revokeRecipient(
      fileId: widget.fileId,
      userId: recipient.recipientId,
      currentRole: recipient.shareRole,
    );
    if (!mounted) return;

    switch (outcome) {
      case ShareSuccess():
        AppNotification.show(
          context,
          message: l10n.sharesAccessRevokedFor(recipient.recipientEmail),
          type: NotificationType.success,
        );
        // Removing the only remaining recipient drops the owner's shared-out
        // badge at once — the inverse of the optimistic flip on the share path,
        // applied synchronously so it never waits on the re-fetch below.
        final wasLast = loadedRoster
            .where((r) => r.recipientId != recipient.recipientId)
            .isEmpty;
        if (wasLast) {
          ref
              .read(filesNotifierProvider(widget.dirId).notifier)
              .markFileSharedInNone(widget.fileId);
        }
        reload();
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
    return FutureBuilder<List<AppShare>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: AdaptiveLoadingIndicator(radius: 9)),
          );
        }
        if (snapshot.hasError) {
          return Text(
            l10n.sharesRecipientsLoadFailed,
            style: TextStyle(fontSize: 12, color: context.colors.textCrimson),
          );
        }
        final recipients = snapshot.data ?? const [];
        if (recipients.isEmpty) {
          return Text(
            l10n.sharesNoAccessYet,
            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sharesPeopleWithAccess,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            for (final r in recipients) _row(r),
          ],
        );
      },
    );
  }

  Widget _row(AppShare recipient) {
    final shareCrypto = ref.read(shareCryptoProvider);
    final fingerprint = shareCrypto == null
        ? recipient.recipientPubkeyFingerprint
        : _abbreviate(
            shareCrypto.formatFingerprint(recipient.recipientPubkeyFingerprint),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient.recipientEmail,
                  style: TextStyle(fontSize: 13, color: context.colors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  fingerprint,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: context.colors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _roleBadge(recipient.shareRole),
          IconButton(
            tooltip: AppLocalizations.of(context).sharesRevoke,
            icon: Icon(
              AppIcons.memberRemove,
              size: 18,
              color: context.colors.iconCrimson,
            ),
            onPressed: () => _revoke(recipient),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge(ShareRole role) {
    final l10n = AppLocalizations.of(context);
    final label = switch (role) {
      ShareRole.reader => l10n.sharesRoleReader,
      ShareRole.editor => l10n.sharesRoleEditor,
      ShareRole.coOwner => l10n.sharesRoleCoOwner,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.seam,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: context.colors.textMuted),
      ),
    );
  }

  static String _abbreviate(String full) {
    if (full.length <= 19) return full;
    return '${full.substring(0, 10)}…-${full.substring(full.length - 4)}';
  }
}
