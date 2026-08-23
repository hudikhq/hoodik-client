import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers.dart';
import 'adaptive.dart';
import 'app_icons.dart';

/// Inline warning rendered at the top of the files screen when the
/// signed-in server is verifiably older than the latest published hoodik
/// release on github.com/hudikhq/hoodik.
///
/// Two independent verification paths:
///  - The server omits the `version` field on `/api/liveness` (added in
///    v1.16.0), so its absence is itself proof the server predates v1.16.0.
///  - The server reports a version AND we successfully fetched the latest
///    release tag from GitHub AND the server's version is older.
///
/// If GitHub is unreachable and the server reports a version, the banner
/// stays hidden — we refuse to warn on guesswork.
///
/// Non-blocking on purpose: old servers still work via the graceful-
/// degradation paths exercised by the compat gate. This banner is a
/// nudge, not a gate — the user can dismiss it for the session.
class OutdatedServerWarning extends ConsumerWidget {
  const OutdatedServerWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final livenessAsync = ref.watch(serverLivenessProvider);
    final latestAsync = ref.watch(latestServerReleaseProvider);
    final server = ref.watch(activeServerProvider);
    final dismissed = ref.watch(dismissedOutdatedServerBannersProvider);

    final serverUrl = server?.url;
    if (serverUrl == null) return const SizedBox.shrink();
    if (dismissed.contains(serverUrl)) return const SizedBox.shrink();

    final liveness = livenessAsync.valueOrNull;
    if (liveness == null || !liveness.alive) {
      return const SizedBox.shrink();
    }

    // A server this app cannot actually work with gets the specific,
    // actionable message from ServerCompatibilityWarning instead. Stacking
    // "an update is available" on top of "search will not work here" adds a
    // line that says less than the one below it.
    if (liveness.isServerBelowMinimum) {
      return const SizedBox.shrink();
    }

    final latest = latestAsync.valueOrNull;
    if (!liveness.isOutdatedAgainst(latest)) {
      return const SizedBox.shrink();
    }

    return _OutdatedBanner(
      version: liveness.version,
      latestRelease: latest,
      onDismiss: () {
        ref.read(dismissedOutdatedServerBannersProvider.notifier).state = {
          ...dismissed,
          serverUrl,
        };
      },
    );
  }
}

class _OutdatedBanner extends StatelessWidget {
  const _OutdatedBanner({
    required this.version,
    required this.latestRelease,
    required this.onDismiss,
  });

  /// Server-reported version. `null` when the server predates the
  /// addition of the field (anything before v1.16.0).
  final String? version;

  /// Latest published release fetched from GitHub. `null` when the server
  /// omitted its version field — in that branch we don't need GitHub
  /// confirmation to know the server is old.
  final String? latestRelease;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final Color accent;
    final Color background;

    if (isApplePlatform) {
      accent = CupertinoColors.systemOrange.resolveFrom(context);
      background = accent.withValues(alpha: 0.12);
    } else {
      final scheme = Theme.of(context).colorScheme;
      accent = scheme.tertiary;
      background = scheme.tertiary.withValues(alpha: 0.12);
    }

    final l10n = AppLocalizations.of(context);
    final reported = version ?? l10n.widgetServerVersionUnknown;
    final message = latestRelease != null
        ? l10n.widgetOutdatedServer(reported, latestRelease!)
        : l10n.widgetOutdatedServerNoLatest(reported);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: background),
      child: Row(
        children: [
          Icon(
            isApplePlatform ? CupertinoIcons.info_circle_fill : AppIcons.info,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: message,
                style: TextStyle(color: accent, fontSize: 13, height: 1.35),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _DismissButton(
            key: const ValueKey('outdated_server_banner_dismiss'),
            color: accent,
            onTap: onDismiss,
          ),
        ],
      ),
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
      isApplePlatform ? CupertinoIcons.xmark : AppIcons.close,
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
      constraints: BoxConstraints(
        minWidth: kMinTapTarget,
        minHeight: kMinTapTarget,
      ),
      tooltip: AppLocalizations.of(context).widgetDismiss,
      icon: icon,
    );
  }
}
