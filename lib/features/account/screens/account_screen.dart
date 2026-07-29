import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/account_header_section.dart';
import '../widgets/account_settings_section.dart';
import '../widgets/account_switcher_section.dart';
import '../widgets/admin_section.dart';
import '../widgets/legal_section.dart';
import '../widgets/sharing_preferences_section.dart';
import '../widgets/sign_out_section.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(activeAccountProvider)?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).accountTitle),
        centerTitle: isApplePlatform,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const AccountHeaderSection(),
          const AccountSettingsSection(),
          const SharingPreferencesSection(),
          if (isAdmin) ...const [SizedBox(height: 16), AdminSection()],
          const SizedBox(height: 16),
          const AccountSwitcherSection(),
          const LegalSection(),
          const SizedBox(height: 16),
          const SignOutSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
