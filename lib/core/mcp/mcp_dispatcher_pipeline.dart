import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../storage/database.dart';
import 'mcp_audit_logger.dart';
import 'mcp_auditing_dispatcher.dart';
import 'mcp_gateway.dart';
import 'mcp_lock_gating_dispatcher.dart';
import 'mcp_rate_limiting_dispatcher.dart';
import 'mcp_tool_handler.dart';

/// Resolvers the pipeline needs from the enclosing [McpServer]. The server
/// owns the bearer token and the active-account state, so we pass them in
/// as closures that re-read on every tool call instead of baking values in
/// at construction time — bearer tokens rotate, accounts switch, and the
/// pipeline outlives both events.
class McpPipelineHooks {
  final String Function() bearerTokenResolver;
  final String? Function() accountIdResolver;

  const McpPipelineHooks({
    required this.bearerTokenResolver,
    required this.accountIdResolver,
  });
}

/// Build the full decorator stack used by the MCP server:
///
/// `rate limit → lock gate → audit → real tool handler`.
///
/// Rate limit runs first so a runaway agent hitting the bucket doesn't cost
/// us an audit-write per rejection. Lock gating runs before audit so the
/// audit row is the definitive record of what was denied for what reason.
/// Audit wraps the real handler so every accepted call is logged.
///
/// The rate-limit bucket is held in the returned dispatcher; the caller
/// keeps the reference so it can [RateLimitingMcpToolDispatcher.resetSessions]
/// on token rotation.
({McpToolDispatcher dispatcher, RateLimitingMcpToolDispatcher rateLimiter})
buildMcpDispatcherPipeline({
  required Ref ref,
  required McpPipelineHooks hooks,
}) {
  final db = ref.read(databaseProvider);
  final auditLogger = McpAuditLogger(db);
  final inner = McpToolHandler(
    ProductionMcpGateway(ref),
    isLocked: () => ref.read(isLockedProvider),
  );

  final auditing = AuditingMcpToolDispatcher(
    inner: inner,
    logger: auditLogger,
    bearerTokenResolver: hooks.bearerTokenResolver,
    accountIdResolver: hooks.accountIdResolver,
  );

  final lockGating = LockGatingMcpToolDispatcher(
    inner: auditing,
    auditLogger: auditLogger,
    isLockedResolver: () => ref.read(isLockedProvider),
    allowReadOnlyWhileLockedResolver: () =>
        _mcpAllowReadOnlyWhileLocked(ref, hooks.accountIdResolver()),
    bearerTokenResolver: hooks.bearerTokenResolver,
    accountIdResolver: hooks.accountIdResolver,
  );

  final rateLimiting = RateLimitingMcpToolDispatcher(
    inner: lockGating,
    auditLogger: auditLogger,
    settingsResolver: () =>
        _resolveRateLimitSettings(ref, hooks.accountIdResolver()),
    bearerTokenResolver: hooks.bearerTokenResolver,
    accountIdResolver: hooks.accountIdResolver,
  );

  return (dispatcher: rateLimiting, rateLimiter: rateLimiting);
}

bool _mcpAllowReadOnlyWhileLocked(Ref ref, String? accountId) {
  if (accountId == null) return false;
  final async = ref.read(mcpSettingsProvider);
  final settings = async.valueOrNull;
  if (settings == null || settings.accountId != accountId) return false;
  return settings.allowReadOnlyWhileLocked;
}

RateLimitSettings _resolveRateLimitSettings(Ref ref, String? accountId) {
  if (accountId == null) return RateLimitSettings.defaults;
  final async = ref.read(mcpSettingsProvider);
  final settings = async.valueOrNull;
  if (settings == null || settings.accountId != accountId) {
    return RateLimitSettings.defaults;
  }
  return _fromMcpSetting(settings);
}

RateLimitSettings _fromMcpSetting(McpSetting settings) {
  final rps = settings.rateLimitRps;
  final burst = settings.rateLimitBurst;
  if (rps <= 0 || burst <= 0) return RateLimitSettings.defaults;
  return RateLimitSettings(
    refillRatePerSecond: rps.toDouble(),
    capacity: burst,
  );
}
