import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/widgets/adaptive.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:hoodik_app/router.dart';

final _apple = Platform.isIOS || Platform.isMacOS;

/// Mounts the real [MainShell] at a given window width over stub branches.
Future<ProviderContainer> _pumpShell(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width * tester.view.devicePixelRatio, 1600);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const Text('files')),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/notes', builder: (_, _) => const Text('notes')),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  final container = ProviderContainer(
    overrides: [permanentlyFailedCountProvider.overrideWith((ref) async => 0)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('a phone width keeps the bottom tab bar and shows no rail', (
    tester,
  ) async {
    await _pumpShell(tester, 393);

    expect(find.byType(NavigationRail), findsNothing);
    if (_apple) {
      expect(find.byType(CupertinoTabBar), findsOneWidget);
    } else {
      expect(find.byType(NavigationBar), findsOneWidget);
    }
  });

  testWidgets('an expanded width moves navigation to the rail', (tester) async {
    await _pumpShell(tester, 1200);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(CupertinoTabBar), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('the rail switches branches and keeps content mounted', (
    tester,
  ) async {
    await _pumpShell(tester, 1200);
    expect(find.text('files'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Notes'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('notes'), findsOneWidget);
    // IndexedStack keeps every branch alive; only one is on screen.
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('a split-view width on a large screen stays compact', (
    tester,
  ) async {
    // The rail is chosen by the width the shell is handed, not the device.
    await _pumpShell(tester, kExpandedWidthBreakpoint - 1);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
