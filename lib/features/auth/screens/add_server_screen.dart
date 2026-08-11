import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/error_copy.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/providers.dart';
import '../../../core/storage/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/cloud_nudge.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Shown as the selected server for the login screen.
final selectedServerProvider = StateProvider<Server?>((ref) => null);

class AddServerScreen extends ConsumerStatefulWidget {
  const AddServerScreen({super.key});

  @override
  ConsumerState<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends ConsumerState<AddServerScreen> {
  final _urlController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Server> _servers = [];

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadServers() async {
    final authService = ref.read(authServiceProvider);
    final servers = await authService.getServers();
    if (mounted) {
      setState(() => _servers = servers);
    }
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(
        () => _error = AppLocalizations.of(context).authServerUrlRequired,
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final server = await authService.addServer(url);

      if (mounted) {
        ref.read(selectedServerProvider.notifier).state = server;
        context.go('/auth/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = humanizeError(e);
        });
      }
    }
  }

  Future<void> _selectServer(Server server) async {
    unawaited(HapticFeedback.selectionClick());
    ref.read(selectedServerProvider.notifier).state = server;
    if (mounted) {
      context.go('/auth/login');
    }
  }

  Future<void> _deleteServer(Server server) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.authDeleteServerTitle,
      content: l10n.authDeleteServerConfirm(server.name),
      actions: [
        AdaptiveDialogAction(
          label: l10n.commonCancel,
          value: false,
          isDefault: true,
        ),
        AdaptiveDialogAction(
          label: l10n.commonDelete,
          value: true,
          isDestructive: true,
        ),
      ],
    );

    if (confirmed == true) {
      final authService = ref.read(authServiceProvider);
      await authService.deleteServer(server.id);
      final activeServer = ref.read(activeServerProvider);
      if (activeServer?.id == server.id) {
        ref.setLoggedOut();
      }
      await _loadServers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final canGoBack = Navigator.of(context).canPop();

    return Scaffold(
      appBar: canGoBack
          ? AppBar(
              leading: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icon(
                  isApplePlatform ? CupertinoIcons.back : AppIcons.back,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(l10n.authManageAccounts),
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Compact branding
                  Icon(
                    isApplePlatform
                        ? CupertinoIcons.cloud
                        : Icons.cloud_outlined,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hoodik',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.colors.textCrimson,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.authTagline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),

                  // Saved servers
                  if (_servers.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    AdaptiveListSection(
                      header: l10n.authSavedServers,
                      children: _servers.map((server) {
                        return AdaptiveListTile(
                          leading: Icon(
                            isApplePlatform
                                ? CupertinoIcons.desktopcomputer
                                : Icons.dns_outlined,
                            color: context.colors.iconEmber,
                            size: 22,
                          ),
                          title: Text(server.name),
                          subtitle: Text(server.url),
                          trailing: isApplePlatform
                              ? const CupertinoListTileChevron()
                              : IconButton(
                                  icon: Icon(
                                    AppIcons.delete,
                                    color: theme.colorScheme.error,
                                    size: 20,
                                  ),
                                  onPressed: () => _deleteServer(server),
                                ),
                          onTap: () => _selectServer(server),
                        );
                      }).toList(),
                    ),
                  ],

                  // Add server form
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _servers.isEmpty
                          ? l10n.authConnectToServer
                          : l10n.authAddNewServer,
                      style: _servers.isEmpty
                          ? theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            )
                          : theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AdaptiveTextField(
                    key: const Key('serverUrlField'),
                    controller: _urlController,
                    label: l10n.authServerUrlLabel,
                    placeholder: 'https://cloud.example.com',
                    prefix: Icon(
                      isApplePlatform
                          ? CupertinoIcons.globe
                          : Icons.dns_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _connect(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 16),
                  AdaptiveButton(
                    onPressed: _loading ? null : _connect,
                    child: _loading
                        ? const AdaptiveLoadingIndicator(radius: 10)
                        : Text(l10n.authAddServer),
                  ),

                  const SizedBox(height: 24),
                  const CloudNudge(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
