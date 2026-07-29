import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../services/migration_notice.dart';

/// Shows the one-time post-migration notice over the main shell, pointing the
/// user at the recovery-key export.
///
/// The migration ceremony lives in the core auth service, so instead of a
/// hook there the gate keys off the ceremony's observable outcome: a curve
/// session that still carries the retained RSA key only exists for migrated
/// accounts (fresh v2 registrations never have one). PIN unlocks don't
/// restore that key, so the notice can only fire on a password-fresh session
/// — exactly when the full recovery bundle is exportable.
class MigrationNoticeGate extends ConsumerStatefulWidget {
  const MigrationNoticeGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MigrationNoticeGate> createState() =>
      _MigrationNoticeGateState();
}

class _MigrationNoticeGateState extends ConsumerState<MigrationNoticeGate> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    // The login screen sets the key providers before this shell mounts, so
    // the mount itself is the first chance to check.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(decryptedPrivateKeyProvider, (previous, next) {
      if (next != null && next != previous) _maybeShow();
    });
    return widget.child;
  }

  Future<void> _maybeShow() async {
    if (_showing) return;
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    if (ref.read(authServiceProvider).decryptedLegacyRsaPrivateKey == null) {
      return;
    }
    if (await isMigrationNoticeSeen(account.id)) return;
    if (!mounted) return;

    _showing = true;
    try {
      final l10n = AppLocalizations.of(context);
      final goToKey = await showAdaptiveAlert<bool>(
        context: context,
        title: l10n.authMigrationNoticeTitle,
        content: l10n.authMigrationNoticeBody,
        actions: [
          AdaptiveDialogAction(label: l10n.authLater, value: false),
          AdaptiveDialogAction(
            label: l10n.authGetMyRecoveryKey,
            value: true,
            isDefault: true,
          ),
        ],
      );
      // A tap outside dismisses without a choice — leave the flag unset so
      // the reminder returns on the next password login.
      if (goToKey == null) return;
      await markMigrationNoticeSeen(account.id);
      if (goToKey && mounted) {
        unawaited(context.push('/account/recovery-key'));
      }
    } finally {
      _showing = false;
    }
  }
}
