import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/utils/log_file_sink.dart';
import 'package:hoodik_app/core/utils/logger.dart';
import 'package:path/path.dart' as p;

/// Minimal [LogRecord] factory so individual tests don't repeat boilerplate.
LogRecord _record({
  required DateTime ts,
  Level level = Level.info,
  String component = 'TestComponent',
  String message = 'hello',
  Map<String, Object?> fields = const {},
}) {
  return LogRecord(
    timestamp: ts,
    level: level,
    component: component,
    message: message,
    fields: fields,
  );
}

void main() {
  late Directory tmpDir;
  late LogFileSink sink;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('hoodik_log_test_');
    sink = await LogFileSink.open(directoryOverride: tmpDir);
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('writes one JSON line per record to a dated file', () async {
    sink.record(_record(ts: DateTime(2026, 4, 22, 10)));

    final file = File(p.join(tmpDir.path, 'hoodik-2026-04-22.jsonl'));
    expect(await file.exists(), isTrue);

    final lines = await file.readAsLines();
    expect(lines, hasLength(1));

    final parsed = jsonDecode(lines.single) as Map<String, dynamic>;
    expect(parsed['component'], 'TestComponent');
    expect(parsed['message'], 'hello');
  });

  test('appends consecutive records to the same file', () async {
    for (var i = 0; i < 5; i++) {
      sink.record(
        _record(ts: DateTime(2026, 4, 22, 10, i), message: 'line $i'),
      );
    }

    final file = File(p.join(tmpDir.path, 'hoodik-2026-04-22.jsonl'));
    final lines = await file.readAsLines();
    expect(lines, hasLength(5));
    expect(lines.first, contains('"message":"line 0"'));
    expect(lines.last, contains('"message":"line 4"'));
  });

  test('rotates to a new file when the date changes', () async {
    sink.record(_record(ts: DateTime(2026, 4, 22, 23, 59)));
    sink.record(_record(ts: DateTime(2026, 4, 23, 0, 1)));

    final april22 = File(p.join(tmpDir.path, 'hoodik-2026-04-22.jsonl'));
    final april23 = File(p.join(tmpDir.path, 'hoodik-2026-04-23.jsonl'));
    expect(await april22.readAsLines(), hasLength(1));
    expect(await april23.readAsLines(), hasLength(1));
  });

  test(
    'pruneOlderThan deletes files older than retention and keeps newer',
    () async {
      final today = DateTime.now();
      final fresh = today;
      final ancient = today.subtract(const Duration(days: 30));

      sink.record(_record(ts: fresh));
      sink.record(_record(ts: ancient));

      await sink.pruneOlderThan(const Duration(days: 3));

      final remaining = await tmpDir
          .list()
          .where((e) => e is File)
          .map((e) => p.basename(e.path))
          .toList();

      expect(remaining, hasLength(1));
      expect(remaining.single, contains(_ymd(fresh)));
    },
  );

  test('readAllLines concatenates lines across dated files in order', () async {
    sink.record(_record(ts: DateTime(2026, 4, 20), message: 'old'));
    sink.record(_record(ts: DateTime(2026, 4, 22), message: 'new'));

    final lines = await sink.readAllLines();
    expect(lines, hasLength(2));
    expect(lines.first, contains('"message":"old"'));
    expect(lines.last, contains('"message":"new"'));
  });

  test('readLinesSince filters by timestamp cutoff', () async {
    sink.record(_record(ts: DateTime(2026, 4, 22, 9), message: 'before'));
    sink.record(_record(ts: DateTime(2026, 4, 22, 11), message: 'after'));

    final lines = await sink.readLinesSince(DateTime(2026, 4, 22, 10));
    expect(lines, hasLength(1));
    expect(lines.single, contains('"message":"after"'));
  });

  test(
    'record does not throw even when the target directory is missing',
    () async {
      // Delete the directory underneath the sink and verify the call is silent.
      await tmpDir.delete(recursive: true);
      expect(() => sink.record(_record(ts: DateTime.now())), returnsNormally);
    },
  );
}

String _ymd(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
