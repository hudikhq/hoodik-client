import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/adaptive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'wizard_step_scaffold.dart';

/// Visible form of the bearer token. `masked` shows the first four + last
/// four characters around a bullet fill; `plain` is the full token. Kept
/// separate from the token string so the widget can re-render without
/// touching the underlying state.
enum TokenVisibility { masked, plain }

/// Step 2 of the connect wizard. Shows the bearer token (masked by
/// default), with copy/regenerate/reveal controls that delegate to the
/// parent. Regeneration is behind an adaptive confirm dialog because it
/// invalidates every AI client already configured against the old token.
class WizardCredentialsStep extends StatelessWidget {
  const WizardCredentialsStep({
    super.key,
    required this.bearerToken,
    required this.visibility,
    required this.onCopy,
    required this.onToggleVisibility,
    required this.onRegenerate,
    required this.onNext,
    required this.busy,
  });

  final String bearerToken;
  final TokenVisibility visibility;
  final VoidCallback onCopy;
  final VoidCallback onToggleVisibility;
  final Future<void> Function() onRegenerate;
  final VoidCallback onNext;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return WizardStepScaffold(
      title: l10n.accountWizardStep2Title,
      subtitle: l10n.accountWizardStep2Subtitle,
      primaryLabel: l10n.accountWizardNext,
      onPrimary: bearerToken.isEmpty || busy ? null : onNext,
      primaryDisabled: bearerToken.isEmpty || busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.lock_shield, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    bearerToken.isEmpty
                        ? l10n.accountWizardNoToken
                        : _formatToken(bearerToken, visibility),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                    maxLines: 1,
                  ),
                ),
                IconButton(
                  tooltip: visibility == TokenVisibility.masked
                      ? l10n.accountWizardShowToken
                      : l10n.accountWizardHideToken,
                  icon: Icon(
                    visibility == TokenVisibility.masked
                        ? CupertinoIcons.eye
                        : CupertinoIcons.eye_slash,
                    size: 20,
                  ),
                  onPressed: bearerToken.isEmpty ? null : onToggleVisibility,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AdaptiveTextButton(
                  onPressed: bearerToken.isEmpty ? null : onCopy,
                  child: Text(l10n.accountWizardCopyToken),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdaptiveTextButton(
                  onPressed: busy ? null : () => _confirmRegenerate(context),
                  isDestructive: true,
                  child: Text(l10n.accountMcpRegenerate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRegenerate(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final result = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.accountWizardRegenerateConfirmTitle,
      content: l10n.accountWizardRegenerateConfirmBody,
      actions: [
        AdaptiveDialogAction(label: l10n.commonCancel, value: false),
        AdaptiveDialogAction(
          label: l10n.accountMcpRegenerate,
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (result == true) {
      await onRegenerate();
    }
  }

  static String _formatToken(String token, TokenVisibility visibility) {
    if (visibility == TokenVisibility.plain) return token;
    if (token.length <= 10) return '\u2022' * token.length;
    final head = token.substring(0, 4);
    final tail = token.substring(token.length - 4);
    return '$head\u2022\u2022\u2022$tail';
  }
}
