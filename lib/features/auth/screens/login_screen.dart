import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/providers.dart';
import '../../../core/storage/database.dart';
import '../../../core/utils/format.dart' as fmt;
import '../../../core/utils/logger.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'add_server_screen.dart';

const _log = Logger('LoginScreen');

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tfaController = TextEditingController();
  bool _loading = false;

  bool _showTfa = false;
  String? _error;
  List<Account> _serverAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _tfaController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final server = ref.read(selectedServerProvider);
    if (server == null) return;

    final authService = ref.read(authServiceProvider);
    final accounts = await authService.getAccountsForServer(server.id);
    if (mounted) {
      setState(() => _serverAccounts = accounts);
    }
  }

  Future<void> _switchToAccount(Account account) async {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final success = await authService.switchAccount(account.id);

      if (!success) {
        await _fallbackAfterFailedRestore(account);
        return;
      }

      if (!mounted) return;

      final privateKey = authService.decryptedPrivateKey;
      ref.setLoggedIn(
        account: authService.activeAccount!,
        server: authService.activeServer,
        privateKey: privateKey,
        wrappingPrivateKey: authService.decryptedWrappingPrivateKey,
      );

      if (privateKey != null) {
        context.go(ref.read(landingBranchProvider).route);
      } else {
        // Session is valid but the private key couldn't be recovered
        // silently. Check if the account has a PIN — if so, send the user
        // to the unlock screen; otherwise, stay here for password entry.
        final hasPin = await authService.hasPinSetup(account.id);
        if (!mounted) return;
        if (hasPin) {
          context.go('/auth/unlock?accountId=${account.id}');
        } else {
          setState(() {
            _loading = false;
            _error = AppLocalizations.of(context).authSignInToUnlockEncryption;
          });
          _emailController.text = account.email;
        }
      }
    } catch (_) {
      // switchAccount rethrows when the stored session can't be restored
      // (e.g. an expired token → 401). Fall back rather than dead-end.
      await _fallbackAfterFailedRestore(account);
    }
  }

  /// After a failed session restore for [account], prefer the PIN unlock
  /// screen when the account has a PIN; otherwise prefill the email so the user
  /// can sign in with their password. Never leaves the user on a raw error.
  Future<void> _fallbackAfterFailedRestore(Account account) async {
    if (!mounted) return;
    final hasPin = await ref.read(authServiceProvider).hasPinSetup(account.id);
    if (!mounted) return;
    if (hasPin) {
      context.go('/auth/unlock?accountId=${account.id}');
      return;
    }
    setState(() {
      _loading = false;
      _error = AppLocalizations.of(context).authSignInToContinue;
    });
    _emailController.text = account.email;
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final tfaToken = _tfaController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = l10n.authEmailPasswordRequired);
      return;
    }

    if (_showTfa && tfaToken.isEmpty) {
      setState(() => _error = l10n.authEnterTfaCode);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final server = ref.read(selectedServerProvider);
      if (server == null) {
        setState(() {
          _loading = false;
          _error = l10n.authNoServerSelected;
        });
        return;
      }

      final authService = ref.read(authServiceProvider);
      final account = await authService.login(
        server: server,
        email: email,
        password: password,
        tfaToken: tfaToken.isNotEmpty ? tfaToken : null,
      );

      if (!mounted) return;

      ref.setLoggedIn(
        account: account,
        server: server,
        privateKey: authService.decryptedPrivateKey,
        wrappingPrivateKey: authService.decryptedWrappingPrivateKey,
      );

      final hasPinSetup = await authService.hasPinSetup(account.id);
      _log.debug(
        'login post-auth routing',
        fields: {
          'has_pin_setup': hasPinSetup,
          'has_private_key': authService.decryptedPrivateKey != null,
        },
      );
      if (!mounted) return;
      if (!hasPinSetup && authService.decryptedPrivateKey != null) {
        _log.debug('routing to setup-pin');
        context.go('/auth/setup-pin');
      } else {
        final landing = ref.read(landingBranchProvider).route;
        _log.debug('routing to landing', fields: {'landing': landing});
        context.go(landing);
      }
    } on DioException catch (e) {
      if (mounted) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;

        String message;
        if (statusCode == 401) {
          final body = responseData is Map ? responseData : {};
          final errorMsg = body['message']?.toString().toLowerCase() ?? '';
          if (errorMsg.contains('token') ||
              errorMsg.contains('two') ||
              errorMsg.contains('2fa')) {
            setState(() {
              _loading = false;
              _showTfa = true;
              _error = l10n.authTfaRequired;
            });
            return;
          }
          message = l10n.authInvalidCredentials;
        } else if (statusCode == 422) {
          message = l10n.authValidationError;
        } else {
          message = l10n.authConnectionFailed(e.message ?? '');
        }

        setState(() {
          _loading = false;
          _error = message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final server = ref.watch(selectedServerProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // Back button to return to server selection
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/setup/server')),
          title: Text(server?.name ?? l10n.authSignIn),
          centerTitle: isApplePlatform,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Existing accounts for this server
                  if (_serverAccounts.isNotEmpty) ...[
                    AdaptiveListSection(
                      header: l10n.authExistingAccounts,
                      children: _serverAccounts.map((account) {
                        return AdaptiveListTile(
                          leading: UserAvatar(email: account.email, radius: 16),
                          title: Text(account.email),
                          subtitle: account.lastUsedAt != null
                              ? Text(
                                  l10n.authLastUsed(
                                    fmt.formatRelativeTime(
                                      account.lastUsedAt,
                                      fallback: '',
                                    ),
                                  ),
                                )
                              : Text(l10n.authNeverUsed),
                          onTap: _loading
                              ? null
                              : () => _switchToAccount(account),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.authSignInDifferentAccount,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Login form
                  AdaptiveTextField(
                    key: const Key('emailField'),
                    controller: _emailController,
                    label: l10n.authEmailLabel,
                    prefix: Icon(
                      isApplePlatform
                          ? CupertinoIcons.mail
                          : Icons.email_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  AdaptivePasswordField(
                    key: const Key('passwordField'),
                    controller: _passwordController,
                    label: l10n.authPasswordLabel,
                    textInputAction: _showTfa
                        ? TextInputAction.next
                        : TextInputAction.go,
                    onSubmitted: _showTfa ? null : (_) => _login(),
                  ),
                  if (_showTfa) ...[
                    const SizedBox(height: 16),
                    AdaptiveTextField(
                      controller: _tfaController,
                      label: l10n.authTfaCodeLabel,
                      placeholder: '000000',
                      prefix: Icon(
                        isApplePlatform
                            ? CupertinoIcons.shield
                            : Icons.security,
                        size: 18,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _login(),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 24),
                  AdaptiveButton(
                    key: const Key('signInButton'),
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const AdaptiveLoadingIndicator(radius: 10)
                        : Text(l10n.authSignIn),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    key: const Key('createAccountLink'),
                    onPressed: _loading
                        ? null
                        : () => context.go('/auth/register'),
                    child: Text(l10n.authCreateAnAccount),
                  ),
                  TextButton(
                    key: const Key('keyLoginLink'),
                    onPressed: _loading
                        ? null
                        : () => context.go('/auth/key-login'),
                    child: Text(l10n.authLogInWithKey),
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
