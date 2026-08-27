import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/file_item.dart';
import 'package:hoodik_app/core/mcp/find_in_note.dart';
import 'package:hoodik_app/core/mcp/mcp_audit_logger.dart';
import 'package:hoodik_app/core/mcp/mcp_lock_gating_dispatcher.dart';
import 'package:hoodik_app/core/mcp/mcp_protocol.dart';
import 'package:hoodik_app/core/mcp/mcp_tool_handler.dart';
import 'package:hoodik_app/core/storage/database.dart';

import 'helpers/fake_mcp_gateway.dart';
import 'helpers/mcp_test_helpers.dart';

void main() {
  group('findInNotePlaintext', () {
    test('returns multiple matches with 1-based lines and 0-based offsets', () {
      const body =
          'alpha abrakadabra\n'
          'beta\n'
          'gamma abrakadabra delta abrakadabra\n'
          'ABRAKADABRA';

      final scan = findInNotePlaintext(plaintext: body, query: 'abrakadabra');

      expect(scan.matchCount, 4);
      expect(scan.truncated, isFalse);
      expect(scan.matches.map((m) => m.index).toList(), [0, 1, 2, 3]);
      expect(scan.matches[0].line, 1);
      expect(scan.matches[0].offset, body.indexOf('abrakadabra'));
      expect(scan.matches[1].line, 3);
      expect(scan.matches[2].line, 3);
      expect(scan.matches[3].line, 4);
      expect(scan.matches[3].offset, body.lastIndexOf('ABRAKADABRA'));
      for (final m in scan.matches) {
        expect(m.excerpt.toLowerCase(), contains('abrakadabra'));
      }
    });

    test('is case-insensitive by default and respects case_sensitive', () {
      const body = 'The Magic word is Abrakadabra.';
      final insensitive = findInNotePlaintext(
        plaintext: body,
        query: 'ABRAKADABRA',
      );
      expect(insensitive.matchCount, 1);
      expect(insensitive.matches.single.excerpt, contains('Abrakadabra'));

      final sensitive = findInNotePlaintext(
        plaintext: body,
        query: 'ABRAKADABRA',
        caseSensitive: true,
      );
      expect(sensitive.matchCount, 0);

      final exact = findInNotePlaintext(
        plaintext: body,
        query: 'Abrakadabra',
        caseSensitive: true,
      );
      expect(exact.matchCount, 1);
    });

    test('empty query throws', () {
      expect(
        () => findInNotePlaintext(plaintext: 'hello', query: ''),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('query must not be empty'),
          ),
        ),
      );
    });

    test('max_matches truncates and sets truncated', () {
      const body = 'one two one two one two one';
      final scan = findInNotePlaintext(
        plaintext: body,
        query: 'one',
        maxMatches: 2,
      );
      expect(scan.matchCount, 2);
      expect(scan.truncated, isTrue);
      expect(scan.matches, hasLength(2));

      final capped = findInNotePlaintext(
        plaintext: List.filled(80, 'hit').join(' '),
        query: 'hit',
        maxMatches: 100,
      );
      expect(capped.matchCount, kFindInNoteMaxMatchesCap);
      expect(capped.truncated, isTrue);
    });
  });

  group('find_in_note tool', () {
    final ctx = McpToolTestFixture();

    setUp(ctx.setUpEach);
    tearDown(ctx.tearDownEach);

    test('returns excerpts from a note body, not the full dump', () async {
      const marker = 'abrakadabra';
      final unique = 'Q' * 400;
      final body =
          'intro $unique\n'
          'the spell is $marker in the middle of this line\n'
          'outro $unique again and $marker once more';

      final created = await ctx.invoke('create_note', {
        'name': 'spell.md',
        'content': body,
      });
      final id = created['file_id'] as String;

      final result = await ctx.invoke('find_in_note', {
        'file_id': id,
        'query': marker,
        'context': 20,
      });

      expect(result['file_id'], id);
      expect(result['name'], 'spell.md');
      expect(result['query'], marker);
      expect(result['match_count'], 2);
      expect(result['truncated'], isFalse);
      expect(result.containsKey('content'), isFalse);

      final matches = (result['matches'] as List).cast<Map<String, dynamic>>();
      expect(matches, hasLength(2));
      expect(matches[0]['index'], 0);
      expect(matches[0]['line'], 2);
      expect(matches[0]['offset'], body.indexOf(marker));
      expect(matches[0]['excerpt'], contains(marker));
      expect(matches[1]['index'], 1);
      expect(matches[1]['line'], 3);

      final encoded = result.toString();
      expect(encoded, isNot(contains(unique)));
      expect(encoded, isNot(contains(body)));
      for (final m in matches) {
        final excerpt = m['excerpt'] as String;
        expect(excerpt.length, lessThan(body.length));
        expect(excerpt, isNot(equals(body)));
      }
    });

    test('empty query is an MCP tool error, not a 500', () async {
      final created = await ctx.invoke('create_note', {
        'name': 'n.md',
        'content': 'hello',
      });
      final response = await ctx.handler.handleToolCall(
        McpRequest(
          jsonrpc: '2.0',
          method: 'tools/call',
          id: 9,
          params: {
            'name': 'find_in_note',
            'arguments': {'file_id': created['file_id'], 'query': ''},
          },
        ),
      );
      expect(response['error'], isNull);
      expect(response['result']['isError'], isTrue);
      expect(
        response['result']['content'][0]['text'],
        contains('query must not be empty'),
      );
    });

    test('max_matches truncation surfaces truncated true', () async {
      final created = await ctx.invoke('create_note', {
        'name': 'hits.md',
        'content': 'hit hit hit hit hit',
      });
      final result = await ctx.invoke('find_in_note', {
        'file_id': created['file_id'],
        'query': 'hit',
        'max_matches': 2,
      });
      expect(result['match_count'], 2);
      expect(result['truncated'], isTrue);
      expect(result['matches'], hasLength(2));
    });

    test('not a note / not found / cannot decrypt are MCP errors', () async {
      await ctx.invoke('write_file', {
        'name': 'photo.png',
        'content': 'not-a-note',
        'encoding': 'text',
      });
      final binaryId = ctx.gateway.files.keys.single;

      Future<Map<String, dynamic>> call(Map<String, dynamic> args) {
        return ctx.handler.handleToolCall(
          McpRequest(
            jsonrpc: '2.0',
            method: 'tools/call',
            id: 1,
            params: {'name': 'find_in_note', 'arguments': args},
          ),
        );
      }

      final notNote = await call({'file_id': binaryId, 'query': 'not'});
      expect(notNote['error'], isNull);
      expect(notNote['result']['isError'], isTrue);
      expect(notNote['result']['content'][0]['text'], contains('Not a note'));

      final missing = await call({'file_id': 'no-such-id', 'query': 'x'});
      expect(missing['error'], isNull);
      expect(missing['result']['isError'], isTrue);
      expect(
        (missing['result']['content'][0]['text'] as String).toLowerCase(),
        contains('not found'),
      );

      final created = await ctx.invoke('create_note', {
        'name': 'locked.md',
        'content': 'secret abrakadabra',
      });
      final noteId = created['file_id'] as String;
      final current = ctx.gateway.files[noteId]!;
      ctx.gateway.files[noteId] = FileItem(
        id: current.id,
        fileId: current.fileId,
        encryptedName: current.encryptedName,
        encryptedKey: null,
        mime: current.mime,
        size: current.size,
        editable: true,
        createdAt: current.createdAt,
        finishedUploadAt: current.finishedUploadAt,
      );

      final lockedKey = await call({'file_id': noteId, 'query': 'secret'});
      expect(lockedKey['error'], isNull);
      expect(lockedKey['result']['isError'], isTrue);
      expect(
        (lockedKey['result']['content'][0]['text'] as String).toLowerCase(),
        contains('decrypt'),
      );
    });
  });

  group('find_in_note lock gating', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async => db.close());

    test(
      'locked app denies find_in_note even with read-only policy on',
      () async {
        final gateway = FakeMcpGateway();
        await gateway.createNote('spell.md', 'abrakadabra');
        final dispatcher = LockGatingMcpToolDispatcher(
          inner: McpToolHandler(gateway),
          auditLogger: McpAuditLogger(db),
          isLockedResolver: () => true,
          allowReadOnlyWhileLockedResolver: () => true,
          bearerTokenResolver: () => 'bearer',
          accountIdResolver: () => 'acct',
        );

        final response = await dispatcher.handleToolCall(
          McpRequest(
            jsonrpc: '2.0',
            method: 'tools/call',
            id: 1,
            params: {
              'name': 'find_in_note',
              'arguments': {
                'file_id': gateway.files.keys.single,
                'query': 'abrakadabra',
              },
            },
          ),
        );

        expect(response['error']['code'], mcpErrorUserLocked);
        expect(isReadOnlyMcpTool('find_in_note'), isFalse);
        expect(gateway.bodies, isNotEmpty);
      },
    );
  });
}
