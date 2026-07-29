import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/widgets/adaptive.dart';
import 'features/auth/screens/add_server_screen.dart';
import 'features/auth/screens/key_login_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/setup_pin_screen.dart';
import 'features/auth/screens/unlock_screen.dart';
import 'features/auth/widgets/migration_notice_gate.dart';
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
import 'core/providers.dart';
import 'core/services/window_title.dart';

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
        builder: (context, state, shell) =>
            MigrationNoticeGate(child: MainShell(navigationShell: shell)),
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
                builder: (context, state) =>
                    FilesScreen(dirId: state.pathParameters['dirId']),
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
const List<String> _kBranchTitles = [
  'Files',
  'Notes',
  'Search',
  'Share',
  'Account',
];

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
  String _composeWindowTitle(WidgetRef ref, int currentIndex) {
    String? subtitle;
    switch (currentIndex) {
      case 0:
        subtitle = ref.watch(filesBranchTitleProvider);
      case 1:
        subtitle = ref.watch(notesBranchTitleProvider);
      default:
        subtitle = null;
    }
    final branchLabel =
        currentIndex >= 0 && currentIndex < _kBranchTitles.length
        ? _kBranchTitles[currentIndex]
        : _kAppTitle;
    if (subtitle == null || subtitle.isEmpty) {
      return '$_kAppTitle — $branchLabel';
    }
    return '$subtitle — $_kAppTitle';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(transferManagerProvider);
    final hasTransfers = manager.hasTransfers;
    final failedCount = ref.watch(permanentlyFailedCountProvider).value ?? 0;
    final showOverlay = hasTransfers || failedCount > 0;
    final currentIndex = navigationShell.currentIndex;

    // Push the composed title to the native window / task switcher.
    // Post-frame so we don't mutate during build.
    final windowTitle = _composeWindowTitle(ref, currentIndex);
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

    if (isApplePlatform) {
      return CupertinoPageScaffold(
        // The notes editor anchors its toolbar above the keyboard and
        // relies on a constant WebView frame (see IosEditorLayout) — if
        // the shell shrinks here, the WebView shrinks with it and
        // WKWebView dismisses the keyboard mid-rise.
        resizeToAvoidBottomInset: !notesActive,
        child: Column(
          children: [
            // The CupertinoTabBar below already draws itself into the
            // home-indicator safe area (it SafeArea-wraps internally).
            // Its siblings in the Column, however, still see the full
            // `MediaQuery.padding.bottom` — children that apply their
            // own SafeArea then reserve that indicator space a second
            // time, which showed up as the visible gap between the
            // notes formatting toolbar and the tab bar. Strip the
            // bottom padding here so descendants see a zero bottom
            // inset and SafeArea becomes a no-op.
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: navigationShell,
              ),
            ),
            if (showOverlay && !notesActive) const TransferOverlay(),
            if (!hideTabBar)
              CupertinoTabBar(
                currentIndex: currentIndex,
                onTap: _onTap,
                activeColor: CupertinoTheme.of(context).primaryColor,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.folder),
                    activeIcon: Icon(CupertinoIcons.folder_fill),
                    label: 'Files',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.doc_text),
                    activeIcon: Icon(CupertinoIcons.doc_text_fill),
                    label: 'Notes',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.search),
                    activeIcon: Icon(CupertinoIcons.search),
                    label: 'Search',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.share),
                    activeIcon: Icon(CupertinoIcons.share_solid),
                    label: 'Share',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.person),
                    activeIcon: Icon(CupertinoIcons.person_fill),
                    label: 'Account',
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
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: 'Files',
                ),
                NavigationDestination(
                  icon: Icon(Icons.sticky_note_2_outlined),
                  selectedIcon: Icon(Icons.sticky_note_2),
                  label: 'Notes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.ios_share_outlined),
                  selectedIcon: Icon(Icons.ios_share),
                  label: 'Share',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Account',
                ),
              ],
            ),
    );
  }
}
