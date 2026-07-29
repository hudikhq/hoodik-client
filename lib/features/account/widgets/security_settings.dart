import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/providers.dart';
import '../../../core/utils/biometric_helper.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Manages PIN and biometric settings for the active account.
class SecuritySettings extends ConsumerStatefulWidget {
  const SecuritySettings({super.key});

  @override
  ConsumerState<SecuritySettings> createState() => _SecuritySettingsState();
}

class _SecuritySettingsState extends ConsumerState<SecuritySettings> {
  bool _hasPinSetup = false;
  bool _hasBiometricSetup = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkPinSetup();
    _checkBiometric();
  }

  Future<void> _checkPinSetup() async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    final authService = ref.read(authServiceProvider);
    final hasPin = await authService.hasPinSetup(account.id);
    if (mounted) {
      setState(() => _hasPinSetup = hasPin);
    }
  }

  Future<void> _clearPinSetup() async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.accountRemovePasscodeTitle,
      content: l10n.accountRemovePasscodeBody,
      actions: [
        AdaptiveDialogAction(
          label: l10n.commonCancel,
          value: false,
          isDefault: true,
        ),
        AdaptiveDialogAction(
          label: l10n.commonRemove,
          value: true,
          isDestructive: true,
        ),
      ],
    );

    if (confirmed == true) {
      final authService = ref.read(authServiceProvider);
      await authService.clearPin(account.id);
      if (mounted) {
        setState(() {
          _hasPinSetup = false;
          _hasBiometricSetup = false;
        });
      }
    }
  }

  Future<void> _checkBiometric() async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    try {
      final auth = LocalAuthentication();
      final canAuth =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (mounted) {
        setState(() => _biometricAvailable = canAuth);
      }
    } catch (_) {
      // Biometric not available on this device.
    }

    final authService = ref.read(authServiceProvider);
    final hasBio = await authService.hasBiometricSetup(account.id);
    if (mounted) {
      setState(() => _hasBiometricSetup = hasBio);
    }
  }

  Future<void> _enableBiometric() async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    final pin = await _askForPin();
    if (pin == null || pin.isEmpty) return;

    final authService = ref.read(authServiceProvider);
    final hasPin = await authService.hasPinSetup(account.id);
    if (!hasPin) {
      if (mounted) {
        AppNotification.show(
          context,
          message: AppLocalizations.of(context).accountSetUpPinFirst,
          type: NotificationType.error,
        );
      }
      return;
    }

    if (!await authService.verifyPin(account.id, pin)) {
      if (mounted) {
        AppNotification.show(
          context,
          message: AppLocalizations.of(context).accountIncorrectPin,
          type: NotificationType.error,
        );
      }
      return;
    }

    await authService.enableBiometric(account.id, pin);
    if (mounted) {
      setState(() => _hasBiometricSetup = true);
    }
  }

  Future<void> _disableBiometric() async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    final authService = ref.read(authServiceProvider);
    await authService.disableBiometric(account.id);
    if (mounted) {
      setState(() => _hasBiometricSetup = false);
    }
  }

  Future<String?> _askForPin() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(l10n.accountEnterPinTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.accountEnterPinBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.accountPinLabel,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(l10n.commonConfirm),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdaptiveListTile(
          leading: Icon(
            isApplePlatform ? CupertinoIcons.lock : Icons.pin_outlined,
            size: 22,
            color: _hasPinSetup ? theme.colorScheme.tertiary : null,
          ),
          title: Text(l10n.accountPasscodeLock),
          subtitle: Text(
            _hasPinSetup ? l10n.accountEnabled : l10n.accountNotConfigured,
          ),
          trailing: _hasPinSetup
              ? AdaptiveTextButton(
                  onPressed: _clearPinSetup,
                  isDestructive: true,
                  child: Text(l10n.commonRemove),
                )
              : AdaptiveTextButton(
                  onPressed: () => context.push('/auth/setup-pin'),
                  child: Text(l10n.accountSetUp),
                ),
        ),
        if (_biometricAvailable && _hasPinSetup)
          AdaptiveListTile(
            leading: Icon(
              biometricIcon(),
              size: 22,
              color: _hasBiometricSetup ? theme.colorScheme.tertiary : null,
            ),
            title: Text(biometricLabel()),
            subtitle: Text(
              _hasBiometricSetup
                  ? l10n.accountEnabled
                  : l10n.accountNotConfigured,
            ),
            trailing: _hasBiometricSetup
                ? AdaptiveTextButton(
                    onPressed: _disableBiometric,
                    isDestructive: true,
                    child: Text(l10n.accountDisable),
                  )
                : AdaptiveTextButton(
                    onPressed: _enableBiometric,
                    child: Text(l10n.accountEnable),
                  ),
          ),
      ],
    );
  }
}
