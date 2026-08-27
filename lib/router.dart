import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/widgets/adaptive.dart';
import 'l10n/generated/app_localizations.dart';
import 'features/auth/screens/add_server_screen.dart';
import 'features/auth/screens/key_login_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/setup_pin_screen.dart';
import 'features/auth/screens/unlock_screen.dart';
import 'features/auth/widgets/migration_notice_gate.dart';
import 'features/auth/widgets/server_version_gate.dart';
import 'features/files/screens/files_screen.dart';
import 'features/files/widgets/transfer_overlay.dart';
import 'features/account/screens/account_screen.dart';
import 'features/account/screens/recovery_key_screen.dart';
import 'features/admin/screens/admin_panel_screen.dart';
import 'features/admin/screens/admin_user_detail_screen.dart';
import 'features/notes/screens/notes_landing_screen.dart';
import 'features/notes/screens/version_history_screen.dart';
import 'features/preview/screens/preview_screen.dart';
import 'features/shares/screens/folder_members_screen.dart';
import 'features/shares/screens/share_hub_screen.dart';
import 'features/search/screens/search_screen.dart';
import 'features/account/screens/diagnostics_screen.dart';
import 'features/account/screens/log_redactor_screen.dart';
import 'features/account/screens/mcp_audit_log_screen.dart';
import 'features/account/screens/mcp_connect_wizard_screen.dart';
import 'features/account/screens/mcp_settings_screen.dart';
import 'features/account/screens/mcp_tools_docs_screen.dart';
import 'core/providers.dart';
import 'core/services/window_title.dart';
import 'core/theme/hoodik_scheme.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

// Per-branch navigator keys. StatefulShellRoute gives each tab its own
// Navigator so the back stack and scroll positions survive tab switches.
final _filesBranchKey = GlobalKey<NavigatorState>();
final _notesBranchKey = GlobalKey<NavigatorState>();
final _searchBranchKey = GlobalKey<NavigatorState>();
final _shareBranchKey = GlobalKey<NavigatorState>();
final _accountBranchKey = GlobalKey<NavigatorState>();

