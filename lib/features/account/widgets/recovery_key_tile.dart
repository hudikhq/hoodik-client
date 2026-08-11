import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Entry point to the recovery-key export. Hidden while the private key is
/// not decrypted in memory — there is nothing to export then.
class RecoveryKeyTile extends ConsumerWidget {
  const RecoveryKeyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(decryptedPrivateKeyProvider) == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);

    return AdaptiveListTile(
      leading: Icon(
        isApplePlatform ? CupertinoIcons.lock_shield : Icons.key_outlined,
        size: 22,
        color: context.colors.iconEmber,
      ),
      title: Text(l10n.accountRecoveryKeyTitle),
      subtitle: Text(l10n.accountRecoveryKeySubtitle),
      onTap: () => context.push('/account/recovery-key'),
    );
  }
}
