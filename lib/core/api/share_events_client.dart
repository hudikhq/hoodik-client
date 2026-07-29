import 'package:dio/dio.dart';

import 'share_event_models.dart';

/// HTTP client scoped to the audit-log route (`GET /api/shares/events`).
///
/// Constructed with the [Dio] instance [ApiClient] owns, so it shares the same
/// auth interceptors, cookie jar, and refresh handling. Kept separate from
/// [SharesClient] because the audit surface is its own resource and folding it
/// in would push `shares_client.dart` past its line target.
class ShareEventsClient {
  final Dio _dio;

  ShareEventsClient(this._dio);

  /// `GET /api/shares/events` — one page of the caller's audit log: every row
  /// they authored, every row targeting them, and every row on a file they
  /// own. [query] carries the optional file/action filters and the
  /// limit/offset window.
  ///
  /// Errors propagate (unlike `getCapabilities`): the audit screen renders a
  /// load-failure state, and swallowing here would mask a real fetch problem
  /// behind an empty list. The page's `users` map is parsed alongside the
  /// events so rows can be labelled and signatures verified without a second
  /// round-trip.
  Future<ShareEventPage> getEvents(ShareEventQuery query) async {
    final resp = await _dio.get(
      '/api/shares/events',
      queryParameters: query.toQueryParameters(),
    );
    return ShareEventPage.fromJson(resp.data as Map<String, dynamic>);
  }
}
