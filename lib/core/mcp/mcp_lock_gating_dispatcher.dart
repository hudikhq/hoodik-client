import '../utils/logger.dart';
import 'mcp_audit_logger.dart';
import 'mcp_protocol.dart';
import 'mcp_tool_handler.dart';

/// JSON-RPC error code for "user locked — agent access paused". Picked from
/// the application-reserved `-32000 .. -32099` window so we don't collide
/// with spec-defined codes.
const int mcpErrorUserLocked = -32001;

/// Tools whose implementation never touches a decrypted file body or a
/// decrypted file key. Kept as a denylist of the crypto-requiring tools
/// instead of an allowlist so a new tool that forgets to register here
/// defaults to "requires decryption", which is the safer failure mode.
const Set<String> _readOnlyMcpTools = {
  'list_files',
  'resolve_path',
  'list_notes',
  'search_files',
  'storage_stats',
  'health',
};

/// Which tools the gate classifies as safe to serve while the app is locked.
bool isReadOnlyMcpTool(String toolName) => _readOnlyMcpTools.contains(toolName);

/// Decorator stacked in front of the real dispatcher that refuses tool calls
/// while the app is PIN-locked. See MCP.md for why: while the UI
/// is locked we treat the decrypted private key as unavailable even though
/// it is technically still in memory, so an agent cannot use a cached
/// session to pull plaintext past a lock.
///
/// Read-only tools (ones that do not decrypt file content) can optionally be
/// allowed through when the user opts in via settings. Default is deny-all.
class LockGatingMcpToolDispatcher implements McpToolDispatcher {
  final McpToolDispatcher _inner;
  final McpAuditLogger _auditLogger;
  final bool Function() _isLockedResolver;
  final bool Function() _allowReadOnlyWhileLockedResolver;
  final String Function() _bearerTokenResolver;
  final String? Function() _accountIdResolver;
  final Logger _log;

  LockGatingMcpToolDispatcher({
    required McpToolDispatcher inner,
    required McpAuditLogger auditLogger,
    required bool Function() isLockedResolver,
    required bool Function() allowReadOnlyWhileLockedResolver,
    required String Function() bearerTokenResolver,
    required String? Function() accountIdResolver,
    Logger log = const Logger('mcp.dispatch'),
  }) : _inner = inner,
       _auditLogger = auditLogger,
       _isLockedResolver = isLockedResolver,
       _allowReadOnlyWhileLockedResolver = allowReadOnlyWhileLockedResolver,
       _bearerTokenResolver = bearerTokenResolver,
       _accountIdResolver = accountIdResolver,
       _log = log;

  @override
  Future<Map<String, dynamic>> handleToolCall(McpRequest request) async {
    if (!_isLockedResolver()) {
      return _inner.handleToolCall(request);
    }

    final params = request.params ?? {};
    final toolName = params['name'] as String? ?? '';
    final allowReadOnly = _allowReadOnlyWhileLockedResolver();
    // health is always allowed while locked so an agent can discover that
    // writes are paused. Other read-only tools still need the user opt-in.
    if (toolName == 'health' ||
        (allowReadOnly && isReadOnlyMcpTool(toolName))) {
      return _inner.handleToolCall(request);
    }

    final arguments = params['arguments'] as Map<String, dynamic>?;
    final message = allowReadOnly
        ? 'user locked - agent access paused (only read-only tools allowed)'
        : 'user locked - agent access paused';

    await _auditLogger.record(
      timestamp: DateTime.now(),
      sessionId: McpAuditLogger.sessionIdFromBearer(_bearerTokenResolver()),
      accountId: _accountIdResolver(),
      toolName: toolName.isEmpty ? '<unknown>' : toolName,
      paramsHash: McpAuditLogger.hashParams(arguments),
      resultStatus: 'denied',
      errorMessage: message,
      durationMs: 0,
    );

    _log.warn(
      'mcp tool call denied: user locked',
      fields: {
        'tool': toolName,
        'reason': 'locked',
        'allow_read_only': allowReadOnly,
      },
    );

    return mcpErrorResponse(request.id, mcpErrorUserLocked, message);
  }
}
