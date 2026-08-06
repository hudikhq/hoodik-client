import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/utils/biometric_helper.dart';
import '../../../core/utils/log_redact.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/providers.dart';
import '../../../core/storage/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/account_switch_list.dart';
import 'add_server_screen.dart' show selectedServerProvider;

const _log = Logger('UnlockScreen');

class UnlockScreen extends ConsumerStatefulWidget {
  /// When provided, the unlock screen targets this specific account instead of
  /// falling back to the default (active/last-used account with a PIN).
  /// Used when account switching redirects here.
  final String? targetAccountId;

  const UnlockScreen({super.key, this.targetAccountId});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _pinController = TextEditingController();
  final _localAuth = LocalAuthentication();
  bool _loading = false;
  String? _error;
  Account? _storedAccount;
  Server? _currentServer;

  /// Other accounts the user can switch to (with or without PIN).
  List<OtherAccount> _otherAccounts = [];

  /// Whether the device supports biometric and the user has it enabled.
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadStoredAccount();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredAccount() async {
    final authService = ref.read(authServiceProvider);
    Account? account;

    // If a specific account was requested (e.g. from account switching),
    // try to load that account first.
    if (widget.targetAccountId != null) {
      account = await authService.getAccountWithPinKeyById(
        widget.targetAccountId!,
      );
    }

    // Fallback: active/last-used account with a PIN.
    account ??= await authService.getAccountWithPinKey();

    if (mounted) {
      setState(() => _storedAccount = account);
    }

    if (account != null) {
      await _checkBiometric(account.id);
    }

    await _loadOtherAccounts();
  }

  /// Load all accounts except the current one for the switch section,
  /// and resolve the current account's server.
  Future<void> _loadOtherAccounts() async {
    final authService = ref.read(authServiceProvider);
    final accounts = await authService.getAccounts();
    final servers = await authService.getServers();

    final serverMap = {for (final s in servers) s.id: s};
    final currentId = _storedAccount?.id;

    final others = accounts
        .where((a) => a.id != currentId)
        .map((a) => OtherAccount(account: a, server: serverMap[a.serverId]))
        .toList();

    if (mounted) {
      setState(() {
        _otherAccounts = others;
        _currentServer = _storedAccount != null
            ? serverMap[_storedAccount!.serverId]
            : null;
      });
    }
  }

