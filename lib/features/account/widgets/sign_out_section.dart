import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/app_icons.dart';

class SignOutSection extends ConsumerWidget {
  const SignOutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasActiveTransfers = ref.watch(
      transferManagerProvider.select((m) => m.hasActiveTransfers),
    );

    final disabledColor = theme.colorScheme.onSurface.withValues(alpha: 0.3);
    final accentColor = hasActiveTransfers
        ? disabledColor
        : theme.colorScheme.error;

    return AdaptiveListSection(
      children: [
        AdaptiveListTile(
          key: const Key('signOutTile'),
          leading: Icon(
            isApplePlatform
                ? CupertinoIcons.square_arrow_right
                : AppIcons.signOut,
            color: accentColor,
            size: 22,
          ),
          title: Text(
            l10n.accountSignOut,
            style: TextStyle(color: accentColor),
          ),
          subtitle: hasActiveTransfers
              ? Text(l10n.accountActiveTransfers)
              : null,
          trailing: const SizedBox.shrink(),
          onTap: hasActiveTransfers
              ? null
              : () => _confirmAndLogout(context, ref),
        ),
      ],
    );
  }

  Future<void> _confirmAndLogout(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.accountSignOut,
      content: l10n.accountSignOutConfirm,
      actions: [
        AdaptiveDialogAction(
          label: l10n.commonCancel,
          value: false,
          isDefault: true,
        ),
        AdaptiveDialogAction(
          label: l10n.accountSignOut,
          value: true,
          isDestructive: true,
        ),
      ],
    );

    if (confirmed != true) return;

    final authService = ref.read(authServiceProvider);
    await authService.logout();

    if (!context.mounted) return;
    ref.setLoggedOut();
    context.go('/setup/server');
  }
}
