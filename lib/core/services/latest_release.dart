import 'package:dio/dio.dart';

/// Latest tagged release of the hudikhq/hoodik server, as reported by the
/// GitHub Releases API. The version string is normalised — leading `v` and
/// any prerelease suffix are stripped so it can be fed directly into
/// [compareSemver].
class LatestRelease {
  final String version;
  final String htmlUrl;

  const LatestRelease({required this.version, required this.htmlUrl});

  @override
  String toString() => 'LatestRelease(version=$version, htmlUrl=$htmlUrl)';
}

/// Fetches the latest published release for a GitHub repo. Returns `null`
/// on any failure (network down, GitHub down, repo moved, response shape
/// changed). Callers MUST treat a `null` return as "we don't know" — never
/// as a fallback signal that justifies a warning.
///
/// A fresh [Dio] is used by default so no Hoodik session cookies, base URL,
/// or auth headers leak to api.github.com. Tests inject their own client.
class LatestReleaseFetcher {
  final Dio _dio;

  LatestReleaseFetcher({Dio? dio}) : _dio = dio ?? _defaultClient();

  static Dio _defaultClient() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        responseType: ResponseType.json,
        headers: {'Accept': 'application/vnd.github+json'},
      ),
    );
    return dio;
  }

  Future<LatestRelease?> fetch({String repo = 'hudikhq/hoodik'}) async {
    try {
      final resp = await _dio.get<dynamic>(
        'https://api.github.com/repos/$repo/releases/latest',
      );
      if (resp.statusCode != 200) return null;
      final data = resp.data;
      if (data is! Map) return null;
      final tag = data['tag_name'];
      final url = data['html_url'];
      if (tag is! String || tag.isEmpty) return null;
      return LatestRelease(
        version: _normalise(tag),
        htmlUrl: url is String ? url : '',
      );
    } catch (_) {
      return null;
    }
  }

  static String _normalise(String tag) {
    var s = tag.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    return s;
  }
}
