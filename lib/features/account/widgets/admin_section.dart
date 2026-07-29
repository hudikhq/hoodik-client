import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';

/// "ADMINISTRATION" section shown only for admin accounts. Parent is
/// responsible for spacing — this widget renders either the section or
/// nothing at all.
class AdminSection extends ConsumerWidget {
  const AdminSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    if (account?.role != 'admin') return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AdaptiveListSection(
      header: l10n.accountAdminHeader,
      children: [
        AdaptiveListTile(
          leading: Icon(
            isApplePlatform
                ? CupertinoIcons.gear_alt
                : Icons.admin_panel_settings,
            size: 22,
            color: theme.colorScheme.secondary,
          ),
          title: Text(l10n.accountAdminPanel),
          subtitle: Text(l10n.accountAdminPanelSubtitle),
          onTap: () => context.push('/admin'),
        ),
      ],
    );
  }
}
