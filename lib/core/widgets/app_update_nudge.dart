import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers.dart';
import '../services/app_update.dart';
import 'adaptive.dart';

/// Nudges the user to update the app when a newer build is available in the
/// store they installed from. Two platform-native paths:
///
///  - **Android** — Google Play's flexible in-app update. Play shows its own
///    UI and downloads in the background; when it's ready we surface a restart
///    snackbar. Nothing is rendered inline.
///  - **iOS / macOS** — Apple has no in-app update API, so we compare the
///    running version against the App Store version (iTunes lookup) and show a
///    dismissible banner linking to the store page.
///
/// The render path is driven entirely by [latestAppStoreVersionProvider],
/// which is `null` off Apple platforms, so the banner is Apple-only without a
/// host `Platform` check that would be untestable on the Linux CI runner.
class AppUpdateNudge extends ConsumerStatefulWidget {
  const AppUpdateNudge({super.key});

  @override
  ConsumerState<AppUpdateNudge> createState() => _AppUpdateNudgeState();
}

class _AppUpdateNudgeState extends ConsumerState<AppUpdateNudge> {
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryPlayUpdate());
    }
  }

  Future<void> _tryPlayUpdate() async {
    final ready = await startPlayFlexibleUpdateIfAvailable();
    if (!ready || !mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.widgetUpdateDownloaded),
        duration: const Duration(seconds: 12),
        action: SnackBarAction(
          label: l10n.widgetUpdateRestart,
          onPressed: () {
            completePlayFlexibleUpdate();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dismissed = ref.watch(dismissedAppUpdateBannerProvider);
    if (dismissed) return const SizedBox.shrink();

    final current = ref.watch(currentAppVersionProvider).valueOrNull;
    final store = ref.watch(latestAppStoreVersionProvider).valueOrNull;
    if (!appUpdateAvailable(current: current, store: store)) {
      return const SizedBox.shrink();
    }

    return _UpdateBanner(
      storeVersion: store!.version,
      onUpdate: () {
        if (store.storeUrl.isNotEmpty) {
          launchUrl(
            Uri.parse(store.storeUrl),
            mode: LaunchMode.externalApplication,
          );
        }
      },
      onDismiss: () =>
          ref.read(dismissedAppUpdateBannerProvider.notifier).state = true,
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({
    required this.storeVersion,
    required this.onUpdate,
    required this.onDismiss,
  });

  final String storeVersion;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final Color accent;
    final Color background;

    if (isApplePlatform) {
      accent = CupertinoColors.systemBlue.resolveFrom(context);
      background = accent.withValues(alpha: 0.12);
    } else {
      final scheme = Theme.of(context).colorScheme;
      accent = scheme.primary;
      background = scheme.primary.withValues(alpha: 0.12);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: background),
      child: Row(
        children: [
          Icon(
            isApplePlatform
                ? CupertinoIcons.arrow_down_circle_fill
                : Icons.system_update,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: AppLocalizations.of(
                  context,
                ).widgetUpdateAvailable(storeVersion),
                style: TextStyle(color: accent, fontSize: 13, height: 1.35),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _UpdateButton(
            key: const ValueKey('app_update_banner_update'),
            color: accent,
            onTap: onUpdate,
          ),
          _DismissButton(
            key: const ValueKey('app_update_banner_dismiss'),
            color: accent,
            onTap: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _UpdateButton extends StatelessWidget {
  const _UpdateButton({super.key, required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      AppLocalizations.of(context).widgetUpdate,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
    );

    if (isApplePlatform) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 28),
        onPressed: onTap,
        child: label,
      );
    }
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      child: label,
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({super.key, required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      isApplePlatform ? CupertinoIcons.xmark : Icons.close,
      color: color,
      size: 18,
    );

    if (isApplePlatform) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(28),
        onPressed: onTap,
        child: icon,
      );
    }
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: AppLocalizations.of(context).widgetDismiss,
      icon: icon,
    );
  }
}
