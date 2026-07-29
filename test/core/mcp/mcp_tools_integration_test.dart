import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/mcp/mcp_audit_logger.dart';
import 'package:hoodik_app/core/mcp/mcp_auditing_dispatcher.dart';
import 'package:hoodik_app/core/mcp/mcp_lock_gating_dispatcher.dart';
import 'package:hoodik_app/core/mcp/mcp_protocol.dart';
import 'package:hoodik_app/core/mcp/mcp_rate_limiting_dispatcher.dart';
import 'package:hoodik_app/core/mcp/mcp_tool_handler.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/mcp_audit_dao.dart';

import 'helpers/fake_mcp_gateway.dart';
import 'helpers/mcp_test_helpers.dart';

void main() {
  final ctx = McpToolTestFixture();

  setUp(ctx.setUpEach);
  tearDown(ctx.tearDownEach);

  group('audit error path', () {
    test('exception inside a tool is recorded with status error', () async {
      ctx.gateway.throwOnTool = 'create_directory';

      // Handler catches the tool exception and wraps it in the
      // success-with-isError envelope; the auditing dispatcher classifies
      // that as an "error" audit row.
      await expectLater(
        () => ctx.invoke('create_directory', {'name': 'fail'}),
        throwsA(isA<StateError>()),
      );

      final entries = await ctx.db.getMcpAuditEntries();
      expect(entries, hasLength(1));
      expect(entries.single.toolName, 'create_directory');
      expect(entries.single.resultStatus, 'error');
      expect(entries.single.errorMessage, isNotNull);
      expect(entries.single.errorMessage, contains('forced failure'));
    });
  });

  group('audit privacy invariants', () {
    test('params hash is SHA256 of canonicalised arguments', () async {
      await ctx.invoke('create_directory', {'name': 'privacy-test'});

      final entry = (await ctx.db.getMcpAuditEntries()).single;
      expect(entry.paramsHash, hasLength(64));
      expect(
        entry.paramsHash,
        McpAuditLogger.hashParams({'name': 'privacy-test'}),
      );
      // The raw name must never appear in any stored column.
      expect(entry.paramsHash, isNot(contains('privacy-test')));
      expect(entry.errorMessage ?? '', isNot(contains('privacy-test')));
    });

    test('session id is a hash of the bearer token, never the token', () async {
      await ctx.invoke('create_directory', {'name': 'd'});

      final entry = (await ctx.db.getMcpAuditEntries()).single;
      expect(entry.sessionId, ctx.expectedSessionId);
      expect(entry.sessionId, isNot(equals(testBearer)));
      expect(entry.sessionId.length, 16);
    });
  });

  group('composed pipeline: rate limit + lock gate + audit', () {
    late AppDatabase db;
    late FakeMcpGateway gateway;
    late McpToolDispatcher pipeline;
    var locked = false;
    var allowReadOnly = false;
    RateLimitSettings currentSettings = const RateLimitSettings(
      refillRatePerSecond: 1,
      capacity: 2,
    );

    setUp(() {
      locked = false;
      allowReadOnly = false;
      currentSettings = const RateLimitSettings(
        refillRatePerSecond: 1,
        capacity: 2,
      );

      db = AppDatabase.forTesting(NativeDatabase.memory());
      gateway = FakeMcpGateway();

      final audit = AuditingMcpToolDispatcher(
        inner: McpToolHandler(gateway),
        logger: McpAuditLogger(db),
        bearerTokenResolver: () => testBearer,
        accountIdResolver: () => testAccountId,
      );
      final lockGate = LockGatingMcpToolDispatcher(
        inner: audit,
        auditLogger: McpAuditLogger(db),
        isLockedResolver: () => locked,
        allowReadOnlyWhileLockedResolver: () => allowReadOnly,
        bearerTokenResolver: () => testBearer,
        accountIdResolver: () => testAccountId,
      );
      pipeline = RateLimitingMcpToolDispatcher(
        inner: lockGate,
        auditLogger: McpAuditLogger(db),
        settingsResolver: () => currentSettings,
        bearerTokenResolver: () => testBearer,
        accountIdResolver: () => testAccountId,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'lock takes precedence: locked + crypto tool is denied regardless of bucket',
      () async {
        locked = true;

        final response = await pipeline.handleToolCall(
          McpRequest(
            jsonrpc: '2.0',
            method: 'tools/call',
            id: 1,
            params: {
              'name': 'write_file',
              'arguments': {'name': 'x.txt', 'content': 'y'},
            },
          ),
        );
        expect(response['error']['code'], mcpErrorUserLocked);
        expect(gateway.files, isEmpty);
      },
    );

    test('rate limit fires before lock gate when bucket is dry', () async {
      await pipeline.handleToolCall(
        McpRequest(
          jsonrpc: '2.0',
          method: 'tools/call',
          id: 1,
          params: {
            'name': 'list_files',
            'arguments': const <String, dynamic>{},
          },
        ),
      );
      await pipeline.handleToolCall(
        McpRequest(
          jsonrpc: '2.0',
          method: 'tools/call',
          id: 2,
          params: {
            'name': 'list_files',
            'arguments': const <String, dynamic>{},
          },
        ),
      );

      locked = true;

      final response = await pipeline.handleToolCall(
        McpRequest(
          jsonrpc: '2.0',
          method: 'tools/call',
          id: 3,
          params: {
            'name': 'list_files',
            'arguments': const <String, dynamic>{},
          },
        ),
      );
      expect(response['error']['code'], mcpErrorRateLimitExceeded);

      final denied = (await db.getMcpAuditEntries())
          .where((e) => e.resultStatus == 'denied')
          .toList();
      expect(denied, hasLength(1));
      expect(denied.single.errorMessage, contains('rate_limit'));
    });
  });
}
