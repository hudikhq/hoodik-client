import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Card at the bottom of the server-selection screen. The app is free and
/// monetisation lives in hoodik.cloud, so the "installed, has no server"
/// path — the largest slice of new installs — gets a way forward instead of
/// a dead end: a chooser page on hoodik.io that lays out self-hosting and
/// managed hosting side by side. Also shown alongside saved servers, where
/// it doubles as the shortcut to another instance.
class CloudNudge extends StatelessWidget {
  const CloudNudge({super.key});

  /// `ref=app` only feeds the referrer split in our self-hosted Umami stats.
  static final Uri serverGuideUri = Uri.parse(
    'https://hoodik.io/server?ref=app',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isApplePlatform ? CupertinoIcons.cloud : Icons.cloud_outlined,
                size: 20,
                color: primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.authNeedServerTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.authNeedServerBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          AdaptiveButton(
            onPressed: () =>
                launchUrl(serverGuideUri, mode: LaunchMode.externalApplication),
            child: Text(l10n.authLearnMore),
          ),
        ],
      ),
    );
  }
}
