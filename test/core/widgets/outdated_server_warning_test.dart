import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/server_version.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/widgets/outdated_server_warning.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

// Both above minimumServerVersion: this banner is the softer of the two,
// and a server below the minimum never reaches it — ServerVersionGate stands
// in for the shell before any of this renders.
const _latestRelease = '2.7.0';
const _usableButBehind = '2.5.0';

Server _server({String url = 'https://self-hosted.example'}) {
  return Server(
    id: 'srv-1',
    url: url,
    name: 'self-hosted',
    trustSelfSignedCerts: false,
    useHeaderAuth: false,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Widget _pump({
  required Server? server,
  required LivenessInfo liveness,
  String? latestRelease = _latestRelease,
}) {
  return ProviderScope(
    overrides: [
      activeServerProvider.overrideWith((ref) => server),
      serverLivenessProvider.overrideWith((ref) async => liveness),
      latestServerReleaseProvider.overrideWith((ref) async => latestRelease),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: OutdatedServerWarning()),
    ),
  );
}

void main() {
  testWidgets('hides when no active server is set', (tester) async {
    await tester.pumpWidget(
      _pump(
        server: null,
        liveness: const LivenessInfo(
          alive: true,
          version: _usableButBehind,
          minimumClientVersion: '1.0.0',
          recommendedClientVersion: '1.0.0',
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('hides when server matches the latest release', (tester) async {
    await tester.pumpWidget(
      _pump(
        server: _server(),
        liveness: const LivenessInfo(alive: true, version: _latestRelease),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Upgrade', findRichText: true), findsNothing);
  });

  testWidgets('hides when server is newer than the latest release', (
    tester,
  ) async {
    // Self-hoster running a master build — we don't warn on "ahead".
    await tester.pumpWidget(
      _pump(
        server: _server(),
        liveness: const LivenessInfo(
          alive: true,
          version: '99.0.0',
          minimumClientVersion: '1.0.0',
          recommendedClientVersion: '1.0.0',
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Upgrade', findRichText: true), findsNothing);
  });

  testWidgets('hides when liveness probe failed', (tester) async {
    // A transient probe failure is different from "server is old" — don't
    // spook the user with an upgrade banner when we can't even reach the
    // server to read its version.
    await tester.pumpWidget(
      _pump(server: _server(), liveness: const LivenessInfo.offline()),
    );
    await tester.pump();
    expect(find.textContaining('Upgrade', findRichText: true), findsNothing);
  });

  testWidgets(
    'hides when GitHub is unreachable and the server reports a version',
    (tester) async {
      // Strict no-guesswork rule: if we can't fetch the latest release,
      // we have no verified threshold for "old". Show nothing.
      await tester.pumpWidget(
        _pump(
          server: _server(),
          liveness: const LivenessInfo(
            alive: true,
            version: _usableButBehind,
            minimumClientVersion: '1.0.0',
            recommendedClientVersion: '1.0.0',
          ),
          latestRelease: null,
        ),
      );
      await tester.pump();
      expect(find.textContaining('Upgrade', findRichText: true), findsNothing);
    },
  );

  testWidgets(
    'shows banner with reported version and latest release on old server',
    (tester) async {
      await tester.pumpWidget(
        _pump(
          server: _server(),
          liveness: const LivenessInfo(
            alive: true,
            version: _usableButBehind,
            minimumClientVersion: '1.0.0',
            recommendedClientVersion: '1.0.0',
          ),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining(_usableButBehind, findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('v$_latestRelease', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets('defers to the compatibility banner when the server predates the '
      'compat fields', (tester) async {
    // A server that omits `version` predates v1.16.0, so it also predates
    // the 2.5.0 compat fields — which makes it a server this app cannot
    // search at all. ServerCompatibilityWarning says exactly that, and
    // needs GitHub no more than this branch did, so stacking a vaguer
    // "upgrade available" line above it would only push the useful message
    // down the screen.
    await tester.pumpWidget(
      _pump(
        server: _server(),
        liveness: const LivenessInfo(alive: true, version: null),
        latestRelease: null,
      ),
    );
    await tester.pump();
    expect(find.textContaining('Upgrade', findRichText: true), findsNothing);
    expect(
      find.textContaining('older than v1.16.0', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('dismiss button hides the banner for that server URL only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _pump(
        server: _server(),
        liveness: const LivenessInfo(
          alive: true,
          version: _usableButBehind,
          minimumClientVersion: '1.0.0',
          recommendedClientVersion: '1.0.0',
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Upgrade', findRichText: true), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('outdated_server_banner_dismiss')),
    );
    await tester.pump();
    expect(find.textContaining('Upgrade', findRichText: true), findsNothing);
  });
}
