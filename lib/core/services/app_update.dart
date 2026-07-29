import 'dart:io';

import 'package:dio/dio.dart';
import 'package:in_app_update/in_app_update.dart';

import 'server_version.dart';

/// The version currently live on the App Store for a bundle id, plus a deep
/// link to its store page. Read from Apple's public iTunes lookup endpoint.
class AppStoreVersion {
  final String version;
  final String storeUrl;

  const AppStoreVersion({required this.version, required this.storeUrl});

  @override
  String toString() => 'AppStoreVersion(version=$version, storeUrl=$storeUrl)';
}

/// Reads the latest published App Store version from Apple's iTunes lookup
/// API. Returns `null` on any failure — callers MUST treat `null` as "we
/// don't know" and never as grounds to nudge (same stance as
/// [LatestReleaseFetcher]).
///
/// A dedicated [Dio] keeps Hoodik session cookies and the server base URL off
/// itunes.apple.com. Tests inject their own client.
class AppStoreVersionFetcher {
  final Dio _dio;

  AppStoreVersionFetcher({Dio? dio}) : _dio = dio ?? _defaultClient();

  static Dio _defaultClient() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      responseType: ResponseType.json,
    ),
  );

  Future<AppStoreVersion?> fetch({
    String bundleId = 'com.hudikhq.hoodik',
  }) async {
    try {
      final resp = await _dio.get<dynamic>(
        'https://itunes.apple.com/lookup',
        queryParameters: {'bundleId': bundleId},
      );
      if (resp.statusCode != 200) return null;
      final data = resp.data;
      if (data is! Map) return null;
      final results = data['results'];
      if (results is! List || results.isEmpty) return null;
      final first = results.first;
      if (first is! Map) return null;
      final version = first['version'];
      if (version is! String || version.trim().isEmpty) return null;
      final storeUrl = first['trackViewUrl'];
      return AppStoreVersion(
        version: version.trim(),
        storeUrl: storeUrl is String ? storeUrl : '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// True only when we know both the running version and the store version and
/// the store is strictly newer. A `null` on either side means "we don't know"
/// so we stay quiet — the same no-guesswork rule the outdated-server banner
/// follows. On Android [store] is always null (Play drives its own flow), so
/// this banner is effectively Apple-only.
bool appUpdateAvailable({
  required String? current,
  required AppStoreVersion? store,
}) {
  if (current == null || store == null) return false;
  return compareSemver(current, store.version) < 0;
}

/// Starts Google Play's flexible in-app update when a newer build is live on
/// Play. No-op that never throws off Android or on non-Play installs — the
/// App Store path covers iOS/macOS. Returns `true` once the update has
/// finished downloading and is ready to install, so the caller can offer the
/// restart.
Future<bool> startPlayFlexibleUpdateIfAvailable() async {
  if (!Platform.isAndroid) return false;
  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      return false;
    }
    if (!info.flexibleUpdateAllowed) return false;
    final result = await InAppUpdate.startFlexibleUpdate();
    return result == AppUpdateResult.success;
  } catch (_) {
    return false;
  }
}

/// Installs a flexible update that already finished downloading. Restarts the
/// app as part of the install; safe to call only after
/// [startPlayFlexibleUpdateIfAvailable] returned `true`.
Future<void> completePlayFlexibleUpdate() async {
  if (!Platform.isAndroid) return;
  try {
    await InAppUpdate.completeFlexibleUpdate();
  } catch (_) {}
}
