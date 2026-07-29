import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/mcp/mcp_audit_logger.dart';
import 'package:hoodik_app/core/mcp/mcp_auditing_dispatcher.dart';
import 'package:hoodik_app/core/mcp/mcp_protocol.dart';
import 'package:hoodik_app/core/mcp/mcp_rate_limiter.dart';
import 'package:hoodik_app/core/mcp/mcp_rate_limiting_dispatcher.dart';
import 'package:hoodik_app/core/mcp/mcp_tool_handler.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/mcp_audit_dao.dart';

import 'helpers/fake_mcp_gateway.dart';

/// Test clock that advances manually. Returns the current [now] on every
/// call so a single test can drive refills through deterministic time
/// jumps without relying on `await Future.delayed`.
class _ManualClock {
  DateTime now;
  _ManualClock(this.now);

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
}

Future<Map<String, dynamic>> _call(
  McpToolDispatcher handler,
  String tool, {
  int id = 1,
}) {
  return handler.handleToolCall(
    McpRequest(
      jsonrpc: '2.0',
      method: 'tools/call',
      id: id,
      params: {'name': tool, 'arguments': const <String, dynamic>{}},
    ),
  );
}

bool _isDenied(Map<String, dynamic> resp) =>
    resp['error']?['code'] == mcpErrorRateLimitExceeded;

void main() {
  group('RateLimiter token bucket', () {
    test('tryConsume debits one token on success', () {
      final clock = _ManualClock(DateTime(2026, 1, 1));
      final limiter = RateLimiter(
        capacity: 3,
        refillRatePerSecond: 1,
        clock: clock.call,
      );

      expect(limiter.availableTokens, 3);
      expect(limiter.tryConsume(), isTrue);
      expect(limiter.availableTokens, 2);
      expect(limiter.tryConsume(), isTrue);
      expect(limiter.tryConsume(), isTrue);
      expect(limiter.tryConsume(), isFalse);
    });

    test('refills over time at the configured rate', () {
      final clock = _ManualClock(DateTime(2026, 1, 1));
      final limiter = RateLimiter(
        capacity: 10,
        refillRatePerSecond: 5,
        clock: clock.call,
      );

      // Drain the bucket.
      for (var i = 0; i < 10; i++) {
        expect(limiter.tryConsume(), isTrue);
      }
      expect(limiter.tryConsume(), isFalse);

      // Advance one second — should refill 5 tokens.
      clock.advance(const Duration(seconds: 1));
      expect(limiter.availableTokens, 5);
      for (var i = 0; i < 5; i++) {
        expect(limiter.tryConsume(), isTrue);
      }
      expect(limiter.tryConsume(), isFalse);
    });

    test('burst capacity caps the bucket, no overflow accumulation', () {
      final clock = _ManualClock(DateTime(2026, 1, 1));
      final limiter = RateLimiter(
        capacity: 5,
        refillRatePerSecond: 10,
        clock: clock.call,
      );

      clock.advance(const Duration(seconds: 60));
      expect(limiter.availableTokens, 5);
    });

    test('retryAfter reports time to next token when empty', () {
      final clock = _ManualClock(DateTime(2026, 1, 1));
      final limiter = RateLimiter(
        capacity: 1,
        refillRatePerSecond: 2,
        clock: clock.call,
      );

      expect(limiter.tryConsume(), isTrue);
      expect(limiter.retryAfter, greaterThan(Duration.zero));

      clock.advance(const Duration(milliseconds: 600));
      expect(limiter.tryConsume(), isTrue);
    });
  });

  group('RateLimitingMcpToolDispatcher', () {
    late AppDatabase db;
    late FakeMcpGateway gateway;
    late _ManualClock clock;
    late RateLimitingMcpToolDispatcher dispatcher;
    late RateLimitSettings currentSettings;
    String currentBearer = 'session-A-token';

    RateLimitSettings resolveSettings() => currentSettings;
    String bearer() => currentBearer;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      gateway = FakeMcpGateway();
      clock = _ManualClock(DateTime(2026, 4, 19));
      currentSettings = const RateLimitSettings(
        refillRatePerSecond: 1,
        capacity: 2,
      );

      final audit = AuditingMcpToolDispatcher(
        inner: McpToolHandler(gateway),
        logger: McpAuditLogger(db),
        bearerTokenResolver: bearer,
        accountIdResolver: () => 'acct',
      );
      dispatcher = RateLimitingMcpToolDispatcher(
        inner: audit,
        auditLogger: McpAuditLogger(db),
        settingsResolver: resolveSettings,
        bearerTokenResolver: bearer,
        accountIdResolver: () => 'acct',
        clock: clock.call,
      );
    });

    tearDown(() async => db.close());

    test('within-capacity calls succeed', () async {
      final r1 = await _call(dispatcher, 'list_files', id: 1);
      final r2 = await _call(dispatcher, 'list_files', id: 2);
      expect(_isDenied(r1), isFalse);
      expect(_isDenied(r2), isFalse);
    });

    test(
      'over-capacity call returns rate-limit error and denied audit row',
      () async {
        await _call(dispatcher, 'list_files', id: 1);
        await _call(dispatcher, 'list_files', id: 2);
        final third = await _call(dispatcher, 'list_files', id: 3);

        expect(_isDenied(third), isTrue);
        expect(third['error']['message'], contains('rate_limit'));
        expect(third['error']['data']['retry_after_ms'], isA<int>());

        final entries = await db.getMcpAuditEntries();
        final denied = entries
            .where((e) => e.resultStatus == 'denied')
            .toList();
        expect(denied, hasLength(1));
        expect(denied.single.errorMessage, contains('rate_limit'));
      },
    );

    test('refill restores capacity so later calls succeed', () async {
      await _call(dispatcher, 'list_files', id: 1);
      await _call(dispatcher, 'list_files', id: 2);
      final denied = await _call(dispatcher, 'list_files', id: 3);
      expect(_isDenied(denied), isTrue);

      clock.advance(const Duration(seconds: 2));
      final recovered = await _call(dispatcher, 'list_files', id: 4);
      expect(_isDenied(recovered), isFalse);
    });

    test('settings change resets buckets on the next call', () async {
      await _call(dispatcher, 'list_files', id: 1);
      await _call(dispatcher, 'list_files', id: 2);
      expect(_isDenied(await _call(dispatcher, 'list_files', id: 3)), isTrue);

      currentSettings = const RateLimitSettings(
        refillRatePerSecond: 10,
        capacity: 5,
      );

      expect(_isDenied(await _call(dispatcher, 'list_files', id: 4)), isFalse);
    });

    test('two sessions have independent buckets', () async {
      await _call(dispatcher, 'list_files', id: 1);
      await _call(dispatcher, 'list_files', id: 2);
      expect(_isDenied(await _call(dispatcher, 'list_files', id: 3)), isTrue);

      currentBearer = 'session-B-token';
      expect(_isDenied(await _call(dispatcher, 'list_files', id: 4)), isFalse);
      expect(_isDenied(await _call(dispatcher, 'list_files', id: 5)), isFalse);
      expect(_isDenied(await _call(dispatcher, 'list_files', id: 6)), isTrue);
    });

    test('resetSessions clears per-session buckets', () async {
      await _call(dispatcher, 'list_files', id: 1);
      await _call(dispatcher, 'list_files', id: 2);
      expect(_isDenied(await _call(dispatcher, 'list_files', id: 3)), isTrue);

      dispatcher.resetSessions();
      expect(_isDenied(await _call(dispatcher, 'list_files', id: 4)), isFalse);
    });
  });
}
