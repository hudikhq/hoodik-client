import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/providers.dart';
import '../../../core/services/server_version.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Stands in for the main shell while the active server is older than
/// [minimumServerVersion].
///
/// A banner would not be enough. Against such a server every write still
/// succeeds and is indexed in a shape the server will never match, so the
/// damage is invisible until someone searches for a file months later and it
/// is not there. Refusing up front is the only version of this the user can
/// act on.
///
/// It waits for the probe rather than assuming the worst: while liveness is
/// unresolved, or the server is simply unreachable, the shell renders as
/// usual. Offline is not the same as incompatible, and a flap in the tunnel
/// must not look like one.
class ServerVersionGate extends ConsumerWidget {
  const ServerVersionGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveness = ref.watch(serverLivenessProvider).valueOrNull;
    if (liveness == null || !liveness.isServerBelowMinimum) return child;
    return _ServerTooOldScreen(reported: liveness.version);
  }
}

class _ServerTooOldScreen extends ConsumerWidget {
  const _ServerTooOldScreen({required this.reported});

  /// What the server called itself, or null on one so old it does not say.
  final String? reported;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.sync_problem_outlined,
                    size: 48,
                    color: context.colors.textCrimson,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.serverBelowMinimumTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.serverBelowMinimumBody(
                      minimumServerVersion,
                      reported ?? l10n.serverVersionUnknown,
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () => ref.invalidate(serverLivenessProvider),
                    child: Text(l10n.commonRetry),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _signOut(context, ref),
                    child: Text(l10n.accountSignOut),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The only way out of this screen, so it does not ask for confirmation the
  /// way the settings one does — there is nothing here to lose by leaving.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authServiceProvider).logout();
    if (!context.mounted) return;
    ref.setLoggedOut();
    context.go('/setup/server');
  }
}
