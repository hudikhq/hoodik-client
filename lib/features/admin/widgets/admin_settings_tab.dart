import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/format.dart' as fmt;
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Server settings: registration toggle, email verification, the sharing
/// kill-switch (when the server reports it), and default quota.
class AdminSettingsTab extends ConsumerStatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  ConsumerState<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends ConsumerState<AdminSettingsTab>
    with AutomaticKeepAliveClientMixin {
  ServerSettings? _settings;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _quotaController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _quotaController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final settings = await client.admin.getSettings();
      if (mounted) {
        _quotaController.text = settings.quotaBytes != null
            ? fmt.quotaBytesToGb(settings.quotaBytes!)
            : '';
        setState(() {
          _settings = settings;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_settings == null) return;
    final l10n = AppLocalizations.of(context);
    final client = ref.read(apiClientProvider);
    if (client == null) return;

    final quotaBytes = fmt.quotaGbToBytes(_quotaController.text);

    setState(() => _saving = true);

    try {
      final updated = await client.admin.updateSettings(
        _settings!.copyWith(
          quotaBytes: quotaBytes,
          clearQuota: quotaBytes == null,
        ),
      );
      if (mounted) {
        setState(() {
          _settings = updated;
          _saving = false;
        });
        AppNotification.show(
          context,
          message: l10n.adminSettingsSaved,
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppNotification.show(
          context,
          message: l10n.adminActionFailed(e.toString()),
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _testEmail() async {
    final l10n = AppLocalizations.of(context);
    final client = ref.read(apiClientProvider);
    if (client == null) return;

    try {
      final message = await client.admin.testEmail();
      if (mounted) {
        AppNotification.show(context, message: message);
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          message: l10n.adminEmailTestFailed(e.toString()),
          type: NotificationType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const Center(child: AdaptiveLoadingIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(message: _error!),
        ),
      );
    }

    if (_settings == null) {
      return Center(child: Text(l10n.adminSettingsLoadFailed));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Registration section
        AdaptiveListSection(
          header: l10n.adminRegistrationHeader,
          children: [
            AdaptiveListTile(
              title: Text(l10n.adminAllowRegistration),
              subtitle: Text(l10n.adminAllowRegistrationSubtitle),
              trailing: Switch.adaptive(
                value: _settings!.allowRegister,
                onChanged: (v) {
                  setState(() {
                    _settings = _settings!.copyWith(allowRegister: v);
                  });
                },
              ),
            ),
            AdaptiveListTile(
              title: Text(l10n.adminEnforceEmailVerification),
              subtitle: Text(l10n.adminEnforceEmailVerificationSubtitle),
              trailing: Switch.adaptive(
                value: _settings!.enforceEmailActivation,
                onChanged: (v) {
                  setState(() {
                    _settings = _settings!.copyWith(enforceEmailActivation: v);
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // The sharing kill-switch is a server feature; older servers don't
        // report it, so the section only renders when the server advertised it.
        if (_settings!.sharingSupported) ...[
          AdaptiveListSection(
            header: l10n.adminSharingHeader,
            children: [
              AdaptiveListTile(
                title: Text(l10n.adminSharingToggle),
                subtitle: Text(l10n.adminSharingSubtitle),
                trailing: Switch.adaptive(
                  value: _settings!.sharingEnabled,
                  onChanged: _saving
                      ? null
                      : (v) {
                          setState(() {
                            _settings = _settings!.copyWith(sharingEnabled: v);
                          });
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Quota section
        AdaptiveListSection(
          header: l10n.adminDefaultQuotaHeader,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _quotaController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.adminDefaultQuotaGbLabel,
                  hintText: l10n.adminQuotaUnlimitedHint,
                  border: const OutlineInputBorder(),
                  suffixText: 'GB',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Save button
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.adminSaveSettings),
          ),
        ),
        const SizedBox(height: 24),

        // Email test section
        AdaptiveListSection(
          header: l10n.adminEmailHeader,
          children: [
            AdaptiveListTile(
              title: Text(l10n.adminTestEmailTitle),
              subtitle: Text(l10n.adminTestEmailSubtitle),
              trailing: TextButton(
                onPressed: _testEmail,
                child: Text(
                  l10n.adminSendTest,
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
