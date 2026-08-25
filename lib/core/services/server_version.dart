/// The oldest server this app will talk to.
///
/// Not a nudge — below this the app refuses to run. 2.5.0 is where the keyed
/// search index landed: an older server still stores the reversible digests
/// this build cannot produce, so anything written to it is indexed in a shape
/// it will never match. Nothing about that is visible at the time, which is
/// why it is a refusal and not a banner.
///
/// Raising this locks out everyone whose server has not been updated yet, so
/// it moves rarely, and never in the same release as a feature that could
/// have been made to degrade instead.
const minimumServerVersion = '2.5.0';

/// The server this build is made for. Above the minimum, so a server between
/// the two works while missing what this release was written against — worth
/// a nudge and nothing more. Cheap to raise, which is the point of keeping it
/// separate from the number that locks people out.
const recommendedServerVersion = '2.5.0';

/// Result of a `/api/liveness` probe. Captures whether the server is
/// reachable and — from v1.16.0 onward — which version is running, so
/// the UI can nudge self-hosters to upgrade when their server predates
/// the latest published release.
class LivenessInfo {
  final bool alive;

  /// Version string as reported by the server, e.g. `"1.14.1"`. `null`
  /// on unreachable servers OR on servers older than v1.16.0 that ship
  /// `/api/liveness` without a `version` field.
  final String? version;

  /// Oldest app this server will serve, as reported by `/api/liveness`.
  /// `null` on servers predating the field.
  final String? minimumClientVersion;

  /// App version this server is built to work with. `null` on servers
  /// predating the field.
  final String? recommendedClientVersion;

  const LivenessInfo({
    required this.alive,
    this.version,
    this.minimumClientVersion,
    this.recommendedClientVersion,
  });

  const LivenessInfo.offline()
    : alive = false,
      version = null,
      minimumClientVersion = null,
      recommendedClientVersion = null;

  /// This app is too old for the server and must be updated before it can
  /// work. Blocks rather than nudges.
  bool isClientBelowMinimum(String clientVersion) =>
      alive &&
      minimumClientVersion != null &&
      compareSemver(clientVersion, minimumClientVersion!) < 0;

  /// This app still works but is behind what the server is built for. Worth a
  /// nudge and nothing more, which is why it is a separate number from the
  /// minimum: raising the recommendation is cheap, raising the minimum breaks
  /// people.
  bool isClientBelowRecommended(String clientVersion) =>
      alive &&
      recommendedClientVersion != null &&
      compareSemver(clientVersion, recommendedClientVersion!) < 0 &&
      !isClientBelowMinimum(clientVersion);

  /// The server is older than [minimumServerVersion], so this app refuses to
  /// work against it.
  ///
  /// A server that reports no version at all predates the field, which
  /// arrived in v1.16.0, and so is far below the minimum — absence is a
  /// deterministic answer here, not a missing one. A version that parses to
  /// nothing (a homemade `dev` build) compares equal and is let through:
  /// [compareSemver] refuses to guess, and guessing wrong here locks someone
  /// out of their own server.
  bool get isServerBelowMinimum {
    if (!alive) return false;
    if (version == null) return true;
    return compareSemver(version!, minimumServerVersion) < 0;
  }

  /// The server works but is behind what this build was written against.
  /// Worth a nudge, never a block — which is why it is a separate number
  /// from [minimumServerVersion].
  bool get isServerBelowRecommended =>
      alive &&
      version != null &&
      compareSemver(version!, recommendedServerVersion) < 0 &&
      !isServerBelowMinimum;

  /// True iff we have **verified evidence** that this server is older
  /// than what's currently published. Two independent signals qualify:
  ///
  ///  1. The server is alive but omits the `version` field — that field
  ///     was added in v1.16.0, so its absence is a deterministic signal
  ///     that the server predates v1.16.0. We don't need GitHub for this.
  ///  2. The server reports a version AND we know the latest released
  ///     version (passed in as [latestRelease]) AND the server is older.
  ///
  /// If [latestRelease] is `null` (GitHub unreachable, repo moved, etc.)
  /// and the server reports a version, we return `false`. We refuse to
  /// guess — a false-positive warning erodes trust faster than a missed
  /// one.
  bool isOutdatedAgainst(String? latestRelease) {
    if (!alive) return false;
    if (version == null) return true;
    if (latestRelease == null) return false;
    return compareSemver(version!, latestRelease) < 0;
  }

  @override
  String toString() => 'LivenessInfo(alive=$alive, version=$version)';
}

/// Lexicographic comparison over dotted numeric components — good enough
/// for the `MAJOR.MINOR.PATCH` scheme hoodik ships. Non-numeric suffixes
/// like `-rc1234567` are tolerated: they're stripped from the first
/// component that contains them, and the comparison bails to zero after
/// that component to stay conservative (we'd rather not warn on an RC
/// of the same release than warn incorrectly).
///
/// Accepts optional leading `v` to match both `1.14.0` and `v1.14.0`.
int compareSemver(String a, String b) {
  final left = _parse(a);
  final right = _parse(b);

  // If either side produced no numeric components (homemade "dev" or
  // "nightly" builds), we don't have enough information to tell which
  // is newer. Prefer no warning over a wrong warning and return 0.
  if (left.parsedAny != right.parsedAny &&
      (left.parsedAny == false || right.parsedAny == false)) {
    return 0;
  }
  if (!left.parsedAny && !right.parsedAny) return 0;

  final n = left.values.length < right.values.length
      ? left.values.length
      : right.values.length;
  for (var i = 0; i < n; i++) {
    final diff = left.values[i].compareTo(right.values[i]);
    if (diff != 0) return diff;
  }
  return left.values.length.compareTo(right.values.length);
}

class _ParsedVersion {
  final List<int> values;
  final bool parsedAny;

  const _ParsedVersion(this.values, this.parsedAny);
}

_ParsedVersion _parse(String raw) {
  var s = raw.trim();
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  final out = <int>[];
  for (final part in s.split('.')) {
    // Snip any prerelease/build suffix: "0-rc1234" -> "0".
    final stop = part.indexOf(RegExp(r'[^0-9]'));
    final numeric = stop == -1 ? part : part.substring(0, stop);
    final value = int.tryParse(numeric);
    if (value == null) break;
    out.add(value);
  }
  return _ParsedVersion(out, out.isNotEmpty);
}
