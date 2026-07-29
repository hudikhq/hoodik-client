import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/mcp/mcp_audit_logger.dart';
import 'package:hoodik_app/core/mcp/mcp_auditing_dispatcher.dart';
import 'package:hoodik_app/core/mcp/mcp_lock_gating_dispatcher.dart';
import 'package:hoodik_app/core/mcp/mcp_protocol.dart';
import 'package:hoodik_app/core/mcp/mcp_tool_handler.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/mcp_audit_dao.dart';

import 'helpers/fake_mcp_gateway.dart';

Future<Map<String, dynamic>> _call(
  McpToolDispatcher handler,
  String tool, {
  Map<String, dynamic> args = const {},
  int id = 1,
}) {
  return handler.handleToolCall(
    McpRequest(
      jsonrpc: '2.0',
      method: 'tools/call',
      id: id,
      params: {'name': tool, 'arguments': args},
    ),
  );
}

bool _isLockedError(Map<String, dynamic> response) {
  return response['error']?['code'] == mcpErrorUserLocked;
}

void main() {
  late AppDatabase db;
  late FakeMcpGateway gateway;
  late McpToolDispatcher auditing;
  late McpAuditLogger auditLogger;

  bool locked = false;
  bool allowReadOnly = false;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeMcpGateway();
    auditLogger = McpAuditLogger(db);
    locked = false;
    allowReadOnly = false;

    auditing = AuditingMcpToolDispatcher(
      inner: McpToolHandler(gateway),
      logger: auditLogger,
      bearerTokenResolver: () => 'bearer-token',
      accountIdResolver: () => 'acct',
    );
  });

  tearDown(() async => db.close());

  LockGatingMcpToolDispatcher makeDispatcher() => LockGatingMcpToolDispatcher(
    inner: auditing,
    auditLogger: auditLogger,
    isLockedResolver: () => locked,
    allowReadOnlyWhileLockedResolver: () => allowReadOnly,
    bearerTokenResolver: () => 'bearer-token',
    accountIdResolver: () => 'acct',
  );

  test('read-only tool classification covers list/search/storage tools', () {
    expect(isReadOnlyMcpTool('list_files'), isTrue);
    expect(isReadOnlyMcpTool('list_notes'), isTrue);
    expect(isReadOnlyMcpTool('search_files'), isTrue);
    expect(isReadOnlyMcpTool('storage_stats'), isTrue);

    expect(isReadOnlyMcpTool('read_file'), isFalse);
    expect(isReadOnlyMcpTool('read_note'), isFalse);
    expect(isReadOnlyMcpTool('write_file'), isFalse);
    expect(isReadOnlyMcpTool('rename_file'), isFalse);
    expect(isReadOnlyMcpTool('delete_file'), isFalse);
    expect(isReadOnlyMcpTool('move_files'), isFalse);
    expect(isReadOnlyMcpTool('create_directory'), isFalse);
    expect(isReadOnlyMcpTool('create_note'), isFalse);
    expect(isReadOnlyMcpTool('update_note'), isFalse);
  });

  test('unlocked + any tool = call forwarded, no denial audit row', () async {
    locked = false;
    await gateway.createFolder('docs');

    final response = await _call(makeDispatcher(), 'list_files');
    expect(_isLockedError(response), isFalse);

    final entries = await db.getMcpAuditEntries();
    expect(entries.where((e) => e.resultStatus == 'denied'), isEmpty);
  });

  test('locked + crypto tool = denied with locked error code', () async {
    locked = true;

    final response = await _call(
      makeDispatcher(),
      'read_file',
      args: {'file_id': 'irrelevant'},
    );

    expect(response['error']['code'], mcpErrorUserLocked);
    expect(response['error']['message'], contains('user locked'));

    final entries = await db.getMcpAuditEntries();
    expect(entries, hasLength(1));
    expect(entries.single.resultStatus, 'denied');
    expect(entries.single.toolName, 'read_file');
    // The inner gateway must never have been touched.
    expect(gateway.files, isEmpty);
  });

  test('locked + read-only tool + policy off = denied', () async {
    locked = true;
    allowReadOnly = false;

    final response = await _call(makeDispatcher(), 'list_files');
    expect(_isLockedError(response), isTrue);

    final entries = await db.getMcpAuditEntries();
    expect(entries, hasLength(1));
    expect(entries.single.resultStatus, 'denied');
    expect(entries.single.toolName, 'list_files');
  });

  test('locked + read-only tool + policy on = allowed', () async {
    locked = true;
    allowReadOnly = true;

    await gateway.createFolder('docs');

    final response = await _call(makeDispatcher(), 'list_files');
    expect(_isLockedError(response), isFalse);
    // list_files flowing through the audit decorator writes exactly one "ok" row.
    final entries = await db.getMcpAuditEntries();
    expect(entries.where((e) => e.resultStatus == 'ok'), hasLength(1));
    expect(entries.where((e) => e.resultStatus == 'denied'), isEmpty);
  });

  test('locked + crypto tool + policy on = still denied', () async {
    locked = true;
    allowReadOnly = true;

    final response = await _call(
      makeDispatcher(),
      'write_file',
      args: {'name': 'x.txt', 'content': 'y'},
    );
    expect(_isLockedError(response), isTrue);
    expect(response['error']['message'], contains('read-only'));

    // Gateway must remain untouched — write_file never reached it.
    expect(gateway.files, isEmpty);
  });

  test('unlocking mid-session lets the next call through', () async {
    locked = true;
    final dispatcher = makeDispatcher();

    final denied = await _call(
      dispatcher,
      'create_directory',
      args: {'name': 'nope'},
    );
    expect(_isLockedError(denied), isTrue);

    locked = false;
    final ok = await _call(
      dispatcher,
      'create_directory',
      args: {'name': 'yes'},
      id: 2,
    );
    expect(_isLockedError(ok), isFalse);

    final entries = await db.getMcpAuditEntries();
    // Denials entry is written by lock gating; the "ok" audit row is written
    // by the auditing decorator below it — two total rows, one denied, one ok.
    expect(entries.where((e) => e.resultStatus == 'denied'), hasLength(1));
    expect(entries.where((e) => e.resultStatus == 'ok'), hasLength(1));
  });

  test(
    'denied audit row stores params hash, not plaintext arguments',
    () async {
      locked = true;

      await _call(
        makeDispatcher(),
        'write_file',
        args: {'name': 'secret-filename.md', 'content': 'secret content'},
      );

      final entry = (await db.getMcpAuditEntries()).single;
      expect(entry.resultStatus, 'denied');
      expect(entry.paramsHash.length, 64);
      // Raw plaintext must never appear in any stored column.
      expect(entry.paramsHash, isNot(contains('secret-filename')));
      expect(entry.errorMessage ?? '', isNot(contains('secret-filename')));
      expect(entry.errorMessage ?? '', isNot(contains('secret content')));
    },
  );
}
