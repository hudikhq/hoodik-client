import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/providers.dart';
import '../../../core/storage/database.dart';
import '../../../core/utils/format.dart' as fmt;
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/screens/add_server_screen.dart' show selectedServerProvider;

/// Lists every account known to the app and lets the user switch between
/// them. Hidden (collapses to `SizedBox.shrink`) when only one account
/// exists — the parent can include it unconditionally.
class AccountSwitcherSection extends ConsumerStatefulWidget {
  const AccountSwitcherSection({super.key});

  @override
  ConsumerState<AccountSwitcherSection> createState() =>
      _AccountSwitcherSectionState();
}

class _AccountSwitcherSectionState
    extends ConsumerState<AccountSwitcherSection> {
  List<_AccountWithServer> _allAccounts = [];
  String? _loadedAccountId;

  @override
  void initState() {
    super.initState();
    _loadedAccountId = ref.read(activeAccountProvider)?.id;
    _loadAllAccounts();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(activeAccountProvider, (prev, next) {
        if (next != null && next.id != _loadedAccountId) {
          _loadedAccountId = next.id;
          _loadAllAccounts();
        }
      });
    });
  }

  Future<void> _loadAllAccounts() async {
    final authService = ref.read(authServiceProvider);
    final accounts = await authService.getAccounts();
    final servers = await authService.getServers();

    final serverMap = {for (final s in servers) s.id: s};
    final result = accounts.map((a) {
      return _AccountWithServer(account: a, server: serverMap[a.serverId]);
    }).toList();

    if (mounted) {
      setState(() => _allAccounts = result);
    }
  }

  Future<void> _switchToAccount(_AccountWithServer entry) async {
    unawaited(HapticFeedback.selectionClick());
    final authService = ref.read(authServiceProvider);
    final bool success;
    try {
      success = await authService.switchAccount(entry.account.id);
    } catch (e) {
      if (!mounted) return;
      // getSelf / session lookup failed — redirect to login so the user
      // can re-authenticate. Without this, the refresh timer would run
      // with stale expiry info and the session could die silently.
      ref.read(selectedServerProvider.notifier).state = entry.server;
      context.go('/auth/login');
      return;
    }

    if (!success) {
      if (!mounted) return;
      ref.read(selectedServerProvider.notifier).state = entry.server;
      context.go('/auth/login');
      return;
    }

    if (!mounted) return;

    final privateKey = authService.decryptedPrivateKey;

    ref.setLoggedIn(
      account: authService.activeAccount!,
      server: authService.activeServer,
      privateKey: privateKey,
      wrappingPrivateKey: authService.decryptedWrappingPrivateKey,
    );

    if (privateKey != null) {
      context.go(ref.read(landingBranchProvider).route);
    } else {
      // Session is valid but the private key couldn't be recovered silently.
      // If the account has a PIN, send the user to the unlock screen;
      // otherwise, to the login screen.
      final hasPin = await authService.hasPinSetup(entry.account.id);
      if (!mounted) return;
      if (hasPin) {
        context.go('/auth/unlock?accountId=${entry.account.id}');
      } else {
        ref.read(selectedServerProvider.notifier).state = entry.server;
        context.go('/auth/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allAccounts.length <= 1) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final activeAccount = ref.watch(activeAccountProvider);
    final hasActiveTransfers = ref.watch(
      transferManagerProvider.select((m) => m.hasActiveTransfers),
    );

    return Column(
      children: [
        AdaptiveListSection(
          header: l10n.accountAllAccountsHeader,
          children: _allAccounts.map((entry) {
            final isCurrent = activeAccount?.id == entry.account.id;
            return AdaptiveListTile(
              leading: UserAvatar(
                email: entry.account.email,
                radius: 16,
                backgroundColor: isCurrent
                    ? null
                    : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                textColor: isCurrent
                    ? null
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              title: Text(
                entry.account.email,
                style: isCurrent
                    ? TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
              ),
              subtitle: Text(
                '${entry.server?.name ?? l10n.commonUnknown} · ${fmt.formatRelativeTime(entry.account.lastUsedAt)}',
              ),
              trailing: isCurrent
                  ? Icon(
                      isApplePlatform
                          ? CupertinoIcons.checkmark_alt
                          : Icons.check,
                      color: theme.colorScheme.primary,
                      size: 20,
                    )
                  : null,
              onTap: isCurrent || hasActiveTransfers
                  ? null
                  : () => _switchToAccount(entry),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _AccountWithServer {
  final Account account;
  final Server? server;

  const _AccountWithServer({required this.account, this.server});
}
