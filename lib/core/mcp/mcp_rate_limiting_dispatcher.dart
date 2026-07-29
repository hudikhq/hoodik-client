import '../utils/logger.dart';
import 'mcp_audit_logger.dart';
import 'mcp_protocol.dart';
import 'mcp_rate_limiter.dart';
import 'mcp_tool_handler.dart';

/// JSON-RPC error code for "rate limit exceeded". Picked from the
/// application-reserved `-32000 .. -32099` window.
const int mcpErrorRateLimitExceeded = -32002;

/// Settings-backed bucket parameters. The server reads these whenever a
/// session is minted so a settings change takes effect on the next session
/// without a server restart.
class RateLimitSettings {
  /// Tokens added per second (steady-state allowance).
  final double refillRatePerSecond;

  /// Max tokens in the bucket (burst allowance).
  final int capacity;

  const RateLimitSettings({
    required this.refillRatePerSecond,
    required this.capacity,
  });

  /// Safe default: 5 rps with a 20-token burst — enough for interactive
  /// agent use, tight enough that a runaway loop hits the wall fast.
  static const RateLimitSettings defaults = RateLimitSettings(
    refillRatePerSecond: 5.0,
    capacity: 20,
  );
}

/// Decorator that throttles tool calls per session (bearer token).
///
/// Each unique session hash gets its own [RateLimiter]. A session that
/// exceeds its allowance receives a JSON-RPC error with the retry-after
/// hint — the audit row is written with `resultStatus: 'denied'` and an
/// error message that starts with "rate_limit" so the UI can group denials
/// cleanly in the audit log.
class RateLimitingMcpToolDispatcher implements McpToolDispatcher {
  final McpToolDispatcher _inner;
  final McpAuditLogger _auditLogger;
  final RateLimitSettings Function() _settingsResolver;
  final String Function() _bearerTokenResolver;
  final String? Function() _accountIdResolver;
  final Clock _clock;
  final Logger _log;

  final Map<String, RateLimiter> _bucketsBySession = {};
  RateLimitSettings? _lastSettings;

  RateLimitingMcpToolDispatcher({
    required McpToolDispatcher inner,
    required McpAuditLogger auditLogger,
    required RateLimitSettings Function() settingsResolver,
    required String Function() bearerTokenResolver,
    required String? Function() accountIdResolver,
    Clock clock = DateTime.now,
    Logger log = const Logger('mcp.dispatch'),
  }) : _inner = inner,
       _auditLogger = auditLogger,
       _settingsResolver = settingsResolver,
       _bearerTokenResolver = bearerTokenResolver,
       _accountIdResolver = accountIdResolver,
       _clock = clock,
       _log = log;

  @override
  Future<Map<String, dynamic>> handleToolCall(McpRequest request) async {
    final bearer = _bearerTokenResolver();
    final sessionId = McpAuditLogger.sessionIdFromBearer(bearer);

    final bucket = _bucketFor(sessionId);
    if (bucket.tryConsume()) {
      return _inner.handleToolCall(request);
    }

    final params = request.params ?? {};
    final toolName = params['name'] as String? ?? '';
    final arguments = params['arguments'] as Map<String, dynamic>?;
    final retryAfter = bucket.retryAfter;
    final retrySeconds = (retryAfter.inMilliseconds / 1000).toStringAsFixed(2);
    final message = 'rate_limit: exceeded, retry after ${retrySeconds}s';

    await _auditLogger.record(
      timestamp: DateTime.now(),
      sessionId: sessionId,
      accountId: _accountIdResolver(),
      toolName: toolName.isEmpty ? '<unknown>' : toolName,
      paramsHash: McpAuditLogger.hashParams(arguments),
      resultStatus: 'denied',
      errorMessage: message,
      durationMs: 0,
    );

    _log.warn(
      'mcp tool call denied: rate limit',
      fields: {
        'tool': toolName,
        'reason': 'rate_limit',
        'retry_after_ms': retryAfter.inMilliseconds,
      },
    );

    return mcpErrorResponse(
      request.id,
      mcpErrorRateLimitExceeded,
      message,
      data: {'retry_after_ms': retryAfter.inMilliseconds},
    );
  }

  /// Discard all per-session buckets — called when the bearer token is
  /// rotated or the user logs out so a fresh session starts clean.
  void resetSessions() {
    _bucketsBySession.clear();
    _lastSettings = null;
  }

  RateLimiter _bucketFor(String sessionId) {
    final settings = _settingsResolver();
    if (_lastSettings != null &&
        (_lastSettings!.capacity != settings.capacity ||
            _lastSettings!.refillRatePerSecond !=
                settings.refillRatePerSecond)) {
      _bucketsBySession.clear();
    }
    _lastSettings = settings;

    return _bucketsBySession.putIfAbsent(
      sessionId,
      () => RateLimiter(
        capacity: settings.capacity,
        refillRatePerSecond: settings.refillRatePerSecond,
        clock: _clock,
      ),
    );
  }
}
