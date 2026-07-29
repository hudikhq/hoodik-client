import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'ai_access_tile.dart';
import 'diagnostics_tile.dart';
import 'landing_branch_tile.dart';
import 'language_tile.dart';
import 'manage_accounts_tile.dart';
import 'offline_cache_tile.dart';
import 'recovery_key_tile.dart';
import 'security_settings.dart';
import 'storage_quota_tile.dart';

/// The main "SETTINGS" section of the account screen, grouping storage/cache
/// tiles, security controls, the landing-tab picker, AI access, and the
/// account-management shortcut.
class AccountSettingsSection extends ConsumerWidget {
  const AccountSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showMcp = ref.watch(mcpAvailableProvider);

    return AdaptiveListSection(
      header: AppLocalizations.of(context).accountSettingsHeader,
      children: [
        const StorageQuotaTile(),
        const OfflineCacheTile(),
        const SecuritySettings(),
        const RecoveryKeyTile(),
        const LandingBranchTile(),
        const LanguageTile(),
        if (showMcp) const AiAccessTile(),
        const DiagnosticsTile(),
        const ManageAccountsTile(),
      ],
    );
  }
}
