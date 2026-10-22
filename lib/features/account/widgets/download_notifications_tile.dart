import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../../../l10n/generated/app_localizations.dart';

class DownloadNotificationsTile extends ConsumerWidget {
  const DownloadNotificationsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isAndroid) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(downloadCompleteNotificationsProvider);

    void toggle() =>
        ref.read(downloadCompleteNotificationsProvider.notifier).set(!enabled);

    return AdaptiveListTile(
      leading: Icon(
        Icons.notifications_outlined,
        size: 22,
        color: context.colors.iconEmber,
      ),
      title: Text(l10n.accountDownloadNotificationsTitle),
      subtitle: Text(l10n.accountDownloadNotificationsSubtitle),
      trailing: CupertinoSwitch(value: enabled, onChanged: (_) => toggle()),
      onTap: toggle,
    );
  }
}
