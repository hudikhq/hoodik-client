import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/utils/format.dart' as fmt;
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';

class StorageQuotaTile extends ConsumerWidget {
  const StorageQuotaTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    final l10n = AppLocalizations.of(context);

    return AdaptiveListTile(
      leading: Icon(
        isApplePlatform ? CupertinoIcons.tray_full : Icons.storage,
        size: 22,
      ),
      title: Text(l10n.accountStorageTitle),
      subtitle: Text(
        account?.quota != null
            ? l10n.accountStorageQuota(fmt.formatBytes(account!.quota!))
            : l10n.accountStorageUnlimited,
      ),
    );
  }
}
