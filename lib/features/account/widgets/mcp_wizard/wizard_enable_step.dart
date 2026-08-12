import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'wizard_step_scaffold.dart';
import '../../../../core/theme/hoodik_scheme.dart';

/// Step 1 of the connect wizard. Confirms the MCP server is running and
/// offers a single button to start it if it isn't. The wizard delegates
/// the actual start work to its parent — this widget is stateless and
/// simply surfaces the current running/port state.
class WizardEnableStep extends StatelessWidget {
  const WizardEnableStep({
    super.key,
    required this.isRunning,
    required this.port,
    required this.busy,
    required this.errorMessage,
    required this.onEnable,
    required this.onNext,
  });

  final bool isRunning;
  final int port;
  final bool busy;
  final String? errorMessage;
  final Future<void> Function() onEnable;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return WizardStepScaffold(
      title: l10n.accountWizardStep1Title,
      subtitle: l10n.accountWizardStep1Subtitle,
      primaryLabel: isRunning ? l10n.accountWizardNext : l10n.accountMcpEnable,
      onPrimary: busy ? null : (isRunning ? onNext : () => onEnable()),
      primaryDisabled: busy,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isRunning ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt_slash,
              size: 32,
              color: isRunning
                  ? context.colors.iconSage
                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRunning
                        ? l10n.accountMcpStatusRunning
                        : l10n.accountMcpNotRunning,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isRunning
                        ? 'http://localhost:$port/mcp'
                        : l10n.accountWizardEnableHint,
                    style: TextStyle(
                      fontFamily: isRunning ? 'monospace' : null,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isRunning) WizardDoneBadge(label: l10n.accountEnabled),
          ],
        ),
      ),
    );
  }
}
