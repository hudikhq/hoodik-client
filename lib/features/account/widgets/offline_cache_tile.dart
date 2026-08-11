import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/utils/format.dart' as fmt;
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/app_icons.dart';

/// Displays the size of the offline cache for the active account and lets
/// the user clear it. Owns its own size/count state so the parent screen
/// doesn't have to thread them through build.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
      subtitle: Text(
        hasFiles
            ? l10n.accountOfflineCacheStats(
                _cacheFileCount,
                fmt.formatBytes(_cacheSize),
              )
            : l10n.accountOfflineNoFiles,
      ),
      trailing: hasFiles
          ? AdaptiveTextButton(
              onPressed: _clearOfflineCache,
              isDestructive: true,
              child: Text(l10n.accountClear),
            )
          : null,
    );
  }
}
