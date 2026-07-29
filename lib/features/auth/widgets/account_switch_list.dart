import 'package:flutter/material.dart';

import '../../../core/storage/database.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../l10n/generated/app_localizations.dart';

/// An account other than the one the unlock screen currently targets, offered
/// in the "switch account" list.
class OtherAccount {
  final Account account;
  final Server? server;
  const OtherAccount({required this.account, this.server});
}

/// The "switch account" list under the passcode entry. Flat style (no card or
/// section background) to match the unlock screen. Hides itself when there are
/// no other accounts, so callers can place it unconditionally.
class AccountSwitchList extends StatelessWidget {
  final List<OtherAccount> accounts;
  final bool loading;
  final void Function(OtherAccount) onSwitch;

  const AccountSwitchList({
    super.key,
    required this.accounts,
    required this.loading,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.authSwitchAccount,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...accounts.map(
          (entry) => _AccountRow(
            email: entry.account.email,
            serverName: entry.server?.name ?? l10n.authUnknownServer,
            onTap: loading ? null : () => onSwitch(entry),
          ),
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  final String email;
  final String serverName;
  final VoidCallback? onTap;

  const _AccountRow({
    required this.email,
    required this.serverName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            UserAvatar(email: email, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    serverName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