  /// Check if biometric is available on the device and enabled for this account.
  Future<void> _checkBiometric(String accountId) async {
    try {
      final authService = ref.read(authServiceProvider);
      final hasBio = await authService.hasBiometricSetup(accountId);
      if (!hasBio) return;

      final canAuth =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!canAuth) return;

      if (mounted) {
        setState(() => _biometricAvailable = true);
        // Auto-prompt biometric on screen load.
        unawaited(_authenticateWithBiometric());
      }
    } catch (e) {
      // Biometric not available — fall back to PIN silently.
    }
  }

  Future<void> _authenticateWithBiometric() async {
    if (_loading || _storedAccount == null) return;
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
      final pin = await authService.getBiometricPin(_storedAccount!.id);
      if (pin == null) {
        setState(() => _error = l10n.authBiometricPinNotFound);
        return;
      }

      // Use the stored PIN to unlock.
      await _unlockWithPin(pin);
    } on PlatformException catch (e) {
      // User cancelled / hardware not available is silent — stays on PIN.
      // Anything else is a real failure: surface a useful message to the
      // user and log the full PlatformException code + message so we can
      // debug from the on-disk log without rebuilding the app. The codes
      // we see in the wild include `NotEnrolled`, `LockedOut`,
      // `PermanentlyLockedOut`, `no_fragment_activity`, `auth_in_progress`.
      if (e.code == 'NotAvailable' || e.code == 'UserCancel') return;
      _log.warn(
        'biometric authenticate failed',
        fields: {
          'platform_code': e.code,
          'platform_message': e.message,
          'platform_details': describeError(e),
        },
      );
      if (!mounted) return;
      setState(() => _error = _biometricMessageFor(e));
    } catch (e) {
      _log.warn(
        'biometric authenticate threw non-PlatformException',
        fields: {'error': describeError(e)},
      );
      if (!mounted) return;
      setState(() => _error = l10n.authBiometricFailedUsePin);
    }
  }

  /// Map a [PlatformException.code] to a user-actionable hint. Hides the
  /// raw code from the user (those go to the log) but tells them whether
  /// they should retry, enrol, or fall back to PIN.
  String _biometricMessageFor(PlatformException e) {
    final l10n = AppLocalizations.of(context);
    switch (e.code) {
      case 'NotEnrolled':
        return l10n.authBiometricNotEnrolled;
      case 'LockedOut':
        return l10n.authBiometricLockedOut;
      case 'PermanentlyLockedOut':
        return l10n.authBiometricPermanentlyLockedOut;
      case 'no_fragment_activity':
        // Should be unreachable post-MainActivity fix (issue #160) but keep
        // a clear message in case a future host activity slips back to
        // FlutterActivity.
        return l10n.authBiometricNotConfigured;
      default:
        return l10n.authBiometricFailedUsePin;
    }
  }

  Future<void> _unlock() async {
    final pin = _pinController.text;

    if (pin.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).authEnterPinPrompt);
      return;
    }

    if (_storedAccount == null) {
      setState(() => _error = AppLocalizations.of(context).authNoAccountFound);
      return;
    }

    await _unlockWithPin(pin);
  }

  Future<void> _unlockWithPin(String pin) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final account = await authService.unlockWithPin(_storedAccount!.id, pin);

      if (mounted) {
        unawaited(HapticFeedback.lightImpact());
        ref.setLoggedIn(
          account: account,
          server: authService.activeServer,
          privateKey: authService.decryptedPrivateKey,
          wrappingPrivateKey: authService.decryptedWrappingPrivateKey,
        );
        context.go(ref.read(landingBranchProvider).route);
      }
    } catch (e) {
      if (mounted) {
        unawaited(HapticFeedback.heavyImpact());
        setState(() {
          _loading = false;
          _error = AppLocalizations.of(context).authWrongPinOrAuthFailed;
        });
        _pinController.clear();
      }
    }
  }

  Future<void> _forgetAccount() async {
    if (_storedAccount == null) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.authForgetAccountTitle,
      content: l10n.authForgetAccountConfirm(_storedAccount!.email),
      actions: [
        AdaptiveDialogAction(
          label: l10n.commonCancel,
          value: false,
          isDefault: true,
        ),
        AdaptiveDialogAction(
          label: l10n.authForget,
          value: true,
          isDestructive: true,
        ),
      ],
    );

    if (confirmed == true) {
      final authService = ref.read(authServiceProvider);
      final accountId = _storedAccount!.id;
      final wasActive = ref.read(activeAccountProvider)?.id == accountId;

      // Clear PIN from DB + secure storage before deleting the account row.
      await authService.clearPin(accountId);
      await authService.removeAccount(accountId);

      if (!mounted) return;

      if (wasActive) {
        ref.setLoggedOut();
      }

      // Select the next PIN account in place. Navigating to /auth/unlock is a
      // no-op here — we are already on that route — which is why the forgotten
      // account used to linger on screen until another one was tapped.
      final nextPinAccount = await authService.getAccountWithPinKey();
      if (!mounted) return;
      if (nextPinAccount != null) {
        setState(() {
          _storedAccount = nextPinAccount;
          _biometricAvailable = false;
          _error = null;
          _loading = false;
        });
        _pinController.clear();
        await _loadOtherAccounts();
        if (_storedAccount != null) {
          await _checkBiometric(_storedAccount!.id);
        }
        return;
      }

      final remainingAccounts = await authService.getAccounts();
      if (!mounted) return;
      if (remainingAccounts.isNotEmpty) {
        final servers = await authService.getServers();
        if (!mounted) return;
        final server = servers
            .where((s) => s.id == remainingAccounts.first.serverId)
            .firstOrNull;
        if (server != null) {
          ref.read(selectedServerProvider.notifier).state = server;
        }
        context.go('/auth/login');
        return;
      }

      context.go('/setup/server');
    }
  }

  /// Switch to a different account. If the target has a PIN, swap in-place
  /// (no navigation, no network calls). Otherwise navigate to login.
  Future<void> _switchToAccount(OtherAccount entry) async {
    unawaited(HapticFeedback.selectionClick());

    final authService = ref.read(authServiceProvider);
    final hasPin = await authService.hasPinSetup(entry.account.id);
    if (!mounted) return;

    if (hasPin) {
      // In-place swap — just change which account the PIN screen targets.
      final pinAccount = await authService.getAccountWithPinKeyById(
        entry.account.id,
      );
      if (!mounted) return;

      setState(() {
        _storedAccount = pinAccount ?? entry.account;
        _biometricAvailable = false;
        _error = null;
        _loading = false;
      });
      _pinController.clear();

      // Rebuild the "other accounts" list with the new current excluded.
      await _loadOtherAccounts();

      // Check biometric for the newly selected account.
      if (_storedAccount != null) {
        await _checkBiometric(_storedAccount!.id);
      }
    } else {
      // No PIN — send them to the login screen with the server pre-selected.
      ref.read(selectedServerProvider.notifier).state = entry.server;
      context.go('/auth/login');
    }
  }

  /// Add another account: pick a server, then sign in fresh.
  void _addAnotherAccount() {
    context.go('/setup/server');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Account avatar + identity
                  if (_storedAccount != null) ...[
                    UserAvatar(email: _storedAccount!.email, radius: 28),
                    const SizedBox(height: 12),
                    Text(
                      _storedAccount!.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    if (_currentServer != null)
                      Text(
                        _currentServer!.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
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

                  // Biometric button
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

                  const SizedBox(height: 24),

                  // Secondary actions — clear escape routes
                  AdaptiveTextButton(
                    onPressed: _loading ? null : _addAnotherAccount,
                    child: Text(l10n.authAddAnotherAccount),
                  ),
                  const SizedBox(height: 4),
                  AdaptiveTextButton(
                    onPressed: _loading ? null : _forgetAccount,
                    isDestructive: true,
                    child: Text(l10n.authForgetThisAccount),
                  ),

                  // Other accounts to switch to (self-hides when empty).
                  AccountSwitchList(
                    accounts: _otherAccounts,
                    loading: _loading,
                    onSwitch: _switchToAccount,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
