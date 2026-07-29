import '../../../core/api/share_event_models.dart';
import '../../../core/crypto/share_crypto.dart'
    show AuditEventAction, ShareRole;
import '../../../core/utils/l10n_lookup.dart';
import '../../../l10n/generated/app_localizations.dart';

/// One-line everyday-English description of an audit event, mirroring the web
/// `ShareHubAudit.rowSentence`. Keeps a consistent
/// `sender verb object [with recipient] [as role]` shape so a glance down the
/// list reads naturally. [senderEmail] / [recipientEmail] and
/// [fileLabel] are pre-resolved by the notifier (emails from the page's `users`
/// map, the label decrypted or a bare-id fallback).
String auditEventSentence({
  required AppShareEvent event,
  required String senderEmail,
  required String recipientEmail,
  required String fileLabel,
}) {
  final l10n = ambientL10n;
  final roleAfter = _role(l10n, event.shareRoleAfter);
  final roleBefore = _role(l10n, event.shareRoleBefore);
  final recipient = recipientEmail.isEmpty ? null : recipientEmail;

  switch (event.action) {
    case AuditEventAction.grant:
      final to = recipient ?? l10n.sharesAuditARecipient;
      return roleAfter == null
          ? l10n.sharesAuditGrant(senderEmail, fileLabel, to)
          : l10n.sharesAuditGrantAsRole(senderEmail, fileLabel, to, roleAfter);
    case AuditEventAction.sharedByCoOwner:
      final to = recipient ?? l10n.sharesAuditARecipient;
      return roleAfter == null
          ? l10n.sharesAuditReshared(senderEmail, fileLabel, to)
          : l10n.sharesAuditResharedAsRole(
              senderEmail,
              fileLabel,
              to,
              roleAfter,
            );
    case AuditEventAction.revoke:
      return l10n.sharesAuditRevoked(
        senderEmail,
        recipient ?? l10n.sharesAuditAccessFallback,
        fileLabel,
      );
    case AuditEventAction.roleChange:
      final target = recipient ?? l10n.sharesAuditRecipientFallback;
      if (roleBefore != null && roleAfter != null) {
        return l10n.sharesAuditRoleChangedFromTo(
          senderEmail,
          target,
          fileLabel,
          roleBefore,
          roleAfter,
        );
      }
      return l10n.sharesAuditRoleChanged(senderEmail, target, fileLabel);
    case AuditEventAction.fork:
      return l10n.sharesAuditForked(senderEmail, fileLabel);
    case AuditEventAction.sharedFolderUpload:
      return l10n.sharesAuditUploaded(senderEmail, fileLabel);
    case AuditEventAction.sharedFolderEdit:
      return l10n.sharesAuditEdited(senderEmail, fileLabel);
    case AuditEventAction.sharedFolderRestore:
      return l10n.sharesAuditRestored(senderEmail, fileLabel);
    case AuditEventAction.sharedFolderEvict:
      return l10n.sharesAuditEvicted(
        recipient ?? l10n.sharesAuditARecipientCapital,
        fileLabel,
      );
    case AuditEventAction.sharedFolderMoveOut:
      return l10n.sharesAuditMovedOut(senderEmail, fileLabel);
    case AuditEventAction.sharedByCoOwnerRevoked:
      return l10n.sharesAuditCoOwnerRevoked(
        recipient ?? l10n.sharesAuditARecipientCapital,
        fileLabel,
      );
    case AuditEventAction.keyRotation:
      return l10n.sharesAuditKeyRotation(senderEmail);
  }
}

/// Short label for an action, used in the filter and as the disclosure header.
/// Mirrors the web `ACTION_LABELS`.
String auditActionLabel(AuditEventAction action) {
  switch (action) {
    case AuditEventAction.grant:
      return 'Shared';
    case AuditEventAction.revoke:
      return 'Revoked';
    case AuditEventAction.roleChange:
      return 'Changed role';
    case AuditEventAction.sharedFolderUpload:
      return 'Uploaded into shared folder';
    case AuditEventAction.fork:
      return 'Forked';
    case AuditEventAction.sharedByCoOwner:
      return 'Re-shared as co-owner';
    case AuditEventAction.sharedFolderEdit:
      return 'Edited shared file';
    case AuditEventAction.sharedFolderRestore:
      return 'Restored shared version';
    case AuditEventAction.sharedFolderEvict:
      return 'Cascade revoked';
    case AuditEventAction.sharedFolderMoveOut:
      return 'Moved out of shared folder';
    case AuditEventAction.sharedByCoOwnerRevoked:
      return 'Co-owner access revoked';
    case AuditEventAction.keyRotation:
      return 'Rotated keys';
  }
}

String? _role(AppLocalizations l10n, ShareRole? role) {
  return switch (role) {
    null => null,
    ShareRole.reader => l10n.sharesRoleReader,
    ShareRole.editor => l10n.sharesRoleEditor,
    ShareRole.coOwner => l10n.sharesRoleCoOwner,
  };
}
