import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/mcp/mcp_audit_logger.dart';
import 'package:hoodik_app/core/mcp/mcp_auditing_dispatcher.dart';
import 'package:hoodik_app/core/mcp/mcp_protocol.dart';
import 'package:hoodik_app/core/mcp/mcp_tool_handler.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/mcp_audit_dao.dart';

import 'fake_mcp_gateway.dart';

const testBearer = 'fake-token-for-tests';
const testAccountId = 'test-account';

class McpToolTestFixture {
  late AppDatabase db;
  late FakeMcpGateway gateway;
  late McpToolDispatcher handler;
  late String expectedSessionId;

  void setUpEach() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeMcpGateway();
    handler = AuditingMcpToolDispatcher(
      inner: McpToolHandler(gateway),
      logger: McpAuditLogger(db),
      bearerTokenResolver: () => testBearer,
      accountIdResolver: () => testAccountId,
    );
    expectedSessionId = McpAuditLogger.sessionIdFromBearer(testBearer);
  }

  Future<void> tearDownEach() async {
    await db.close();
  }

  Future<Map<String, dynamic>> invoke(
    String tool,
    Map<String, dynamic> args, {
    int id = 1,
  }) => invokeTool(handler, tool, args, id: id);

  Future<List<Map<String, dynamic>>> invokeList(
    String tool,
    Map<String, dynamic> args,
  ) => invokeToolList(handler, tool, args);

  Future<void> assertOneAuditEntry({
    required String toolName,
    required String status,
  }) async {
    final entries = await db.getMcpAuditEntries();
    expect(entries, hasLength(1), reason: 'Expected one audit row');
    final entry = entries.single;
    expect(entry.toolName, toolName);
    expect(entry.resultStatus, status);
    expect(entry.sessionId, expectedSessionId);
    expect(entry.accountId, testAccountId);
  }
}

/// Dispatch one `tools/call` request. Returns the parsed result payload;
/// throws with the server-side error text if the response carries `isError`,
/// so tests can use `throwsA` to verify failure paths.
Future<Map<String, dynamic>> invokeTool(
  McpToolDispatcher handler,
  String tool,
  Map<String, dynamic> args, {
  int id = 1,
}) async {
  final response = await handler.handleToolCall(
    McpRequest(
      jsonrpc: '2.0',
      method: 'tools/call',
      id: id,
      params: {'name': tool, 'arguments': args},
    ),
  );
  final result = response['result'] as Map<String, dynamic>;
  if (result['isError'] == true) {
    final content = result['content'] as List;
    throw StateError('tool error: ${content.first['text']}');
  }
  final text = (result['content'] as List).first['text'] as String;
  final decoded = jsonDecode(text);
  if (decoded is Map<String, dynamic>) return decoded;
  return {'items': decoded};
}

Future<List<Map<String, dynamic>>> invokeToolList(
  McpToolDispatcher handler,
  String tool,
  Map<String, dynamic> args,
) async {
  final response = await handler.handleToolCall(
    McpRequest(
      jsonrpc: '2.0',
      method: 'tools/call',
      id: 1,
      params: {'name': tool, 'arguments': args},
    ),
  );
  final result = response['result'] as Map<String, dynamic>;
  if (result['isError'] == true) {
    throw StateError(
      'tool error: ${(result['content'] as List).first['text']}',
    );
  }
  final text = (result['content'] as List).first['text'] as String;
  return (jsonDecode(text) as List).cast<Map<String, dynamic>>();
}
