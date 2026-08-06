import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:hoodik_app/router.dart';

/// Mounts the real [MainShell] over stub branch screens so the
/// shell-branch-request wiring is exercised without the full app.
void main() {
  testWidgets('a branch request switches the shell tab and resets itself', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => MainShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const Text('files-root')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/notes',
                  builder: (_, _) => const Text('notes-root'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    final container = ProviderContainer(
      overrides: [
        permanentlyFailedCountProvider.overrideWith((ref) async => 0),
      ],
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
    expect(find.text('files-root'), findsOneWidget);

    container.read(shellBranchRequestProvider.notifier).state = 1;
    await tester.pumpAndSettle();
    expect(find.text('notes-root'), findsOneWidget);
    expect(container.read(shellBranchRequestProvider), isNull);

    container.read(shellBranchRequestProvider.notifier).state = 0;
    await tester.pumpAndSettle();
    expect(find.text('files-root'), findsOneWidget);
  });
}
