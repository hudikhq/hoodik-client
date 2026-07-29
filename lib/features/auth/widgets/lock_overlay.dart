import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/utils/biometric_helper.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/providers.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Full-screen PIN overlay shown when the app resumes from background
/// and a PIN is configured. Does not navigate — just covers the app
/// content until the correct PIN is entered.
class LockOverlay extends ConsumerStatefulWidget {
  const LockOverlay({super.key});

  @override
  ConsumerState<LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends ConsumerState<LockOverlay> {
  final _pinController = TextEditingController();
  final _localAuth = LocalAuthentication();
  bool _loading = false;
  String? _error;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    try {
      final authService = ref.read(authServiceProvider);
      final hasBio = await authService.hasBiometricSetup(account.id);
      if (!hasBio) return;

      final canAuth =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!canAuth) return;

      if (mounted) {
        setState(() => _biometricAvailable = true);
        unawaited(_authenticateWithBiometric());
      }
    } catch (_) {
      // Biometric not available — fall back to PIN silently.
    }
  }

  Future<void> _authenticateWithBiometric() async {
    if (_loading) return;

    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    final l10n = AppLocalizations.of(context);

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: l10n.authUnlockHoodik,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (!authenticated || !mounted) return;

      final authService = ref.read(authServiceProvider);
      final pin = await authService.getBiometricPin(account.id);
      if (pin == null) {
        setState(() => _error = l10n.authBiometricPinNotFound);
        return;
      }

      await _verifyAndUnlock(pin);
    } on PlatformException catch (e) {
      if (mounted) {
        if (e.code != 'NotAvailable' && e.code != 'UserCancel') {
          setState(() => _error = l10n.authBiometricFailed);
        }
      }
    }
  }

  Future<void> _unlock() async {
    final pin = _pinController.text;
    if (pin.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).authEnterPinPrompt);
      return;
    }
    await _verifyAndUnlock(pin);
  }

  Future<void> _verifyAndUnlock(String pin) async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final valid = await authService.verifyPin(account.id, pin);

      if (!mounted) return;

      if (valid) {
        unawaited(HapticFeedback.lightImpact());
        ref.read(isLockedProvider.notifier).state = false;
      } else {
        unawaited(HapticFeedback.heavyImpact());
        setState(() {
          _loading = false;
          _error = l10n.authWrongPin;
        });
        _pinController.clear();
      }
    } catch (e) {
      if (mounted) {
        unawaited(HapticFeedback.heavyImpact());
        setState(() {
          _loading = false;
          _error = l10n.authWrongPinOrVerifyFailed;
        });
        _pinController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(activeAccountProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (account != null) ...[
                      UserAvatar(email: account.email, radius: 28),
                      const SizedBox(height: 12),
                      Text(
                        account.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      l10n.authEnterPasscode,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AdaptivePasswordField(
                      controller: _pinController,
                      label: l10n.authPinLabel,
                      autofocus: !_biometricAvailable,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _unlock(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 24),
                    AdaptiveButton(
                      onPressed: _loading ? null : _unlock,
                      child: _loading
                          ? const AdaptiveLoadingIndicator(radius: 10)
                          : Text(l10n.authUnlock),
                    ),
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 16),
                      AdaptiveTextButton(
                        onPressed: _loading ? null : _authenticateWithBiometric,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(biometricIcon(), size: 20),
                            const SizedBox(width: 8),
                            Text(biometricLabel(withUsePrefix: true)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
