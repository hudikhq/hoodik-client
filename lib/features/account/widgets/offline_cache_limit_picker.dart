import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/services/offline_cache_lru.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';

const cacheLimitChoices = [
  kCacheLimit2Gb,
  kDefaultCacheLimitBytes,
  kCacheLimit32Gb,
  0,
];

/// Label for the stored [cacheLimitBytes] value (null → 8 GB default).
String cacheLimitLabel(AppLocalizations l10n, int? stored) {
  final n = stored ?? kDefaultCacheLimitBytes;
  if (n == 0) return l10n.accountCacheLimitUnlimited;
  if (n == kCacheLimit2Gb) return l10n.accountCacheLimit2Gb;
  if (n == kCacheLimit32Gb) return l10n.accountCacheLimit32Gb;
  return l10n.accountCacheLimit8Gb;
}

/// Bottom sheet: 2 GB / 8 GB / 32 GB / Unlimited.
Future<int?> pickOfflineCacheLimit({
  required BuildContext context,
  required int? current,
}) {
  final selected = current ?? kDefaultCacheLimitBytes;
  return showModalBottomSheet<int>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.accountCacheLimitTitle,
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
            ),
            for (final bytes in cacheLimitChoices)
              ListTile(
                title: Text(cacheLimitLabel(l10n, bytes)),
                trailing: bytes == selected
                    ? Icon(
                        adaptiveIcon(
                          material: Icons.check,
                          cupertino: CupertinoIcons.check_mark,
                        ),
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(bytes),
              ),
          ],
        ),
      );
    },
  );
}
