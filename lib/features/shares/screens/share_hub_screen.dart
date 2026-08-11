import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../links/screens/links_body.dart';
import '../providers/audit_log_notifier.dart';
import 'audit_log_body.dart';
import 'share_groups_body.dart';
import '../../../core/widgets/app_icons.dart';

/// The three sub-surfaces the hub can show. Public links pre-date
/// account-to-account sharing and work on any server, so it is always present;
/// activity and groups are gated on the server's advertised capabilities.
enum _ShareTab { publicLinks, activity, groups }

/// Consolidated sharing hub, replacing the standalone Links tab. Shows a
/// capability-gated sub-tab bar — Public links / Activity / Groups — over a
/// body. When only Public links is visible (an old or sharing-disabled server),
/// the tab bar is dropped so it reads as a plain screen. Mirrors the web
/// `ShareHub.vue`.
class ShareHubScreen extends ConsumerWidget {
  const ShareHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(shareCapabilitiesProvider).valueOrNull;
    final sharingEnabled = caps?.sharingEnabled ?? false;

    final tabs = <_ShareTab>[
      _ShareTab.publicLinks,
      if (sharingEnabled && (caps?.auditLog ?? false)) _ShareTab.activity,
      if (sharingEnabled && (caps?.shareGroups ?? false)) _ShareTab.groups,
    ];

    return _ShareHubView(tabs: tabs);
  }
}

class _ShareHubView extends StatefulWidget {
  const _ShareHubView({required this.tabs});

  final List<_ShareTab> tabs;

  @override
  State<_ShareHubView> createState() => _ShareHubViewState();
}

class _ShareHubViewState extends State<_ShareHubView>
    with TickerProviderStateMixin {
  late TabController _controller;

  /// Drives the public-links list's re-fetch from the AppBar refresh action,
  /// since that list owns its own load state rather than a shared notifier.
  final _linksKey = GlobalKey<LinksBodyState>();

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
  }

  @override
  void didUpdateWidget(_ShareHubView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Capability resolution can add or drop a tab after first paint; rebuild
    // the controller so its length tracks the visible set and stays in range.
    if (oldWidget.tabs.length != widget.tabs.length) {
      _controller.dispose();
      _controller = _buildController();
    }
  }

  TabController _buildController() {
    final controller = TabController(length: widget.tabs.length, vsync: this);
    controller.addListener(_onTabChanged);
    return controller;
  }

  void _onTabChanged() {
    if (!_controller.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  static String _label(AppLocalizations l10n, _ShareTab tab) => switch (tab) {
    _ShareTab.publicLinks => l10n.sharesTabPublicLinks,
    _ShareTab.activity => l10n.sharesTabActivity,
    _ShareTab.groups => l10n.sharesTabGroups,
  };

  Widget _body(_ShareTab tab) => switch (tab) {
    _ShareTab.publicLinks => LinksBody(key: _linksKey),
    _ShareTab.activity => const AuditLogBody(),
    _ShareTab.groups => const ShareGroupsBody(),
  };

  /// iOS-idiom tab switcher: a segmented control in the nav-bar's bottom
  /// slot instead of a Material TabBar. Drives the same TabController so
  /// swiping the TabBarView keeps both platforms in sync.
  PreferredSizeWidget _segmentedSwitcher(
    AppLocalizations l10n,
    List<_ShareTab> tabs,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(44),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        child: SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: _controller.index.clamp(0, tabs.length - 1),
            children: {
              for (final (i, tab) in tabs.indexed)
                i: Text(
                  _label(l10n, tab),
                  style: const TextStyle(fontSize: 13),
                ),
            },
            onValueChanged: (index) {
              if (index != null) _controller.animateTo(index);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = widget.tabs;
    final showTabBar = tabs.length > 1;
    final current = tabs[_controller.index.clamp(0, tabs.length - 1)];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.commonShare),
        centerTitle: isApplePlatform,
        actions: [
          _TabAction(
            tab: current,
            onRefreshLinks: () => _linksKey.currentState?.reload(),
          ),
        ],
        bottom: !showTabBar
            ? null
            : isApplePlatform
            ? _segmentedSwitcher(l10n, tabs)
            : TabBar(
                controller: _controller,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final tab in tabs) Tab(text: _label(l10n, tab))],
              ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [for (final tab in tabs) _body(tab)],
      ),
    );
  }
}

/// The AppBar action for the active sub-tab. Public links and Activity get a
/// refresh; Groups gets "new group". A link can be created from a file's
/// context menu while this list is already mounted, so it needs an explicit
/// re-fetch and not only pull-to-refresh.
class _TabAction extends ConsumerWidget {
  const _TabAction({required this.tab, required this.onRefreshLinks});

  final _ShareTab tab;
  final VoidCallback onRefreshLinks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    switch (tab) {
      case _ShareTab.publicLinks:
        return IconButton(
          tooltip: l10n.sharesRefresh,
          icon: Icon(AppIcons.refresh),
          onPressed: onRefreshLinks,
        );
      case _ShareTab.activity:
        return IconButton(
          tooltip: l10n.sharesRefresh,
          icon: Icon(AppIcons.refresh),
          onPressed: () =>
              ref.read(auditLogNotifierProvider.notifier).refresh(),
        );
      case _ShareTab.groups:
        return IconButton(
          tooltip: l10n.sharesNewGroup,
          icon: Icon(AppIcons.memberAdd),
          onPressed: () => createShareGroup(context, ref),
        );
    }
  }
}
