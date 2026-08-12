import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/format.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/theme/hoodik_scheme.dart';

/// Top-of-screen banner for the MCP settings screen: colored status dot,
/// running-state label, and the last time an agent made a call.
///
/// Purely presentational — the parent owns the running/last-seen state and
/// re-renders as it changes.
class McpStatusHeader extends StatelessWidget {
  const McpStatusHeader({
    super.key,
    required this.isRunning,
    required this.isPaused,
    required this.port,
    required this.lastSeenAt,
  });

  final bool isRunning;

  /// True when the server has been stopped by the user but the feature is
  /// still enabled in settings. Distinguishes "I turned it off" from
  /// "nobody ever enabled it".
  final bool isPaused;
  final int port;
  final DateTime? lastSeenAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _resolveStatus(context, AppLocalizations.of(context));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: status.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: status.color,
                boxShadow: [
                  BoxShadow(
                    color: status.color.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(status.icon, color: status.color, size: 22),
          ],
        ),
      ),
    );
  }

  _StatusDescriptor _resolveStatus(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    if (isRunning) {
      final seen = lastSeenAt == null
          ? l10n.accountMcpNoAgentActivity
          : l10n.accountMcpLastAgentCall(formatRelativeTime(lastSeenAt!));
      return _StatusDescriptor(
        title: l10n.accountMcpStatusRunning,
        color: context.colors.iconSage,
        icon: CupertinoIcons.bolt_fill,
        subtitle: 'localhost:$port • $seen',
      );
    }
    if (isPaused) {
      return _StatusDescriptor(
        title: l10n.accountMcpStatusPaused,
        color: context.colors.iconEmber,
        icon: CupertinoIcons.pause_circle,
        subtitle: l10n.accountMcpPausedSubtitle(port),
      );
    }
    return _StatusDescriptor(
      title: l10n.accountMcpStatusOff,
      color: context.colors.iconMuted,
      icon: CupertinoIcons.bolt_slash,
      subtitle: l10n.accountMcpOffSubtitle,
    );
  }
}

class _StatusDescriptor {
  final String title;
  final Color color;
  final IconData icon;
  final String subtitle;

  const _StatusDescriptor({
    required this.title,
    required this.color,
    required this.icon,
    required this.subtitle,
  });
}
