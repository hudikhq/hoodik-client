import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../services/key_login_service.dart';
import 'add_server_screen.dart';
import '../../../core/theme/hoodik_type.dart';

/// Sign in with a saved recovery key instead of a password — the mobile
/// counterpart of the web client's private-key login. Accepts a v2 curve
/// bundle or a legacy RSA private-key PEM.
class KeyLoginScreen extends ConsumerStatefulWidget {
  const KeyLoginScreen({super.key});

  @override
  ConsumerState<KeyLoginScreen> createState() => _KeyLoginScreenState();
}

class _KeyLoginScreenState extends ConsumerState<KeyLoginScreen> {
  final _keyController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context);
    final material = _keyController.text;
    if (material.trim().isEmpty) {
      setState(() => _error = l10n.authPasteRecoveryKeyFirst);
      return;
    }

    final server = ref.read(selectedServerProvider);
    if (server == null) {
      setState(() => _error = l10n.authNoServerSelected);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final keys = await ref
          .read(keyLoginServiceProvider)
          .login(server: server, material: material);

      final authService = ref.read(authServiceProvider);
      final account = authService.activeAccount!;
      if (!mounted) return;

      ref.setLoggedIn(
        account: account,
        server: authService.activeServer,
        privateKey: keys.identity,
        wrappingPrivateKey: keys.wrapping,
      );

      final hasPinSetup = await authService.hasPinSetup(account.id);
      if (!mounted) return;
      if (!hasPinSetup) {
        context.go('/auth/setup-pin');
      } else {
        context.go(ref.read(landingBranchProvider).route);
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } on KeyLoginException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
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

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/auth/login')),
        title: Text(server?.name ?? l10n.authKeyLoginTitle),
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
                Text(
                  l10n.authKeyLoginIntro,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('recoveryKeyField'),
                  controller: _keyController,
                  maxLines: 8,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: HoodikType.monoFamily,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.authRecoveryKeyLabel,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 24),
                AdaptiveButton(
                  key: const Key('keyLoginButton'),
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const AdaptiveLoadingIndicator(radius: 10)
                      : Text(l10n.authLogIn),
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: const Key('passwordLoginLink'),
                  onPressed: _loading ? null : () => context.go('/auth/login'),
                  child: Text(l10n.authLogInWithPassword),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
