import 'package:flutter/material.dart';

import '../../../core/crypto/share_crypto.dart' show ChainRowStatus;
import '../../../core/utils/format.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/audit_log_notifier.dart';
import 'audit_event_sentence.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// One audit-log row: the action sentence, the timestamp, and a tri-state
/// integrity badge. Mirrors the web `ShareHubAudit` row treatment —
/// [AuditRowBadge.verified] is quiet, [AuditRowBadge.system] is a neutral
/// pill, and [AuditRowBadge.tampered] is a loud red banner naming the failing
/// check. The row's `chainStatus` disambiguates the tampered headline
/// (self-hash vs link) and surfaces a quiet page-boundary note when an earlier
/// event in the chain fell outside the loaded page.
class AuditLogRow extends StatelessWidget {
  const AuditLogRow({super.key, required this.row});

  final AuditDisplayRow row;

  ChainRowStatus get chainStatus => row.chainStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.seam, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 1, right: 10),
                  child: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: context.colors.iconMuted,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auditEventSentence(
                          event: row.event,
                          senderEmail: row.senderEmail,
                          recipientEmail: row.recipientEmail,
                          fileLabel: row.fileLabel,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Tooltip(
                        message: formatAbsoluteTimestamp(
                          row.event.createdAt,
                          includeTime: true,
                        ),
                        child: Text(
                          formatRelativeTimestamp(row.event.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ),
                      if (chainStatus == ChainRowStatus.pageBoundary &&
                          row.badge != AuditRowBadge.tampered)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            l10n.sharesAuditPageBoundaryNote,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _badge(context, l10n),
              ],
            ),
          ),
          if (row.badge == AuditRowBadge.tampered)
            _tamperedBanner(context, l10n),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, AppLocalizations l10n) {
    switch (row.badge) {
      case AuditRowBadge.verified:
        return _pill(
          icon: AppIcons.verified,
          label: l10n.sharesAuditBadgeVerified,
          fg: context.colors.textSage,
          bg: context.colors.sageWash,
        );
      case AuditRowBadge.system:
        return _pill(
          icon: AppIcons.settings,
          label: l10n.sharesAuditBadgeSystem,
          fg: context.colors.textMuted,
          bg: context.colors.recess,
        );
      case AuditRowBadge.tampered:
        return _pill(
          icon: AppIcons.error,
          label: l10n.sharesAuditBadgeMismatch,
          fg: context.colors.onCrimsonWash,
          bg: context.colors.crimsonContainer,
        );
    }
  }

  Widget _tamperedBanner(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.crimsonWash,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        border: Border(top: BorderSide(color: context.colors.crimsonContainer)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 1),
            child: Icon(
              AppIcons.error,
              size: 18,
              color: context.colors.onCrimsonWash,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tamperedHeadline(l10n),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.onCrimsonWash,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.sharesAuditTamperedBody,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.onCrimsonWash,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The most-severe failing check, so the reader has a concrete starting
  /// point. A broken chain link or self-hash mismatch points at deletion /
  /// forgery; otherwise the signature failed against the named sender. Mirrors
  /// the web `tamperedHeadline`, which leads with the chain break when present.
  String _tamperedHeadline(AppLocalizations l10n) {
    switch (chainStatus) {
      case ChainRowStatus.selfHashMismatch:
        return l10n.sharesAuditSelfHashMismatch;
      case ChainRowStatus.linkBroken:
        return l10n.sharesAuditLinkBroken;
      case ChainRowStatus.linked:
      case ChainRowStatus.pageBoundary:
        return l10n.sharesAuditSignatureFailed;
    }
  }

  static Widget _pill({
    required IconData icon,
    required String label,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, letterSpacing: 0.3, color: fg),
          ),
        ],
      ),
    );
  }
}
