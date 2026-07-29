import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../storage/database.dart';
import '../storage/mcp_audit_dao.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';

const _log = Logger('mcp.audit');

/// Persists one [McpAuditLog] row per MCP tool invocation.
///
/// The audit trail is observational — if a write fails it is reported via
/// the structured logger but MUST NOT propagate, because an audit-storage
/// bug must never take down a user's actual tool call.
///
/// Privacy invariants (see MCP.md):
///   - The bearer token is never persisted; only a short hash is kept so the
///     UI can group calls by the same agent without exposing the secret.
///   - Params are canonicalised and hashed before writing, so nothing the
///     user sent (file names, content, search queries) survives in plaintext.
class McpAuditLogger {
  final AppDatabase _db;

  McpAuditLogger(this._db);

  /// Length of the stored session-hash prefix. 16 hex chars = 64 bits of
  /// uniqueness, plenty to distinguish agents while keeping the UI readable.
  static const int _sessionHashLen = 16;

  /// Truncate an error message to keep individual audit rows bounded.
  /// The user can still tell "what went wrong", but we don't store a full
  /// stack trace that might include paths, queries, or other incidental PII.
  static const int _maxErrorMessageLen = 500;

  /// Derive the sessionId stored on the audit row from the bearer token.
  ///
  /// Returns the empty string when [bearerToken] is empty (e.g. the server
  /// is running with no auth token set, which means no agent is connected).
  static String sessionIdFromBearer(String? bearerToken) {
    if (bearerToken == null || bearerToken.isEmpty) return '';
    final digest = sha256.convert(utf8.encode(bearerToken));
    return digest.toString().substring(0, _sessionHashLen);
  }

  /// Canonicalise [params] and hash them with SHA256.
  ///
  /// Canonicalisation = keys sorted alphabetically at every depth, so
  /// `{"a":1,"b":2}` and `{"b":2,"a":1}` produce identical hashes. Returns
  /// the empty string when [params] is null or empty — the UI renders those
  /// as "no params" without having to distinguish an all-defaults call from
  /// a literally-empty one.
  static String hashParams(Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) return '';
    final canonical = jsonEncode(_sortKeys(params));
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static Object? _sortKeys(Object? value) {
    if (value is Map) {
      final sorted = <String, Object?>{};
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      for (final k in keys) {
        sorted[k] = _sortKeys(value[k]);
      }
      return sorted;
    }
    if (value is List) {
      return value.map(_sortKeys).toList();
    }
    return value;
  }

  /// Write one audit entry. Returns without throwing on failure — see the
  /// class doc for why.
  Future<void> record({
    required DateTime timestamp,
    required String sessionId,
    String? accountId,
    required String toolName,
    required String paramsHash,
    required String resultStatus,
    String? errorMessage,
    required int durationMs,
  }) async {
    try {
      await _db.insertMcpAuditEntry(
        timestamp: timestamp,
        sessionId: sessionId,
        accountId: accountId,
        toolName: toolName,
        paramsHash: paramsHash,
        resultStatus: resultStatus,
        errorMessage: _truncate(errorMessage),
        durationMs: durationMs,
      );
    } catch (e) {
      _log.warn('audit write failed', fields: {'error': redactException(e)});
    }
  }

  String? _truncate(String? message) {
    if (message == null) return null;
    if (message.length <= _maxErrorMessageLen) return message;
    return message.substring(0, _maxErrorMessageLen);
  }
}
