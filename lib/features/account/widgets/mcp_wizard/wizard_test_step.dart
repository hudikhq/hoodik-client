import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/mcp/mcp_connection_tester.dart';
import '../../../../core/widgets/adaptive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'wizard_step_scaffold.dart';

/// The three possible states of step 4 of the wizard.
enum WizardTestState { idle, running, success, failure }

/// Step 4 of the connect wizard. Runs an in-process `initialize` request
/// against the local MCP server using the configured bearer token and
/// surfaces the result verbatim (server info, protocol version,
/// capabilities) so users see the same handshake their AI client will
/// see.
class WizardTestStep extends StatelessWidget {
  const WizardTestStep({
    super.key,
    required this.state,
    required this.result,
    required this.onRun,
    required this.onFinish,
  });

  final WizardTestState state;
  final McpTestResult? result;
  final Future<void> Function() onRun;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return WizardStepScaffold(
      title: l10n.accountWizardStep4Title,
      subtitle: l10n.accountWizardStep4Subtitle,
      primaryLabel: state == WizardTestState.success
          ? l10n.accountWizardFinish
          : l10n.accountWizardRunTest,
      onPrimary: state == WizardTestState.running
          ? null
          : (state == WizardTestState.success ? onFinish : () => onRun()),
      primaryDisabled: state == WizardTestState.running,
      secondaryLabel: state == WizardTestState.failure
          ? l10n.accountWizardTryAgain
          : null,
      onSecondary: state == WizardTestState.failure ? () => onRun() : null,
      child: _TestResultCard(state: state, result: result),
    );
  }
}

class _TestResultCard extends StatelessWidget {
  const _TestResultCard({required this.state, required this.result});

  final WizardTestState state;
  final McpTestResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, title, body) = _renderFor(
      state,
      result,
      AppLocalizations.of(context),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                body,
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String, Widget) _renderFor(
    WizardTestState state,
    McpTestResult? result,
    AppLocalizations l10n,
  ) {
    switch (state) {
      case WizardTestState.idle:
        return (
          CupertinoIcons.play_circle,
          CupertinoColors.systemGrey,
          l10n.accountWizardReadyTitle,
          Text(
            l10n.accountWizardReadyBody,
            style: const TextStyle(fontSize: 13),
          ),
        );
      case WizardTestState.running:
        return (
          CupertinoIcons.hourglass,
          CupertinoColors.activeBlue,
          l10n.accountWizardTesting,
          Row(
            children: [
              const AdaptiveLoadingIndicator(radius: 8),
              const SizedBox(width: 8),
              Text(
                l10n.accountWizardCallingInitialize,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        );
      case WizardTestState.success:
        return (
          CupertinoIcons.check_mark_circled_solid,
          CupertinoColors.activeGreen,
          l10n.accountWizardConnected,
          _SuccessBody(result: result),
        );
      case WizardTestState.failure:
        final message = result?.error ?? l10n.accountWizardConnectionFailed;
        return (
          CupertinoIcons.exclamationmark_triangle_fill,
          CupertinoColors.destructiveRed,
          l10n.accountWizardFailed,
          Text(message, style: const TextStyle(fontSize: 13)),
        );
    }
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.result});

  final McpTestResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final caps = result?.capabilities ?? const <String>[];
    final name = result?.serverName ?? 'hoodik';
    final version = result?.serverVersion ?? '';
    final protocol = result?.protocolVersion ?? '';
    final details = StringBuffer(l10n.accountWizardServerName(name));
    if (version.isNotEmpty) details.write(' $version');
    if (protocol.isNotEmpty) {
      details.write(' · ${l10n.accountWizardProtocol(protocol)}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          details.toString(),
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          caps.isEmpty
              ? l10n.accountWizardCapabilitiesNone
              : l10n.accountWizardCapabilitiesList(caps.join(', ')),
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
