import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/adaptive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/theme/hoodik_scheme.dart';

/// Bundle of destructive-ish shortcuts for the MCP settings screen:
/// stop the server, rotate the bearer token, clear the audit log. Each
/// callback fires an adaptive confirmation dialog before running.
///
/// Receiving a null callback disables the corresponding tile — the parent
/// uses this to grey out "Stop server" when the server isn't running and
/// the other two once the bearer token is missing.
class McpQuickActions extends StatelessWidget {
  const McpQuickActions({
    super.key,
    required this.onStopServer,
    required this.onRotateToken,
    required this.onClearAuditLog,
    required this.isRunning,
  });

  final VoidCallback? onStopServer;
  final VoidCallback? onRotateToken;
  final VoidCallback? onClearAuditLog;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AdaptiveListSection(
      header: l10n.accountMcpQuickActionsHeader,
      children: [
        AdaptiveListTile(
          leading: Icon(
            CupertinoIcons.stop_circle,
            size: 22,
            color: isRunning ? context.colors.iconCrimson : null,
          ),
          title: Text(l10n.accountMcpStopServer),
          subtitle: Text(
            isRunning
                ? l10n.accountMcpStopServerSubtitle
                : l10n.accountMcpNotRunning,
          ),
          onTap: isRunning ? onStopServer : null,
        ),
        AdaptiveListTile(
          leading: Icon(
            CupertinoIcons.arrow_2_circlepath,
            size: 22,
            color: theme.colorScheme.error,
          ),
          title: Text(l10n.accountMcpRotateToken),
          subtitle: Text(l10n.accountMcpRotateTokenSubtitle),
          onTap: onRotateToken,
        ),
        AdaptiveListTile(
          leading: Icon(
            CupertinoIcons.delete,
            size: 22,
            color: theme.colorScheme.error,
          ),
          title: Text(l10n.accountMcpClearAuditLog),
          subtitle: Text(l10n.accountMcpClearAuditLogSubtitle),
          onTap: onClearAuditLog,
        ),
      ],
    );
  }
}
