import 'package:flutter_test/flutter_test.dart';

import 'helpers/mcp_test_helpers.dart';

void main() {
  final ctx = McpToolTestFixture();

  setUp(ctx.setUpEach);
  tearDown(ctx.tearDownEach);

  Future<({String workId, String thelabId, String fileId})> seedTree() async {
    final work = await ctx.invoke('create_directory', {'name': 'Work'});
    final workId = work['id'] as String;
    final thelab = await ctx.invoke('create_directory', {
      'name': 'thelab',
      'dir_id': workId,
    });
    final thelabId = thelab['id'] as String;
    final file = await ctx.invoke('create_note', {
      'name': 'file.md',
      'content': 'hello',
      'dir_id': thelabId,
    });
    return (workId: workId, thelabId: thelabId, fileId: file['id'] as String);
  }

  test('/Work/thelab/file.md returns 3 segments with ids', () async {
    final ids = await seedTree();

    final result = await ctx.invoke('resolve_path', {
      'path': '/Work/thelab/file.md',
    });

    expect(result['path'], 'Work/thelab/file.md');
    expect(result['resolved'], isTrue);
    final segments = (result['segments'] as List).cast<Map<String, dynamic>>();
    expect(segments, hasLength(3));

    expect(segments[0]['name'], 'Work');
    expect(segments[0]['id'], ids.workId);
    expect(segments[0]['is_dir'], isTrue);
    expect(segments[0]['exists'], isTrue);

    expect(segments[1]['name'], 'thelab');
    expect(segments[1]['id'], ids.thelabId);
    expect(segments[1]['is_dir'], isTrue);
    expect(segments[1]['exists'], isTrue);

    expect(segments[2]['name'], 'file.md');
    expect(segments[2]['id'], ids.fileId);
    expect(segments[2]['is_dir'], isFalse);
    expect(segments[2]['exists'], isTrue);
    expect(segments[2]['editable'], isTrue);
  });

  test(
    'missing middle folder: first exists, rest exists:false, resolved:false',
    () async {
      await ctx.invoke('create_directory', {'name': 'Work'});

      final result = await ctx.invoke('resolve_path', {
        'path': '/Work/missing/file.md',
      });

      expect(result['resolved'], isFalse);
      final segments = (result['segments'] as List)
          .cast<Map<String, dynamic>>();
      expect(segments, hasLength(3));

      expect(segments[0]['name'], 'Work');
      expect(segments[0]['exists'], isTrue);
      expect(segments[0]['id'], isNotEmpty);
      expect(segments[0]['is_dir'], isTrue);

      expect(segments[1]['name'], 'missing');
      expect(segments[1]['exists'], isFalse);
      expect(segments[1].containsKey('id'), isFalse);

      expect(segments[2]['name'], 'file.md');
      expect(segments[2]['exists'], isFalse);
      expect(segments[2].containsKey('id'), isFalse);
    },
  );

  test('empty or omitted dir_id starts at vault root', () async {
    final ids = await seedTree();

    final omitted = await ctx.invoke('resolve_path', {
      'path': 'Work/thelab/file.md',
    });
    expect(omitted['resolved'], isTrue);
    final omittedSegs = (omitted['segments'] as List)
        .cast<Map<String, dynamic>>();
    expect(omittedSegs.map((s) => s['id']).toList(), [
      ids.workId,
      ids.thelabId,
      ids.fileId,
    ]);

    final empty = await ctx.invoke('resolve_path', {
      'path': 'Work/thelab/file.md',
      'dir_id': '',
    });
    expect(empty['resolved'], isTrue);
    final emptySegs = (empty['segments'] as List).cast<Map<String, dynamic>>();
    expect(emptySegs.map((s) => s['id']).toList(), [
      ids.workId,
      ids.thelabId,
      ids.fileId,
    ]);
  });

  test('leading slash is ignored', () async {
    final ids = await seedTree();

    final withSlash = await ctx.invoke('resolve_path', {
      'path': '/Work/thelab/file.md',
    });
    final withoutSlash = await ctx.invoke('resolve_path', {
      'path': 'Work/thelab/file.md',
    });

    expect(withSlash['path'], 'Work/thelab/file.md');
    expect(withoutSlash['path'], 'Work/thelab/file.md');
    expect(withSlash['resolved'], isTrue);
    expect(withoutSlash['resolved'], isTrue);

    final withSegs = (withSlash['segments'] as List)
        .cast<Map<String, dynamic>>();
    final withoutSegs = (withoutSlash['segments'] as List)
        .cast<Map<String, dynamic>>();
    expect(withSegs.map((s) => s['id']).toList(), [
      ids.workId,
      ids.thelabId,
      ids.fileId,
    ]);
    expect(
      withoutSegs.map((s) => s['id']).toList(),
      withSegs.map((s) => s['id']).toList(),
    );
  });
}
