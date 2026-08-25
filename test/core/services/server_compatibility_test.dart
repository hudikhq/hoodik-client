import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/core/services/server_version.dart';

/// The client/server compatibility handshake.
///
/// A marketing version cannot answer "can these two talk to each other", so
/// the server publishes two numbers on `/api/liveness`: the oldest app it will
/// serve, and the one it is built for. Below the minimum the app is broken and
/// says so; between the two it still works and only gets a nudge.
LivenessInfo _server({
  String version = '2.5.0',
  String? minimum = '2.5.0',
  String? recommended = '2.5.0',
}) => LivenessInfo(
  alive: true,
  version: version,
  minimumClientVersion: minimum,
  recommendedClientVersion: recommended,
);

void main() {
  group('client below the server minimum', () {
    test('is blocked', () {
      expect(_server().isClientBelowMinimum('2.4.1'), isTrue);
    });

    test('is not blocked at exactly the minimum', () {
      expect(_server().isClientBelowMinimum('2.5.0'), isFalse);
    });

    test('is not blocked above it', () {
      expect(_server().isClientBelowMinimum('2.6.0'), isFalse);
    });

    test('is never blocked by a server that does not report a minimum', () {
      expect(_server(minimum: null).isClientBelowMinimum('1.0.0'), isFalse);
    });

    test('is never blocked by an unreachable server', () {
      expect(
        const LivenessInfo.offline().isClientBelowMinimum('1.0.0'),
        isFalse,
      );
    });
  });

  group('client below the recommended version', () {
    test('is nudged when it still works', () {
      final server = _server(minimum: '2.0.0', recommended: '2.5.0');

      expect(server.isClientBelowRecommended('2.4.1'), isTrue);
      expect(server.isClientBelowMinimum('2.4.1'), isFalse);
    });

    test('is not nudged as well as blocked — the block wins', () {
      // Two messages for one problem is worse than one, and "update to keep
      // using this" already covers "an update is available".
      final server = _server(minimum: '2.5.0', recommended: '2.5.0');

      expect(server.isClientBelowMinimum('2.4.1'), isTrue);
      expect(server.isClientBelowRecommended('2.4.1'), isFalse);
    });

    test('is quiet at or above the recommendation', () {
      expect(_server().isClientBelowRecommended('2.5.0'), isFalse);
      expect(_server().isClientBelowRecommended('3.0.0'), isFalse);
    });
  });

  group('server too old for this client', () {
    test('a version below the minimum is refused', () {
      expect(
        const LivenessInfo(alive: true, version: '2.4.1').isServerBelowMinimum,
        isTrue,
      );
    });

    test('a server that reports no version at all is refused', () {
      // The field arrived in v1.16.0, so its absence is not missing
      // information — it dates the server precisely enough.
      expect(const LivenessInfo(alive: true).isServerBelowMinimum, isTrue);
    });

    test('the minimum itself is accepted', () {
      expect(
        LivenessInfo(
          alive: true,
          version: minimumServerVersion,
        ).isServerBelowMinimum,
        isFalse,
      );
    });

    test('a newer server is accepted', () {
      expect(
        const LivenessInfo(alive: true, version: '2.6.0').isServerBelowMinimum,
        isFalse,
      );
    });

    test('a version that parses to nothing is let through', () {
      // compareSemver returns 0 rather than guess, and guessing wrong here
      // locks someone out of their own server over a homemade build string.
      expect(
        const LivenessInfo(alive: true, version: 'dev').isServerBelowMinimum,
        isFalse,
      );
    });

    test('is not claimed for an unreachable server', () {
      // Offline is not the same as incompatible, and guessing would put a
      // permanent wall in front of anyone with a flaky connection.
      expect(const LivenessInfo.offline().isServerBelowMinimum, isFalse);
    });
  });

  group('the recommended server version', () {
    test('nudges without blocking between the two numbers', () {
      // Nothing sits between them today; the test pins the shape so raising
      // the recommendation later cannot start blocking people by accident.
      const between = LivenessInfo(alive: true, version: '2.5.0');
      expect(between.isServerBelowMinimum, isFalse);
      expect(
        between.isServerBelowRecommended,
        compareSemver('2.5.0', recommendedServerVersion) < 0,
      );
    });

    test('a blocked server is never also merely nudged', () {
      const old = LivenessInfo(alive: true, version: '1.0.0');
      expect(old.isServerBelowMinimum, isTrue);
      expect(old.isServerBelowRecommended, isFalse);
    });

    test('is not claimed for a server that reports no version', () {
      expect(const LivenessInfo(alive: true).isServerBelowRecommended, isFalse);
    });
  });

  group('the two server banners do not stack', () {
    test('an incompatible server is outdated too, so one must defer', () {
      // Both conditions are true for a pre-2.5.0 server. OutdatedServerWarning
      // checks isServerBelowMinimum first and stands down, leaving the
      // message that tells the user what is actually broken.
      const server = LivenessInfo(alive: true, version: '2.4.1');

      expect(server.isServerBelowMinimum, isTrue);
      expect(server.isOutdatedAgainst('2.5.0'), isTrue);
    });

    test('a current server triggers neither', () {
      final server = _server(version: '2.5.0');

      expect(server.isServerBelowMinimum, isFalse);
      expect(server.isOutdatedAgainst('2.5.0'), isFalse);
    });
  });
}
