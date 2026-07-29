import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/admin_users_tab.dart';
import '../widgets/admin_invitations_tab.dart';
import '../widgets/admin_settings_tab.dart';

/// Top-level admin panel with three tabs: Users, Invitations, Settings.
///
/// Pushed full-screen from the account screen (not inside the bottom-nav shell).
class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminPanelTitle),
        centerTitle: isApplePlatform,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.adminTabUsers),
            Tab(text: l10n.adminTabInvitations),
            Tab(text: l10n.adminTabSettings),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AdminUsersTab(),
          AdminInvitationsTab(),
          AdminSettingsTab(),
        ],
      ),
    );
  }
}
