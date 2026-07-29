import 'mcp_audit_logger.dart';
import 'mcp_protocol.dart';
import 'mcp_tool_handler.dart';

/// Decorator around another [McpToolDispatcher] that persists one audit
/// entry per tool call. The inner dispatcher sees exactly the same inputs
/// and returns the same outputs — audit is side-effect-only.
///
/// See [McpAuditLogger] for the privacy invariants this class enforces
/// (bearer token hashed, params hashed, error messages truncated).
class AuditingMcpToolDispatcher implements McpToolDispatcher {
  final McpToolDispatcher _inner;
  final McpAuditLogger _logger;

  /// Resolves the bearer token on every call because the active token can
  /// rotate without the dispatcher being rebuilt (Regenerate in settings).
  final String Function() _bearerTokenResolver;

  /// Resolves the active account id on every call because the dispatcher
  /// outlives account switches — but at that point the server would
  /// restart anyway; kept as a provider for the logged-out case.
  final String? Function() _accountIdResolver;

  AuditingMcpToolDispatcher({
    required McpToolDispatcher inner,
    required McpAuditLogger logger,
    required String Function() bearerTokenResolver,
    required String? Function() accountIdResolver,
  }) : _inner = inner,
       _logger = logger,
       _bearerTokenResolver = bearerTokenResolver,
       _accountIdResolver = accountIdResolver;

  @override
  Future<Map<String, dynamic>> handleToolCall(McpRequest request) async {
    final params = request.params ?? {};
    final toolName = params['name'] as String? ?? '';
    final arguments = params['arguments'] as Map<String, dynamic>?;

    final startedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();

    Map<String, dynamic> response;
    try {
      response = await _inner.handleToolCall(request);
    } catch (e) {
      stopwatch.stop();
      await _logger.record(
        timestamp: startedAt,
        sessionId: McpAuditLogger.sessionIdFromBearer(_bearerTokenResolver()),
        accountId: _accountIdResolver(),
        toolName: toolName.isEmpty ? '<unknown>' : toolName,
        paramsHash: McpAuditLogger.hashParams(arguments),
        resultStatus: 'error',
        errorMessage: e.toString(),
        durationMs: stopwatch.elapsedMilliseconds,
      );
      rethrow;
    }
    stopwatch.stop();

    final status = _statusFromResponse(response);
    final errorMessage = status == 'error'
        ? _extractErrorMessage(response)
        : null;

    await _logger.record(
      timestamp: startedAt,
      sessionId: McpAuditLogger.sessionIdFromBearer(_bearerTokenResolver()),
      accountId: _accountIdResolver(),
      toolName: toolName.isEmpty ? '<unknown>' : toolName,
      paramsHash: McpAuditLogger.hashParams(arguments),
      resultStatus: status,
      errorMessage: errorMessage,
      durationMs: stopwatch.elapsedMilliseconds,
    );

    return response;
  }

  /// Map a tool response back to one of the three audit statuses.
  /// The inner handler reports tool-level failures via `isError: true` and
  /// structural problems (missing tool name, etc.) via a JSON-RPC `error`
  /// object — we classify both as `error` here. `denied` is reserved for
  /// future authorisation checks (locked-state gating, per-tool scopes).
  String _statusFromResponse(Map<String, dynamic> response) {
    if (response.containsKey('error')) return 'error';
    final result = response['result'];
    if (result is Map && result['isError'] == true) return 'error';
    return 'ok';
  }

  String? _extractErrorMessage(Map<String, dynamic> response) {
    final error = response['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    final result = response['result'];
    if (result is Map) {
      final content = result['content'];
      if (content is List && content.isNotEmpty) {
        final first = content.first;
        if (first is Map && first['text'] is String) {
          return first['text'] as String;
        }
      }
    }
    return null;
  }
}
