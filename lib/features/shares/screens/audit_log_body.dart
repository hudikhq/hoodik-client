import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/connectivity_error.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/audit_log_notifier.dart';
import '../widgets/audit_log_row.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Sharing activity log: the caller's share events newest-first, each with the
/// action in plain English, the timestamp, and a tri-state integrity badge
/// verified entirely client-side (per-sender hash chain + per-row sender
/// signature). Self-sufficient — drives its own [auditLogNotifierProvider] so
/// it renders inside the Share hub's "Activity" tab without a Scaffold.
/// Mirrors the web `ShareHubAudit`.
class AuditLogBody extends ConsumerWidget {
  const AuditLogBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auditLogNotifierProvider);
    return state.when(
      loading: () => const Center(child: AdaptiveLoadingIndicator(radius: 12)),
      error: (error, _) => _ErrorBody(
        error: error,
        onRetry: () => ref.read(auditLogNotifierProvider.notifier).refresh(),
      ),
      data: (loaded) => _AuditBody(state: loaded),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final offline = isConnectivityError(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.cloud_off_outlined : AppIcons.error,
              size: 32,
              color: context.colors.iconMuted,
            ),
            const SizedBox(height: 12),
            Text(
              offline
                  ? l10n.sharesAuditLoadFailedOffline
                  : l10n.sharesAuditLoadFailed,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textMuted),
            ),
            if (!offline) ...[
              const SizedBox(height: 6),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.colors.textMuted),
              ),
            ],
            const SizedBox(height: 16),
            AdaptiveButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}

class _AuditBody extends StatelessWidget {
  const _AuditBody({required this.state});

  final AuditLogState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            key: const ValueKey('audit-empty'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.seam, width: 0.5),
            ),
            child: Text(
              l10n.sharesAuditEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.colors.textMuted),
            ),
          ),
        ),
      );
    }

    final capped = state.total > state.rows.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _Legend(),
        const SizedBox(height: 12),
        for (final row in state.rows) AuditLogRow(row: row),
        if (capped)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.sharesAuditShowingRecent(state.rows.length, state.total),
              style: TextStyle(fontSize: 12, color: context.colors.textMuted),
            ),
          ),
      ],
    );
  }
}

/// Legend for the tri-state badge. The "mismatch" row is the one that matters —
/// it tells the reader what a red banner means before they hit one.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.seam, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendItem(
            icon: AppIcons.verified,
            color: context.colors.textSage,
            label: l10n.sharesAuditBadgeVerified,
            description: l10n.sharesAuditLegendVerified,
          ),
          const SizedBox(height: 6),
          _LegendItem(
            icon: AppIcons.settings,
            color: context.colors.iconMuted,
            label: l10n.sharesAuditBadgeSystem,
            description: l10n.sharesAuditLegendSystem,
          ),
          const SizedBox(height: 6),
          _LegendItem(
            icon: AppIcons.error,
            color: context.colors.onCrimsonWash,
            label: l10n.sharesAuditBadgeMismatch,
            description: l10n.sharesAuditLegendMismatch,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label — ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: description,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
