/// Timestamp captured at app start so the bug-report flow can filter
/// "current session only" logs by `ts >= AppSession.startedAt`.
///
/// Called exactly once from `main()` before any logger configuration.
class AppSession {
  static DateTime _startedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// The moment this app process started. Returns the epoch until
  /// [start] has been called, so callers never get a null.
  static DateTime get startedAt => _startedAt;

  /// Record the current instant as the session's start. Idempotent —
  /// calling twice keeps the first value so repeated invocations (tests,
  /// hot reload) don't move the boundary mid-session.
  static void start() {
    if (_startedAt.millisecondsSinceEpoch != 0) return;
    _startedAt = DateTime.now();
  }

  /// Test helper — reset the session so `setUp` can pin a known start.
  static void resetForTests() {
    _startedAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Test helper — set an exact session start, bypassing the idempotence
  /// guard in [start].
  static void setForTests(DateTime instant) {
    _startedAt = instant;
  }
}
