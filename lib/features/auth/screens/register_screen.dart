import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'add_server_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = l10n.authEmailPasswordRequired);
      return;
    }
    if (password != confirm) {
      setState(() => _error = l10n.authPasswordsDoNotMatch);
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
      final account = await authService.register(
        server: server,
        email: email,
        password: password,
      );

      if (!mounted) return;

      // No session means the server requires email activation before login.
      if (!authService.isLoggedIn) {
        setState(() => _loading = false);
        await showAdaptiveAlert<void>(
          context: context,
          title: l10n.authCheckEmailTitle,
          content: l10n.authCheckEmailBody,
          actions: [AdaptiveDialogAction(label: l10n.commonOk, value: null)],
        );
        if (mounted) context.go('/auth/login');
        return;
      }

      ref.setLoggedIn(
        account: account,
        server: server,
        privateKey: authService.decryptedPrivateKey,
        wrappingPrivateKey: authService.decryptedWrappingPrivateKey,
      );

      if (authService.decryptedPrivateKey != null) {
        context.go('/auth/setup-pin');
      } else {
        context.go(ref.read(landingBranchProvider).route);
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        final serverMsg = data is Map ? data['message']?.toString() : null;
        final status = e.response?.statusCode;
        setState(() {
          _loading = false;
          if (status == 404) {
            // A pre-OPAQUE server has no /api/auth/register/pake/start, so the
            // signup ceremony 404s here. New accounts are Curve25519 + OPAQUE
            // only — there's no legacy signup fallback — so tell the user to
            // update rather than showing a raw 404.
            _error = l10n.authServerTooOldForRegister;
          } else if (status == 422) {
            // The real reason (e.g. "not allowed to register", "email is
            // taken") lives in the validr body under context.errors, not the
            // generic top-level "Validation error" message.
            _error =
                _firstValidationError(data) ??
                serverMsg ??
                l10n.authRegistrationNotAllowed;
          } else {
            _error = l10n.authRegistrationFailed(e.message ?? '');
          }
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
    final l10n = AppLocalizations.of(context);
    final server = ref.watch(selectedServerProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/auth/login')),
          title: Text(server?.name ?? l10n.authCreateAccount),
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
                  AdaptiveTextField(
                    key: const Key('emailField'),
                    controller: _emailController,
                    label: l10n.authEmailLabel,
                    prefix: Icon(
                      isApplePlatform
                          ? CupertinoIcons.mail
                          : Icons.email_outlined,
                      size: 18,
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
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  AdaptivePasswordField(
                    key: const Key('confirmPasswordField'),
                    controller: _confirmController,
                    label: l10n.authConfirmPasswordLabel,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _register(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 24),
                  AdaptiveButton(
                    key: const Key('createAccountButton'),
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const AdaptiveLoadingIndicator(radius: 10)
                        : Text(l10n.authCreateAccount),
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

/// Pull the first field-level message out of a validr validation body
/// (`{context: {errors: {<field>: {errors: [msg]}}}}`) so the user sees the
/// real reason ("not allowed to register", "email is taken") instead of a bare
/// "Validation error".
String? _firstValidationError(dynamic data) {
  final context = data is Map ? data['context'] : null;
  final errors = context is Map ? context['errors'] : null;
  if (errors is! Map) return null;
  for (final entry in errors.values) {
    final list = entry is Map ? entry['errors'] : null;
    if (list is List && list.isNotEmpty) {
      final msg = list.first?.toString().trim();
      if (msg != null && msg.isNotEmpty) {
        return msg[0].toUpperCase() + msg.substring(1);
      }
    }
  }
  return null;
}
