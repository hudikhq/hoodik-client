import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/offline_cache_lru.dart';
import '../../../core/utils/format.dart' as fmt;
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/app_icons.dart';
import 'offline_cache_limit_picker.dart';

/// Displays the size of the offline cache for the active account and lets
/// the user set the size cap or clear it. Owns its own size/count state so
/// the parent screen doesn't have to thread them through build.
class OfflineCacheTile extends ConsumerStatefulWidget {
  const OfflineCacheTile({super.key});

  @override
  ConsumerState<OfflineCacheTile> createState() => _OfflineCacheTileState();
}

class _OfflineCacheTileState extends ConsumerState<OfflineCacheTile> {
  int _cacheSize = 0;
  int _cacheFileCount = 0;
  String? _loadedAccountId;

  @override
  void initState() {
    super.initState();
    _loadedAccountId = ref.read(activeAccountProvider)?.id;
    _loadCacheStats();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(activeAccountProvider, (prev, next) {
        if (next != null && next.id != _loadedAccountId) {
          _loadedAccountId = next.id;
          _loadCacheStats();
        }
      });
      ref.listenManual(offlineManagerProvider, (prev, next) {
        _loadCacheStats();
      });
    });
  }

  Future<void> _loadCacheStats() async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    final offlineManager = ref.read(offlineManagerProvider);
    final size = await offlineManager.getCacheSize(account.id);
    final count = await offlineManager.getCacheFileCount(account.id);
    if (mounted) {
      setState(() {
        _cacheSize = size;
        _cacheFileCount = count;
      });
    }
  }

  Future<void> _pickLimit() async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    final picked = await pickOfflineCacheLimit(
      context: context,
      current: account.cacheLimitBytes,
    );
    if (picked == null ||
        picked == (account.cacheLimitBytes ?? kDefaultCacheLimitBytes)) {
      return;
    }

    final db = ref.read(databaseProvider);
    await db.setCacheLimitBytes(account.id, picked);
    final updated = await db.getAccountById(account.id);
    if (updated != null) {
      ref.read(activeAccountProvider.notifier).state = updated;
    }
    await ref.read(offlineManagerProvider).enforceLimit(account.id);
    if (mounted) await _loadCacheStats();
  }

  Future<void> _clearOfflineCache() async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.accountOfflineClearTitle,
      content: l10n.accountOfflineClearBody,
      actions: [
        AdaptiveDialogAction(
          label: l10n.commonCancel,
          value: false,
          isDefault: true,
        ),
        AdaptiveDialogAction(
          label: l10n.accountClear,
          value: true,
          isDestructive: true,
        ),
      ],
    );

    if (confirmed != true) return;

    final offlineManager = ref.read(offlineManagerProvider);
    await offlineManager.clearCache(account.id);
    if (!mounted) return;
    await _loadCacheStats();
    if (!mounted) return;
    AppNotification.show(
      context,
      message: l10n.accountOfflineCleared,
      type: NotificationType.success,
    );
  }

  String _subtitle(AppLocalizations l10n, int? cacheLimitBytes) {
    if (_cacheFileCount == 0) return l10n.accountOfflineNoFiles;
    final used = fmt.formatBytes(_cacheSize);
    final limit = resolvedCacheLimitBytes(cacheLimitBytes);
    if (limit == null) return l10n.accountOfflineCacheUnlimited(used);
    return l10n.accountOfflineCacheOfLimit(used, fmt.formatBytes(limit));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(activeAccountProvider);
    final hasFiles = _cacheFileCount > 0;

    return AdaptiveListTile(
      leading: Icon(
        isApplePlatform
            ? CupertinoIcons.arrow_down_circle
            : AppIcons.offlineAvailable,
        size: 22,
        color: hasFiles ? theme.colorScheme.tertiary : null,
      ),
      title: Text(l10n.accountOfflineCacheTitle),
      subtitle: Text(_subtitle(l10n, account?.cacheLimitBytes)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdaptiveTextButton(
            onPressed: _pickLimit,
            child: Text(cacheLimitLabel(l10n, account?.cacheLimitBytes)),
          ),
          if (hasFiles)
            AdaptiveTextButton(
              onPressed: _clearOfflineCache,
              isDestructive: true,
              child: Text(l10n.accountClear),
            ),
        ],
      ),
    );
  }
}
