import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/providers.dart';
import '../../../l10n/generated/app_localizations.dart';

const _log = Logger('SetupPinScreen');

class SetupPinScreen extends ConsumerStatefulWidget {
  const SetupPinScreen({super.key});

  @override
  ConsumerState<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends ConsumerState<SetupPinScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _setupPin() async {
    final l10n = AppLocalizations.of(context);
    final pin = _pinController.text;
    final confirm = _confirmController.text;

    if (pin.length < 4) {
      setState(() => _error = l10n.authPinTooShort);
      return;
    }

    if (pin != confirm) {
      setState(() => _error = l10n.authPinsDoNotMatch);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final account = ref.read(activeAccountProvider);
      final privateKey = ref.read(decryptedPrivateKeyProvider);
      final wrappingKey = ref.read(decryptedWrappingPrivateKeyProvider);

      if (account == null || privateKey == null) {
        setState(() {
          _loading = false;
          _error = l10n.authNoActiveAccountOrKey;
        });
        return;
      }

      await authService.setupPin(
        account.id,
        privateKey,
        pin,
        wrappingPrivateKeyPem: wrappingKey,
      );

      if (mounted) {
        context.go(ref.read(landingBranchProvider).route);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = l10n.authPinSetupFailed(
            e.toString().replaceFirst('Exception: ', ''),
          );
        });
      }
    }
  }

  void _skip() {
    context.go(ref.read(landingBranchProvider).route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(activeAccountProvider);
    _log.debug('build', fields: {'has_account': account != null});

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          // "Skip" as the right action — tapping navigates home.
          // Back button goes home too (user is already logged in).
          leading: BackButton(onPressed: _skip),
          centerTitle: isApplePlatform,
          actions: [
            AdaptiveTextButton(
              onPressed: _loading ? null : _skip,
              child: Text(l10n.authSkip),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    l10n.authCreatePasscode,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authSetupPinIntro,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (account != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      account.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  AdaptivePasswordField(
                    key: const Key('pinField'),
                    controller: _pinController,
                    label: l10n.authPinLabel,
                    placeholder: l10n.authPinPlaceholder,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  AdaptivePasswordField(
                    key: const Key('pinConfirmField'),
                    controller: _confirmController,
                    label: l10n.authConfirmPinLabel,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _setupPin(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 24),
                  AdaptiveButton(
                    onPressed: _loading ? null : _setupPin,
                    child: _loading
                        ? const AdaptiveLoadingIndicator(radius: 10)
                        : Text(l10n.authSetPin),
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
