import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/server_version.dart';

void main() {
  group('compareSemver', () {
    test('equal versions return zero', () {
      expect(compareSemver('1.14.0', '1.14.0'), 0);
      expect(compareSemver('v1.14.0', '1.14.0'), 0);
      expect(compareSemver('1.14.0', 'v1.14.0'), 0);
    });

    test('newer major/minor/patch are positive', () {
      expect(compareSemver('2.0.0', '1.14.0'), greaterThan(0));
      expect(compareSemver('1.15.0', '1.14.0'), greaterThan(0));
      expect(compareSemver('1.14.1', '1.14.0'), greaterThan(0));
    });

    test('older versions are negative', () {
      expect(compareSemver('1.13.2', '1.14.0'), lessThan(0));
      expect(compareSemver('1.7.0', '1.14.0'), lessThan(0));
      expect(compareSemver('0.9.0', '1.0.0'), lessThan(0));
    });

    test('two-component versions compared against three-component', () {
      // A shorter version (missing patch) is treated as "smaller" than
      // the same major.minor with an explicit patch, matching how
      // operators read "1.14" vs "1.14.0".
      expect(compareSemver('1.14', '1.14.0'), lessThan(0));
      expect(compareSemver('1.14.0', '1.14'), greaterThan(0));
    });

    test('non-numeric prerelease suffixes are tolerated, never spurious', () {
      // "1.14.0-rc1234567" is treated as equal to "1.14.0" — we'd rather
      // skip a warning for an RC of the right release than fire one.
      expect(compareSemver('1.14.0-rc1234567', '1.14.0'), 0);
      expect(compareSemver('1.14.0', '1.14.0-rc1234567'), 0);
    });

    test('malformed components halt the compare instead of crashing', () {
      // A homemade build with a non-semver version string ("dev",
      // "nightly") is treated as equal rather than panicking.
      expect(compareSemver('dev', '1.14.0'), 0);
      expect(compareSemver('1.14.0', 'nightly'), 0);
    });

    test('leading V is accepted', () {
      expect(compareSemver('V1.14.0', '1.14.0'), 0);
    });
  });

  group('LivenessInfo.isOutdatedAgainst', () {
    test('offline servers are never flagged', () {
      // We can't warn about a version we don't know.
      expect(const LivenessInfo.offline().isOutdatedAgainst('1.15.0'), isFalse);
      expect(const LivenessInfo.offline().isOutdatedAgainst(null), isFalse);
    });

    test('missing version field is verified evidence of pre-v1.16.0', () {
      // The version field landed in v1.16.0 — its absence is itself
      // proof the server is older. We don't need GitHub for this branch.
      const info = LivenessInfo(alive: true, version: null);
      expect(info.isOutdatedAgainst('1.16.0'), isTrue);
      expect(info.isOutdatedAgainst(null), isTrue);
    });

    test('reported version older than latest release is flagged', () {
      const info = LivenessInfo(alive: true, version: '1.14.0');
      expect(info.isOutdatedAgainst('1.15.0'), isTrue);
    });

    test('reported version equal to latest release is not flagged', () {
      const info = LivenessInfo(alive: true, version: '1.15.0');
      expect(info.isOutdatedAgainst('1.15.0'), isFalse);
    });

    test('reported version newer than latest release is not flagged', () {
      // Self-hosters running master-built containers will report a higher
      // version than the latest tag — that's not "outdated".
      const info = LivenessInfo(alive: true, version: '1.16.0');
      expect(info.isOutdatedAgainst('1.15.0'), isFalse);
    });

    test('null latest release means we never warn on a reported version', () {
      // When GitHub is unreachable we refuse to guess. A reported
      // version with no known baseline produces no warning, ever.
      const info = LivenessInfo(alive: true, version: '1.0.0');
      expect(info.isOutdatedAgainst(null), isFalse);
    });
  });
}
