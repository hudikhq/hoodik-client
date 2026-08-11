import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Current value of the caller's `share_notifications_enabled` flag, read from
/// the authenticated user row via `POST /api/auth/self`. The field rides on the
/// same user object the login response carries but isn't persisted locally, so
/// the section fetches it on demand. Defaults to true (the server default) when
/// the client is absent or the field is missing from an older server's payload.
final _shareNotificationsEnabledProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) return true;
  final self = await client.auth.getSelf();
  return self.user['share_notifications_enabled'] as bool? ?? true;
});

/// Account-screen section for the share-notifications email opt-out. Hidden
/// entirely on servers that don't advertise sharing — gated on
/// [shareCapabilitiesProvider] — so it never appears against an instance that
/// can't act on the preference. Mirrors the web `SharingPreferences.vue`:
/// reads the current value from the user row, writes through
/// `PATCH /api/users/me`.
class SharingPreferencesSection extends ConsumerWidget {
  const SharingPreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharingEnabled = ref
        .watch(shareCapabilitiesProvider)
        .maybeWhen(data: (caps) => caps.sharingEnabled, orElse: () => false);
    if (!sharingEnabled) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AdaptiveListSection(
        header: AppLocalizations.of(context).accountSharingHeader,
        children: const [_ShareNotificationsTile()],
      ),
    );
  }
}

class _ShareNotificationsTile extends ConsumerStatefulWidget {
  const _ShareNotificationsTile();

  @override
  ConsumerState<_ShareNotificationsTile> createState() =>
      _ShareNotificationsTileState();
}

class _ShareNotificationsTileState
    extends ConsumerState<_ShareNotificationsTile> {
  /// Optimistic local copy: flipped immediately on toggle, reverted if the
  /// PATCH fails. Null until the initial value loads.
  bool? _override;
  bool _saving = false;

  Future<void> _toggle(bool current) async {
    final desired = !current;
    setState(() {
      _override = desired;
      _saving = true;
    });

    final client = ref.read(apiClientProvider);
    if (client == null) {
      setState(() {
        _override = current;
        _saving = false;
      });
      return;
    }

    try {
      await client.shares.patchMe(shareNotificationsEnabled: desired);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      AppNotification.show(
        context,
        message: desired
            ? l10n.accountSharingEnabledMsg
            : l10n.accountSharingDisabledMsg,
        type: NotificationType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _override = current);
      AppNotification.show(
        context,
        message: AppLocalizations.of(context).accountSharingUpdateFailed,
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_shareNotificationsEnabledProvider);
    final enabled = _override ?? async.valueOrNull ?? true;
    final loading = async.isLoading && _override == null;
    final l10n = AppLocalizations.of(context);

    return AdaptiveListTile(
      leading: Icon(
        isApplePlatform ? CupertinoIcons.bell : Icons.notifications_outlined,
        size: 22,
        color: context.colors.iconEmber,
      ),
      title: Text(l10n.accountSharingEmailToggle),
      subtitle: Text(
        enabled ? l10n.accountSharingEmailsOn : l10n.accountSharingEmailsOff,
      ),
      trailing: loading
          ? const AdaptiveLoadingIndicator()
          : CupertinoSwitch(
              value: enabled,
              onChanged: _saving ? null : (_) => _toggle(enabled),
            ),
    );
  }
}
