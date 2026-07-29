import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/storage/mcp_audit_dao.dart';

import 'helpers/mcp_test_helpers.dart';

void main() {
  final ctx = McpToolTestFixture();

  setUp(ctx.setUpEach);
  tearDown(ctx.tearDownEach);

  group('files.list', () {
    test('returns decrypted names of children and audits as ok', () async {
      await ctx.gateway.createFolder('docs');

      final items = await ctx.invokeList('list_files', {});
      expect(items, hasLength(1));
      expect(items.single['name'], 'docs');
      expect(items.single['is_dir'], isTrue);
      expect(ctx.gateway.ensuredFreshSession, isTrue);

      await ctx.assertOneAuditEntry(toolName: 'list_files', status: 'ok');
    });
  });

  group('files.read', () {
    test('returns the bytes written by write_file and audits ok', () async {
      await ctx.invoke('write_file', {
        'name': 'hello.txt',
        'content': 'hi there',
      });
      await ctx.db.clearMcpAuditLog();

      final uploaded = ctx.gateway.files.values.single;
      final result = await ctx.invoke('read_file', {'file_id': uploaded.id});
      expect(result['content'], 'hi there');
      expect(result['encoding'], 'text');
      expect(result['mime'], 'text/plain');

      await ctx.assertOneAuditEntry(toolName: 'read_file', status: 'ok');
    });
  });

  group('files.write', () {
    test('uploads a new file and audits ok', () async {
      final before = ctx.gateway.files.length;

      final result = await ctx.invoke('write_file', {
        'name': 'note.json',
        'content': '{"a":1}',
      });
      expect(result['success'], isTrue);
      expect(ctx.gateway.files.length, before + 1);
      expect(ctx.gateway.plaintextNames.values, contains('note.json'));

      await ctx.assertOneAuditEntry(toolName: 'write_file', status: 'ok');
    });
  });

  group('files.delete', () {
    test('removes the file and a follow-up read raises', () async {
      await ctx.invoke('write_file', {'name': 'a.txt', 'content': 'x'});
      final id = ctx.gateway.files.keys.single;
      await ctx.db.clearMcpAuditLog();

      final result = await ctx.invoke('delete_file', {'file_id': id});
      expect(result['success'], isTrue);
      expect(ctx.gateway.files[id], isNull);

      await expectLater(
        () => ctx.invoke('read_file', {'file_id': id}),
        throwsA(isA<StateError>()),
      );

      // Entries come back newest-first, so read_file (second call) sits
      // above delete_file (first call) in the log.
      final entries = await ctx.db.getMcpAuditEntries();
      expect(entries.map((e) => e.toolName).toList(), [
        'read_file',
        'delete_file',
      ]);
      expect(entries.first.resultStatus, 'error');
      expect(entries.last.resultStatus, 'ok');
    });
  });

  group('files.rename', () {
    test('updates the plaintext name of the file and audits ok', () async {
      await ctx.invoke('write_file', {
        'name': 'draft.md',
        'content': '# draft',
      });
      final id = ctx.gateway.files.keys.single;
      await ctx.db.clearMcpAuditLog();

      final result = await ctx.invoke('rename_file', {
        'file_id': id,
        'new_name': 'final.md',
      });
      expect(result['new_name'], 'final.md');
      expect(ctx.gateway.plaintextNames[id], 'final.md');

      await ctx.assertOneAuditEntry(toolName: 'rename_file', status: 'ok');
    });
  });

  group('files.move', () {
    test('reparents the moved files under the target dir', () async {
      await ctx.gateway.createFolder('target');
      final targetId = ctx.gateway.files.keys.last;

      await ctx.invoke('write_file', {'name': 'movable.txt', 'content': 'hi'});
      final fileId = ctx.gateway.files.values.firstWhere((f) => !f.isDir).id;

      await ctx.db.clearMcpAuditLog();

      final result = await ctx.invoke('move_files', {
        'file_ids': [fileId],
        'target_dir_id': targetId,
      });
      expect(result['moved'], 1);
      expect(ctx.gateway.files[fileId]!.fileId, targetId);

      await ctx.assertOneAuditEntry(toolName: 'move_files', status: 'ok');
    });
  });

  group('folders.create', () {
    test('adds a new directory entry and audits ok', () async {
      final result = await ctx.invoke('create_directory', {'name': 'projects'});
      expect(result['success'], isTrue);
      final created = ctx.gateway.files.values.single;
      expect(created.isDir, isTrue);
      expect(ctx.gateway.plaintextNames[created.id], 'projects');

      await ctx.assertOneAuditEntry(toolName: 'create_directory', status: 'ok');
    });
  });

  group('folders.delete', () {
    test('removes a directory and the entry disappears from list', () async {
      await ctx.invoke('create_directory', {'name': 'scratch'});
      final id = ctx.gateway.files.keys.single;
      await ctx.db.clearMcpAuditLog();

      await ctx.invoke('delete_file', {'file_id': id});
      expect(ctx.gateway.files, isEmpty);

      final items = await ctx.invokeList('list_files', {});
      expect(items, isEmpty);

      final entries = await ctx.db.getMcpAuditEntries();
      expect(entries.map((e) => e.toolName).toList(), [
        'list_files',
        'delete_file',
      ]);
    });
  });
}
