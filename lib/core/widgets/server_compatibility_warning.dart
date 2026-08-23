import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers.dart';
import '../theme/hoodik_scheme.dart';
import 'app_icons.dart';

/// Tells the user when this app and the server it is signed in to are not
/// built for each other.
///
/// Distinct from the store-driven [AppUpdateNudge], which asks "is there a
/// newer build available"; this asks "does *this* server work with *this*
/// build", which only the server can answer. It publishes two versions on
/// `/api/liveness`: the oldest app it will serve, and the one it is built for.
///
/// Three states, in descending severity:
///
///  - the app is below the server's minimum, so it is broken here and says so
///  - the server predates the compatibility fields entirely, which means it
///    predates the keyed search index and this app's search cannot work on it
///  - the app merely trails the recommended version, which is a nudge
///
/// The middle case is the one worth the code: without it, search against an
/// older server returns an empty list forever and looks like the user's files
/// are gone.
class ServerCompatibilityWarning extends ConsumerWidget {
  const ServerCompatibilityWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveness = ref.watch(serverLivenessProvider).valueOrNull;
    final appVersion = ref.watch(currentAppVersionProvider).valueOrNull;

    if (liveness == null || !liveness.alive) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);

    if (appVersion != null && liveness.isClientBelowMinimum(appVersion)) {
      return _Banner(message: l10n.appBelowMinimumVersion, severe: true);
    }

    // Below the minimum the app does not reach this banner at all —
    // ServerVersionGate stands in for the shell instead. What is left here is
    // the softer half: a server this build is ahead of but can still work
    // with.
    if (liveness.isServerBelowRecommended) {
      return _Banner(
        message: l10n.serverBelowRecommendedVersion,
        severe: false,
      );
    }

    if (appVersion != null && liveness.isClientBelowRecommended(appVersion)) {
      return _Banner(message: l10n.appBelowRecommendedVersion, severe: false);
    }

    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.severe});

  final String message;
  final bool severe;

  @override
  Widget build(BuildContext context) {
    final color = severe
        ? context.colors.textCrimson
        : context.colors.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.info, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
