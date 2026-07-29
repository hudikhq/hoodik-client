import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';

class ManageAccountsTile extends StatelessWidget {
  const ManageAccountsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdaptiveListTile(
      leading: Icon(
        isApplePlatform ? CupertinoIcons.person_2 : Icons.switch_account,
        size: 22,
      ),
      title: Text(l10n.accountManageAccounts),
      subtitle: Text(l10n.accountManageAccountsSubtitle),
      onTap: () => context.push('/setup/server'),
    );
  }
}
