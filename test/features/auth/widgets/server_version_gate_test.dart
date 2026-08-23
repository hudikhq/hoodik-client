import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/server_version.dart';
import 'package:hoodik_app/features/auth/widgets/server_version_gate.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

/// What the shell would have rendered. Its absence is the assertion: a banner
/// over a working app is exactly what this gate exists not to be.
const _shellMarker = 'the shell';

Widget _pump({LivenessInfo? liveness, bool pending = false}) {
  return ProviderScope(
    overrides: [
      serverLivenessProvider.overrideWith((ref) async {
        // A probe that never resolves, standing in for the moment before the
        // first answer comes back.
        if (pending) return Completer<LivenessInfo>().future;
        return liveness!;
      }),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ServerVersionGate(child: Text(_shellMarker)),
    ),
  );
}

void main() {
  testWidgets('replaces the shell when the server is below the minimum', (
    tester,
  ) async {
    await tester.pumpWidget(
      _pump(liveness: const LivenessInfo(alive: true, version: '2.4.1')),
    );
    await tester.pumpAndSettle();

    expect(find.text(_shellMarker), findsNothing);
    expect(
      find.text(
        AppLocalizations.of(
          tester.element(find.byType(Scaffold)),
        ).serverBelowMinimumTitle,
      ),
      findsOneWidget,
    );
  });

  testWidgets('names both versions so the user knows what to install', (
    tester,
  ) async {
    await tester.pumpWidget(
      _pump(liveness: const LivenessInfo(alive: true, version: '2.4.1')),
    );
    await tester.pumpAndSettle();

    final body = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(body, contains(minimumServerVersion));
    expect(body, contains('2.4.1'));
  });

  testWidgets('offers a way out rather than trapping the user', (tester) async {
    await tester.pumpWidget(
      _pump(liveness: const LivenessInfo(alive: true, version: '2.4.1')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextButton), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('lets a server on the minimum through', (tester) async {
    await tester.pumpWidget(
      _pump(
        liveness: const LivenessInfo(
          alive: true,
          version: minimumServerVersion,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_shellMarker), findsOneWidget);
  });

  testWidgets('lets an unreachable server through', (tester) async {
    // Offline is not incompatible. Walling off the app on a dropped
    // connection would be worse than the problem the gate solves.
    await tester.pumpWidget(_pump(liveness: const LivenessInfo.offline()));
    await tester.pumpAndSettle();

    expect(find.text(_shellMarker), findsOneWidget);
  });

  testWidgets('renders the shell while the probe is still in flight', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(pending: true));
    await tester.pump();

    expect(find.text(_shellMarker), findsOneWidget);
  });
}
