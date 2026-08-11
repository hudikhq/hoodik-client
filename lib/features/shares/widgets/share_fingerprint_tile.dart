import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Trust outcome for a discovered recipient, derived by the share dialog from
/// the local [TrustedFingerprintDao] row:
/// - [firstSight] — no stored row (TOFU). Proceeding records it; never a warning.
/// - [verified] — stored row equals the server's current fingerprint.
/// - [mismatch] — stored row differs. Loud warning; submit stays blocked until
///   the user confirms they checked the new fingerprint out of band.
enum ShareTrustStatus { firstSight, verified, mismatch }

/// Recipient identity card: email, the formatted public-key fingerprint, and a
/// trust state. On [ShareTrustStatus.mismatch] it surfaces the cached vs. new
/// fingerprints and an explicit acknowledgement checkbox — the only gate that
/// re-enables sharing after a key change, mirroring the web mismatch modal.
class ShareFingerprintTile extends StatelessWidget {
  const ShareFingerprintTile({
    super.key,
    required this.email,
    required this.formattedFingerprint,
    required this.status,
    this.cachedFingerprint,
    this.mismatchAcknowledged = false,
    this.onAcknowledgeChanged,
  });

  final String email;
  final String formattedFingerprint;
  final ShareTrustStatus status;

  /// Formatted previously-trusted fingerprint; only set (and shown) on mismatch.
  final String? cachedFingerprint;
  final bool mismatchAcknowledged;
  final ValueChanged<bool>? onAcknowledgeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            email,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          SelectableText(
            formattedFingerprint,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: context.colors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          _statusBody(context),
        ],
      ),
    );
  }

  Widget _statusBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (status) {
      ShareTrustStatus.verified => _banner(
        context: context,
        icon: Icons.verified_user,
        color: context.colors.textSage,
        child: Text(
          l10n.sharesTrustVerified,
          style: TextStyle(fontSize: 12, color: context.colors.textSage),
        ),
      ),
      ShareTrustStatus.firstSight => _banner(
        context: context,
        icon: Icons.shield_outlined,
        color: context.colors.iconMuted,
        child: Text(
          l10n.sharesTrustFirstSight,
          style: TextStyle(fontSize: 12, color: context.colors.textMuted),
        ),
      ),
      ShareTrustStatus.mismatch => _mismatchBody(context, l10n),
    };
  }

  Widget _mismatchBody(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.crimsonWash,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.crimsonFill),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: context.colors.onCrimsonWash,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.sharesTrustMismatchBody,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.onCrimsonWash,
                  ),
                ),
              ),
            ],
          ),
          if (cachedFingerprint != null) ...[
            const SizedBox(height: 8),
            _fingerprintRow(
              context,
              l10n.sharesPreviouslyTrusted,
              cachedFingerprint!,
            ),
            const SizedBox(height: 4),
            _fingerprintRow(
              context,
              l10n.sharesServerReturnedNow,
              formattedFingerprint,
            ),
          ],
          const SizedBox(height: 8),
          InkWell(
            onTap: onAcknowledgeChanged == null
                ? null
                : () => onAcknowledgeChanged!(!mismatchAcknowledged),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: mismatchAcknowledged,
                  onChanged: onAcknowledgeChanged == null
                      ? null
                      : (v) => onAcknowledgeChanged!(v ?? false),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      l10n.sharesMismatchAcknowledge,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fingerprintRow(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: context.colors.onCrimsonWash,
            letterSpacing: 0.5,
          ),
        ),
        SelectableText(
          value,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: context.colors.text,
          ),
        ),
      ],
    );
  }

  Widget _banner({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }

  Color _borderColor(BuildContext context) => switch (status) {
    ShareTrustStatus.mismatch => context.colors.crimsonFill,
    ShareTrustStatus.verified => context.colors.sageFill,
    ShareTrustStatus.firstSight => context.colors.seam,
  };
}
