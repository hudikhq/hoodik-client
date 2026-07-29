import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/log_export_service.dart';
import 'package:hoodik_app/core/utils/app_session.dart';
import 'package:hoodik_app/core/utils/log_file_sink.dart';
import 'package:hoodik_app/core/utils/logger.dart';
import 'package:path/path.dart' as p;

LogRecord _record(
  DateTime ts, {
  Level level = Level.info,
  String component = 'TestComp',
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
  group('formatLine', () {
    test('renders a minimal record on one human-readable line', () {
      final json = jsonEncode({
        'ts': '2026-04-22T15:30:45.123Z',
        'level': 'info',
        'component': 'SyncService',
        'message': 'upload complete',
      });
      final formatted = LogExportService.formatLine(json);
      expect(formatted, contains('[2026-04-22T15:30:45.123Z]'));
      expect(formatted, contains('[INFO '));
      expect(formatted, contains('SyncService: upload complete'));
    });

    test('includes the account prefix when present', () {
      final json = jsonEncode({
        'ts': '2026-04-22T15:30:45Z',
        'level': 'warn',
        'component': 'ApiClient',
        'message': 'request error',
        'account': 'owner@example.test / files.example.test',
      });
      final formatted = LogExportService.formatLine(json);
      expect(formatted, contains('[owner@example.test / files.example.test]'));
    });

    test('appends extra fields in k=v form', () {
      final json = jsonEncode({
        'ts': '2026-04-22T15:30:45Z',
        'level': 'info',
        'component': 'X',
        'message': 'done',
        'count': 42,
        'duration_ms': 500,
      });
      final formatted = LogExportService.formatLine(json);
      expect(formatted, contains('(count=42, duration_ms=500)'));
    });

    test('passes invalid JSON through unchanged', () {
      const garbage = '[not valid json';
      expect(LogExportService.formatLine(garbage), garbage);
    });
  });

  group('loadLines', () {
    late Directory tmpDir;
    late LogFileSink sink;
    late LogExportService service;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('hoodik_export_');
      sink = await LogFileSink.open(directoryOverride: tmpDir);
      service = LogExportService(sinkOverride: sink);
      AppSession.resetForTests();
    });

    tearDown(() async {
      AppSession.resetForTests();
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    });

    test(
      'currentSessionOnly filters to records at or after session start',
      () async {
        AppSession.setForTests(DateTime(2026, 4, 22, 10));
        sink.record(_record(DateTime(2026, 4, 22, 9), message: 'before'));
        sink.record(_record(DateTime(2026, 4, 22, 11), message: 'after'));

        final lines = await service.loadLines(currentSessionOnly: true);
        expect(lines, hasLength(1));
        expect(lines.single, contains('after'));
      },
    );

    test('currentSessionOnly=false returns every retained line', () async {
      AppSession.setForTests(DateTime(2026, 4, 22, 10));
      sink.record(_record(DateTime(2026, 4, 22, 9), message: 'before'));
      sink.record(_record(DateTime(2026, 4, 22, 11), message: 'after'));

      final lines = await service.loadLines(currentSessionOnly: false);
      expect(lines, hasLength(2));
    });
  });

  group('writeExportFile', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hoodik_export_out_');
    });
    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('writes header + lines to a temp file', () async {
      final now = DateTime(2026, 4, 22, 15, 30);
      final service = LogExportService(
        tempDirOverride: tempDir,
        nowOverride: () => now,
      );

      final file = await service.writeExportFile([
        '[2026-04-22] [INFO ] TestComp: hello',
        '[2026-04-22] [WARN ] TestComp: something went wrong',
      ]);

      expect(await file.exists(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('Hoodik bug report'));
      expect(content, contains('Generated: 2026-04-22T15:30:00.000'));
      expect(content, contains('----- logs -----'));
      expect(content, contains('[INFO ] TestComp: hello'));
      expect(content, contains('[WARN ] TestComp: something went wrong'));

      // Filename should encode the timestamp for easy identification.
      expect(p.basename(file.path), startsWith('hoodik-logs-'));
      expect(p.basename(file.path), endsWith('.txt'));
    });
  });

  group('clipboardContent', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hoodik_clipboard_');
    });
    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('matches the export file content byte-for-byte', () async {
      final now = DateTime(2026, 4, 22, 15, 30);
      final service = LogExportService(
        tempDirOverride: tempDir,
        nowOverride: () => now,
      );
      final lines = ['line A', 'line B'];

      final file = await service.writeExportFile(lines);
      expect(service.clipboardContent(lines), await file.readAsString());
    });
  });
}
