import 'package:flutter/material.dart';

import '../../../core/api/shares_models.dart';
import '../../../core/crypto/share_crypto.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/folder_members_notifier.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../../../core/theme/hoodik_type.dart';

/// One row in the folder members roster: email/id, role badge, the "added by"
/// attribution, the abbreviated fingerprint, and a per-row signature badge.
/// Change / revoke controls show only when [canMutate] and this isn't the
/// owner or the caller's own row. Mirrors the web `FolderMembersView` row.
class FolderMemberTile extends StatelessWidget {
  const FolderMemberTile({
    super.key,
    required this.member,
    required this.ownerId,
    required this.callerId,
    required this.signatureStatus,
    required this.canMutate,
    required this.onChangeRole,
    required this.onRevoke,
  });

  final FolderMember member;
  final String ownerId;
  final String? callerId;
  final MemberSignatureStatus signatureStatus;
  final bool canMutate;
  final VoidCallback onChangeRole;
  final VoidCallback onRevoke;

  bool get _showControls =>
      canMutate && !member.isOwner && member.userId != callerId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.email ?? member.userId,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // The owner has full authority by definition; showing a
                    // role pill (the server reports the owner as co-owner)
                    // alongside "Owner" reads as a contradiction, so the owner
                    // gets only the Owner badge.
                    if (member.isOwner)
                      _ownerBadge(context, l10n)
                    else
                      _roleBadge(context, l10n),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _abbreviate(
                          formatFingerprint(member.pubkeyFingerprint),
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: HoodikType.monoFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: context.colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_addedByLabel(l10n) != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${_addedByLabel(l10n)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                    if (!member.isOwner) ...[
                      const SizedBox(width: 6),
                      _signatureBadge(context),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_showControls) ...[
            IconButton(
              tooltip: member.email == null
                  ? l10n.sharesEmailUnknownCannotChangeRole
                  : l10n.sharesChangeRole,
              icon: Icon(Icons.tune, size: 18, color: context.colors.iconMuted),
              onPressed: member.email == null ? null : onChangeRole,
            ),
            IconButton(
              tooltip: l10n.sharesRevoke,
              icon: Icon(
                AppIcons.memberRemove,
                size: 18,
                color: context.colors.iconCrimson,
              ),
              onPressed: onRevoke,
            ),
          ],
        ],
      ),
    );
  }

  Widget _roleBadge(BuildContext context, AppLocalizations l10n) {
    final label = switch (member.shareRole) {
      ShareRole.reader => l10n.sharesRoleReader,
      ShareRole.editor => l10n.sharesRoleEditor,
      ShareRole.coOwner => l10n.sharesRoleCoOwner,
    };
    return _pill(label, context.colors.recess, context.colors.textMuted);
  }

  Widget _ownerBadge(BuildContext context, AppLocalizations l10n) => _pill(
    l10n.sharesRoleOwner,
    context.colors.sageWash,
    context.colors.sageFill,
  );

  Widget _signatureBadge(BuildContext context) {
    return switch (signatureStatus) {
      MemberSignatureStatus.verified => Icon(
        Icons.verified_outlined,
        size: 13,
        color: context.colors.sageFill,
      ),
      MemberSignatureStatus.failed => Icon(
        Icons.gpp_bad_outlined,
        size: 13,
        color: context.colors.iconCrimson,
      ),
      MemberSignatureStatus.legacy => Icon(
        Icons.help_outline,
        size: 13,
        color: context.colors.iconMuted,
      ),
    };
  }

  String? _addedByLabel(AppLocalizations l10n) {
    if (member.isOwner) return null;
    if (member.signedByUserId == null) return l10n.sharesAddedByUnknown;
    if (member.signedByUserId == ownerId) return l10n.sharesAddedByOwner;
    return l10n.sharesAddedByCoOwner;
  }

  static Widget _pill(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
    );
  }

  /// Quad-group rendering matching [ShareCrypto.formatFingerprint] without
  /// needing a crypto instance — the value is already hex from the server.
  static String formatFingerprint(String hexFp) {
    final upper = hexFp.toUpperCase();
    final chunks = <String>[];
    for (var i = 0; i < upper.length; i += 4) {
      chunks.add(
        upper.substring(i, i + 4 > upper.length ? upper.length : i + 4),
      );
    }
    return chunks.join('-');
  }

  static String _abbreviate(String full) {
    if (full.length <= 19) return full;
    return '${full.substring(0, 10)}…-${full.substring(full.length - 4)}';
  }
}
