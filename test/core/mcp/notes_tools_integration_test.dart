import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/storage/mcp_audit_dao.dart';

import 'helpers/mcp_test_helpers.dart';

void main() {
  final ctx = McpToolTestFixture();

  setUp(ctx.setUpEach);
  tearDown(ctx.tearDownEach);

  group('search', () {
    test('finds the file whose name contains the query', () async {
      await ctx.invoke('write_file', {
        'name': 'budget-2026.md',
        'content': '# budget',
      });
      await ctx.invoke('write_file', {
        'name': 'vacation.md',
        'content': '# trip',
      });
      await ctx.db.clearMcpAuditLog();

      final hits = await ctx.invokeList('search_files', {'query': 'budget'});
      expect(hits, hasLength(1));
      expect(hits.single['name'], 'budget-2026.md');

      await ctx.assertOneAuditEntry(toolName: 'search_files', status: 'ok');
    });
  });

  group('notes.read', () {
    test('returns the plain-text content of the note', () async {
      final created = await ctx.invoke('create_note', {
        'name': 'idea.md',
        'content': '# Big idea',
      });
      final id = created['file_id'] as String;
      await ctx.db.clearMcpAuditLog();

      final result = await ctx.invoke('read_note', {'file_id': id});
      expect(result['content'], '# Big idea');
      expect(result['encoding'], 'text');

      await ctx.assertOneAuditEntry(toolName: 'read_note', status: 'ok');
    });
  });

  group('notes.write', () {
    test('create_note stores the note and lists it as editable', () async {
      final created = await ctx.invoke('create_note', {
        'name': 'journal.md',
        'content': 'entry 1',
      });
      expect(created['success'], isTrue);
      expect(created['existed'], isFalse);
      expect(created['id'], isNotEmpty);
      expect(created['file_id'], created['id']);

      final notes = await ctx.invokeList('list_notes', {});
      expect(notes, hasLength(1));
      expect(notes.single['name'], 'journal.md');

      final entries = await ctx.db.getMcpAuditEntries();
      expect(entries.map((e) => e.toolName).toSet(), {
        'create_note',
        'list_notes',
      });
      expect(entries.every((e) => e.resultStatus == 'ok'), isTrue);
    });

    test('list_notes with dir_id only returns notes in that folder', () async {
      final dir = await ctx.invoke('create_directory', {'name': 'folder'});
      final dirId = dir['id'] as String;
      await ctx.invoke('create_note', {'name': 'root.md', 'content': 'root'});
      await ctx.invoke('create_note', {
        'name': 'in-folder.md',
        'content': 'nested',
        'dir_id': dirId,
      });

      final scoped = await ctx.invokeList('list_notes', {'dir_id': dirId});
      expect(scoped.map((n) => n['name']), ['in-folder.md']);

      final all = await ctx.invokeList('list_notes', {});
      expect(all.map((n) => n['name']).toSet(), {'root.md', 'in-folder.md'});
    });

    test('create_note upserts when the name already exists', () async {
      final first = await ctx.invoke('create_note', {
        'name': 'dup.md',
        'content': 'v1',
      });
      final second = await ctx.invoke('create_note', {
        'name': 'dup.md',
        'content': 'v2',
      });
      expect(second['success'], isTrue);
      expect(second['existed'], isTrue);
      expect(second['id'], first['id']);
      expect(second['file_id'], first['file_id']);
      expect(ctx.gateway.files, hasLength(1));

      final reread = await ctx.invoke('read_note', {
        'file_id': first['file_id'],
      });
      expect(reread['content'], 'v2');
    });

    test('update_note replaces the content in place', () async {
      final created = await ctx.invoke('create_note', {
        'name': 'todo.md',
        'content': 'v1',
      });
      final id = created['file_id'] as String;
      await ctx.db.clearMcpAuditLog();

      await ctx.invoke('update_note', {'file_id': id, 'content': 'v2'});
      final reread = await ctx.invoke('read_note', {'file_id': id});
      expect(reread['content'], 'v2');

      final entries = await ctx.db.getMcpAuditEntries();
      expect(entries.map((e) => e.toolName).toList(), [
        'read_note',
        'update_note',
      ]);
    });
  });

  group('storage_stats', () {
    test('returns quota and used space and audits ok', () async {
      await ctx.invoke('write_file', {
        'name': 'a.txt',
        'content': 'hello world',
      });
      await ctx.db.clearMcpAuditLog();

      final stats = await ctx.invoke('storage_stats', {});
      expect(stats['quota'], greaterThan(0));
      expect(stats['used_space'], 'hello world'.length);

      await ctx.assertOneAuditEntry(toolName: 'storage_stats', status: 'ok');
    });
  });
}