/// Build a GoRouter. Access to protected routes is gated on [isLoggedIn],
/// checked on every navigation.
GoRouter buildRouter(bool Function() isLoggedIn) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/setup/server',
    redirect: (context, state) {
      final loggedIn = isLoggedIn();
      final location = state.uri.toString();

      final isAuthRoute =
          location.startsWith('/setup') || location.startsWith('/auth');

      if (!loggedIn && !isAuthRoute) {
        return '/setup/server';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/setup/server',
        builder: (context, state) => const AddServerScreen(),
      ),

      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/key-login',
        builder: (context, state) => const KeyLoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/setup-pin',
        builder: (context, state) => const SetupPinScreen(),
      ),
      GoRoute(
        path: '/auth/unlock',
        builder: (context, state) {
          final accountId = state.uri.queryParameters['accountId'];
          return UnlockScreen(targetAccountId: accountId);
        },
      ),

      // Overlay/modal routes live outside the shell — they hide the
      // bottom nav by design (preview, admin, mcp).
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/preview/:fileId',
        builder: (context, state) =>
            PreviewScreen(fileId: state.pathParameters['fileId']!),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/notes/:fileId/history',
        builder: (context, state) =>
            VersionHistoryScreen(fileId: state.pathParameters['fileId']!),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/shares/folder/:folderId/members',
        builder: (context, state) => FolderMembersScreen(
          folderId: state.pathParameters['folderId']!,
          folderName: state.uri.queryParameters['name'] ?? '',
        ),
      ),

      // The Links tab and the two Account-tile destinations folded into the
      // Share hub. These redirects keep old in-app pushes and external deep
      // links pointed at a live route instead of a 404.
      GoRoute(path: '/links', redirect: (_, _) => '/share'),
      GoRoute(path: '/shares/groups', redirect: (_, _) => '/share'),
      GoRoute(path: '/shares/activity', redirect: (_, _) => '/share'),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/admin',
        builder: (context, state) => const AdminPanelScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/mcp-settings',
        builder: (context, state) => const McpSettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/account/ai-access/audit-log',
        builder: (context, state) => const McpAuditLogScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/account/ai-access/tools',
        builder: (context, state) => const McpToolsDocsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/account/ai-access/connect-wizard',
        builder: (context, state) => const McpConnectWizardScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/account/recovery-key',
        builder: (context, state) => const RecoveryKeyScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/account/diagnostics',
        builder: (context, state) => const DiagnosticsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/account/diagnostics/redact',
        builder: (context, state) => const LogRedactorScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/admin/users/:userId',
        builder: (context, state) =>
            AdminUserDetailScreen(userId: state.pathParameters['userId']!),
      ),

      // Main tabbed shell. IndexedStack keeps every branch mounted so
      // switching tabs is instant (no slide transition) and preserves
      // each branch's scroll/selection state.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ServerVersionGate(
          child: MigrationNoticeGate(child: MainShell(navigationShell: shell)),
        ),
        branches: [
          StatefulShellBranch(
            navigatorKey: _filesBranchKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const FilesScreen(),
              ),
              GoRoute(
                path: '/files/:dirId',
                // `extra` carries the folder's decrypted name from the tap
                // site; cold deep-links have no extra and fall back to the
                // generic title until the listing resolves.
                builder: (context, state) => FilesScreen(
                  dirId: state.pathParameters['dirId'],
                  dirName: state.extra is String ? state.extra as String : null,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _notesBranchKey,
            routes: [
              GoRoute(
                path: '/notes',
                // `?open=<fileId>` seeds the workspace with an existing
                // note as the first tab — used when opening a note from
                // another screen without leaving the Notes branch.
                builder: (context, state) => NotesLandingScreen(
                  initialFileId: state.uri.queryParameters['open'],
                ),
              ),
              GoRoute(
                // Deep-link entry point preserved for callers like the
                // files screen and external intents. Redirects into the
                // workspace so we never stack two NotesWorkspace
                // instances on top of each other — important on mobile
                // where a system-back pop would otherwise reveal a
                // fresh sidebar with no expansion state.
                path: '/editor/:fileId',
                redirect: (context, state) =>
                    '/notes?open=${state.pathParameters['fileId']}',
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _searchBranchKey,
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shareBranchKey,
            routes: [
              GoRoute(
                path: '/share',
                builder: (context, state) => const ShareHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _accountBranchKey,
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

const String _kAppTitle = 'Hoodik';

/// Default title for each branch when no per-branch subtitle is set.
/// Index matches the bottom-nav order.
List<String> _branchTitles(AppLocalizations l10n) => [
  l10n.tabFiles,
  l10n.tabNotes,
  l10n.tabSearch,
  l10n.tabShare,
  l10n.tabAccount,
];

/// Strips the bottom safe-area padding for the branch subtree on Apple
/// platforms. The CupertinoTabBar below the branch already draws itself into
/// the home-indicator safe area (it SafeArea-wraps internally); children that
/// apply their own SafeArea would reserve that indicator space a second time,
/// which showed up as a visible gap between the notes formatting toolbar and
/// the tab bar.
///
/// This must be its own widget so `MediaQuery.removePadding` derives from a
/// context *inside* the CupertinoPageScaffold. Deriving from the shell's
/// outer context rebuilds MediaQuery from pre-scaffold data, re-injecting
/// the keyboard inset the scaffold already consumed via
/// `resizeToAvoidBottomInset` — the branch then padded by the keyboard
/// height a second time, pushing sheet content to the top of the screen
/// with a keyboard-sized void below it.
class ShellBranchInsets extends StatelessWidget {
  const ShellBranchInsets({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: child,
    );
  }
}

/// Bottom-nav host for the main five tabs. Renders its child branch
/// inside an `IndexedStack` (provided by GoRouter's `navigationShell`) so
/// tab switches are instant and stateful.
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    // `initialLocation: true` when tapping the current tab again resets
    // that branch to its root route — mirrors the iOS tab-bar convention
    // where re-tapping a tab pops its stack.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// Pick the current window title from the active branch, preferring
  /// any per-branch subtitle (e.g. the active note's filename) over the
  /// plain tab label.
  String _composeWindowTitle(
    WidgetRef ref,
    AppLocalizations l10n,
    int currentIndex,
  ) {
    String? subtitle;
    switch (currentIndex) {
      case 0:
        subtitle = ref.watch(filesBranchTitleProvider);
      case 1:
        subtitle = ref.watch(notesBranchTitleProvider);
      default:
        subtitle = null;
    }
    final titles = _branchTitles(l10n);
    final branchLabel = currentIndex >= 0 && currentIndex < titles.length
        ? titles[currentIndex]
        : _kAppTitle;
    if (subtitle == null || subtitle.isEmpty) {
      return '$_kAppTitle — $branchLabel';
    }
    return '$subtitle — $_kAppTitle';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int?>(shellBranchRequestProvider, (_, index) {
      if (index == null) return;
      ref.read(shellBranchRequestProvider.notifier).state = null;
      navigationShell.goBranch(index);
    });

    final manager = ref.watch(transferManagerProvider);
    final hasTransfers = manager.hasVisibleTransfers;
    final failedCount = ref.watch(permanentlyFailedCountProvider).value ?? 0;
    final showOverlay = hasTransfers || failedCount > 0;
    final currentIndex = navigationShell.currentIndex;

    final l10n = AppLocalizations.of(context);

    // Push the composed title to the native window / task switcher.
    // Post-frame so we don't mutate during build.
    final windowTitle = _composeWindowTitle(ref, l10n, currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setWindowTitle(windowTitle);
    });

    // Notes is meant to feel immersive — per the user, the ambient
    // transfer strip breaks that. Hide the overlay on the Notes branch
    // (index 1); any in-flight transfers are still running, they're
    // just visually muted until the user returns to Files.
    final notesActive = currentIndex == 1;

    // When the keyboard is up on Notes, hide the tab bar so the
    // formatting toolbar sits directly above the keyboard with no gap.
    // Keep the tab bar visible on every other branch and whenever the
    // keyboard is hidden.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final hideTabBar = notesActive && keyboardOpen;

    final destinations = _destinations(l10n);

    // A window wide enough for a rail gets one: the five sections move to the
    // leading edge and the bottom belongs to content again. Driven by the
    // width the shell is handed, so an iPad in Split View or a half-width
    // macOS window correctly stays on the tab bar.
    if (isExpandedWidth(context)) {
      final content = Column(
        children: [
          Expanded(child: ShellBranchInsets(child: navigationShell)),
          if (showOverlay && !notesActive) const TransferOverlay(),
        ],
      );

      return Scaffold(
        resizeToAvoidBottomInset: !notesActive,
        body: SafeArea(
          bottom: false,
          child: Row(
            children: [
              _ShellRail(
                destinations: destinations,
                currentIndex: currentIndex,
                onSelected: _onTap,
              ),
              VerticalDivider(
                width: 0.5,
                thickness: 0.5,
                color: context.colors.seam,
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    if (isApplePlatform) {
      return CupertinoPageScaffold(
        // The notes editor anchors its toolbar above the keyboard and
        // relies on a constant WebView frame (see IosEditorLayout) — if
        // the shell shrinks here, the WebView shrinks with it and
        // WKWebView dismisses the keyboard mid-rise.
        resizeToAvoidBottomInset: !notesActive,
        child: Column(
          children: [
            Expanded(child: ShellBranchInsets(child: navigationShell)),
            if (showOverlay && !notesActive) const TransferOverlay(),
            if (!hideTabBar)
              CupertinoTabBar(
                currentIndex: currentIndex,
                onTap: _onTap,
                activeColor: CupertinoTheme.of(context).primaryColor,
                items: [
                  for (final d in destinations)
                    BottomNavigationBarItem(
                      icon: Icon(d.cupertino),
                      activeIcon: Icon(d.cupertinoActive),
                      label: d.label,
                    ),
                ],
              ),
          ],
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: !notesActive,
      body: Column(
        children: [
          Expanded(child: navigationShell),
          if (showOverlay && !notesActive) const TransferOverlay(),
        ],
      ),
      bottomNavigationBar: hideTabBar
          ? null
          : NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: _onTap,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.material),
                    selectedIcon: Icon(d.materialActive),
                    label: d.label,
                  ),
              ],
            ),
    );
  }

  List<_ShellDestination> _destinations(AppLocalizations l10n) => [
    _ShellDestination(
      label: l10n.tabFiles,
      material: Icons.folder_outlined,
      materialActive: Icons.folder,
      cupertino: CupertinoIcons.folder,
      cupertinoActive: CupertinoIcons.folder_fill,
    ),
    _ShellDestination(
      label: l10n.tabNotes,
      material: Icons.sticky_note_2_outlined,
      materialActive: Icons.sticky_note_2,
      cupertino: CupertinoIcons.doc_text,
      cupertinoActive: CupertinoIcons.doc_text_fill,
    ),
    _ShellDestination(
      label: l10n.tabSearch,
      material: Icons.search_outlined,
      materialActive: Icons.search,
      cupertino: CupertinoIcons.search,
      cupertinoActive: CupertinoIcons.search,
    ),
    _ShellDestination(
      label: l10n.tabShare,
      material: Icons.share_outlined,
      materialActive: Icons.share,
      cupertino: CupertinoIcons.share,
      cupertinoActive: CupertinoIcons.share_solid,
    ),
    _ShellDestination(
      label: l10n.tabAccount,
      material: Icons.person_outline,
      materialActive: Icons.person,
      cupertino: CupertinoIcons.person,
      cupertinoActive: CupertinoIcons.person_fill,
    ),
  ];
}

/// One top-level section, carrying both platforms' glyph pair so the tab bar,
/// nav bar and rail all read from a single list.
class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.material,
    required this.materialActive,
    required this.cupertino,
    required this.cupertinoActive,
  });

  final String label;
  final IconData material;
  final IconData materialActive;
  final IconData cupertino;
  final IconData cupertinoActive;
}

/// Leading-edge navigation for expanded windows. Wears the app-bar shade so
/// it reads as chrome against the body, and keeps each platform's own glyphs
/// rather than flattening both to Material.
class _ShellRail extends StatelessWidget {
  const _ShellRail({
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<_ShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      backgroundColor: context.colors.panel,
      indicatorColor: context.colors.crimsonContainer,
      selectedIconTheme: IconThemeData(
        color: context.colors.onCrimsonContainer,
      ),
      unselectedIconTheme: IconThemeData(color: context.colors.iconMuted),
      selectedLabelTextStyle: TextStyle(
        color: context.colors.text,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: context.colors.textMuted,
        fontSize: 12,
      ),
      destinations: [
        for (final d in destinations)
          NavigationRailDestination(
            icon: Icon(isApplePlatform ? d.cupertino : d.material),
            selectedIcon: Icon(
              isApplePlatform ? d.cupertinoActive : d.materialActive,
            ),
            label: Text(d.label),
          ),
      ],
    );
  }
}
