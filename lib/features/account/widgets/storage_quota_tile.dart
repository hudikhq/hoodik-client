import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/utils/format.dart' as fmt;
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/app_icons.dart';

class StorageQuotaTile extends ConsumerWidget {
  const StorageQuotaTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    final usage = ref.watch(storageUsageProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);

    // Live figures when the stats call resolved; the cached quota (or
    // "unlimited") until then and on servers without the stats route.
    final quota = usage != null ? usage.quota : account?.quota;
    final String subtitle;
    if (usage != null && quota != null) {
      subtitle = l10n.accountStorageUsedOfTotal(
        fmt.formatBytes(usage.usedSpace),
        fmt.formatBytes(quota),
      );
    } else if (usage != null) {
      subtitle =
          '${l10n.accountStorageUnlimited} · '
          '${l10n.accountStorageUsed(fmt.formatBytes(usage.usedSpace))}';
    } else if (quota != null) {
      subtitle = l10n.accountStorageQuota(fmt.formatBytes(quota));
    } else {
      subtitle = l10n.accountStorageUnlimited;
    }

    return AdaptiveListTile(
      leading: Icon(
        isApplePlatform ? CupertinoIcons.tray_full : AppIcons.storage,
        size: 22,
      ),
      title: Text(l10n.accountStorageTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(subtitle),
          if (usage != null && quota != null && quota > 0) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (usage.usedSpace / quota).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: HoodikColors.brownish500,
                color: HoodikColors.iconCrimson,
              ),
            ),
            const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}
