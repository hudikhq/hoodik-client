import 'package:flutter/material.dart';

import '../../../core/theme/hoodik_colors.dart';
import '../../../l10n/generated/app_localizations.dart';

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
        color: HoodikColors.brownish800,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            email,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: HoodikColors.dirtyWhite,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          SelectableText(
            formattedFingerprint,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: HoodikColors.textMuted,
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
        icon: Icons.verified_user,
        color: HoodikColors.greeny300,
        child: Text(
          l10n.sharesTrustVerified,
          style: const TextStyle(fontSize: 12, color: HoodikColors.greeny300),
        ),
      ),
      ShareTrustStatus.firstSight => _banner(
        icon: Icons.shield_outlined,
        color: HoodikColors.iconMuted,
        child: Text(
          l10n.sharesTrustFirstSight,
          style: const TextStyle(fontSize: 12, color: HoodikColors.textMuted),
        ),
      ),
      ShareTrustStatus.mismatch => _mismatchBody(l10n),
    };
  }

  Widget _mismatchBody(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HoodikColors.redish900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HoodikColors.redish400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: HoodikColors.redish50,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.sharesTrustMismatchBody,
                  style: const TextStyle(
                    fontSize: 12,
                    color: HoodikColors.redish50,
                  ),
                ),
              ),
            ],
          ),
          if (cachedFingerprint != null) ...[
            const SizedBox(height: 8),
            _fingerprintRow(l10n.sharesPreviouslyTrusted, cachedFingerprint!),
            const SizedBox(height: 4),
            _fingerprintRow(l10n.sharesServerReturnedNow, formattedFingerprint),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: HoodikColors.dirtyWhite,
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

  Widget _fingerprintRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: HoodikColors.redish50,
            letterSpacing: 0.5,
          ),
        ),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: HoodikColors.dirtyWhite,
          ),
        ),
      ],
    );
  }

  Widget _banner({
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

  Color get _borderColor => switch (status) {
    ShareTrustStatus.mismatch => HoodikColors.redish400,
    ShareTrustStatus.verified => HoodikColors.greeny400,
    ShareTrustStatus.firstSight => HoodikColors.brownish600,
  };
}
