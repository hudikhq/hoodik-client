import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/services/recovery_bundle.dart';

/// Shows the active account's recovery key — the credential that gets the
/// user back in when the password is gone. Assembled entirely from the keys
/// already decrypted in memory; nothing here talks to the server.
class RecoveryKeyScreen extends ConsumerStatefulWidget {
  const RecoveryKeyScreen({super.key});

  @override
  ConsumerState<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends ConsumerState<RecoveryKeyScreen> {
  bool _revealed = false;

  Future<void> _copy(String recoveryKey) async {
    await Clipboard.setData(ClipboardData(text: recoveryKey));
    if (mounted) {
      AppNotification.show(
        context,
        message: AppLocalizations.of(context).accountRecoveryKeyCopied,
        type: NotificationType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recoveryKey = recoveryKeyOf(
      identity: ref.watch(decryptedPrivateKeyProvider),
      wrapping: ref.watch(decryptedWrappingPrivateKeyProvider),
      legacyRsa: ref.watch(authServiceProvider).decryptedLegacyRsaPrivateKey,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).accountRecoveryKeyTitle),
        centerTitle: isApplePlatform,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: recoveryKey == null
                ? Text(
                    AppLocalizations.of(context).accountRecoveryKeyLocked,
                    style: theme.textTheme.bodyMedium,
                  )
                : _RecoveryKeyBody(
                    recoveryKey: recoveryKey,
                    revealed: _revealed,
                    onToggleReveal: () =>
                        setState(() => _revealed = !_revealed),
                    onCopy: () => _copy(recoveryKey),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RecoveryKeyBody extends StatelessWidget {
  const _RecoveryKeyBody({
    required this.recoveryKey,
    required this.revealed,
    required this.onToggleReveal,
    required this.onCopy,
  });

  final String recoveryKey;
  final bool revealed;
  final VoidCallback onToggleReveal;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.accountRecoveryKeyBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AdaptiveButton(
                key: const Key('revealRecoveryKey'),
                onPressed: onToggleReveal,
                child: Text(
                  revealed
                      ? l10n.accountRecoveryHide
                      : l10n.accountRecoveryReveal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AdaptiveButton(
                key: const Key('copyRecoveryKey'),
                onPressed: onCopy,
                child: Text(l10n.commonCopy),
              ),
            ),
          ],
        ),
        if (revealed) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              recoveryKey,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
