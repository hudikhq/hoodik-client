import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'logger.dart';

/// Append-only file sink that writes one JSON-encoded [LogRecord] per line
/// into a daily-rotated file under `<ApplicationSupport>/logs/`.
///
/// The on-disk format is deliberately machine-readable (JSONL) — the
/// redactor UI renders each line into a human-friendly form at display
/// time, so we keep enough structure to filter by session and render per
/// account without re-parsing free-form text.
class LogFileSink {
  LogFileSink._(this.directory);

  /// Directory containing every `hoodik-YYYY-MM-DD.jsonl` file.
  final Directory directory;

  File? _currentFile;
  String? _currentDate;

  static const String _fileStem = 'hoodik-';
  static const String _fileExt = '.jsonl';
  static final RegExp _filenamePattern = RegExp(
    r'^hoodik-(\d{4})-(\d{2})-(\d{2})\.jsonl$',
  );

  /// Open (or create) the log directory. Pass [directoryOverride] from
  /// tests to avoid pulling in path_provider and to isolate each test's
  /// files in a tmp dir.
  static Future<LogFileSink> open({Directory? directoryOverride}) async {
    final dir = directoryOverride ?? await _defaultDirectory();
    await dir.create(recursive: true);
    return LogFileSink._(dir);
  }

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'logs'));
  }

  /// [LogSink] entry point — wire this into `configureLogging(sinks: [...])`.
  ///
  /// Writes are best-effort: a disk-full or permission error is swallowed
  /// silently so a logging failure never takes down the app.
  void record(LogRecord r) {
    try {
      final file = _fileForDate(r.timestamp);
      file.writeAsStringSync(
        '${jsonEncode(r.toJson())}\n',
        mode: FileMode.append,
        flush: false,
      );
    } catch (_) {
      // Observational — never propagate.
    }
  }

  File _fileForDate(DateTime ts) {
    final date = _ymd(ts);
    if (_currentFile == null || _currentDate != date) {
      _currentDate = date;
      _currentFile = File(p.join(directory.path, '$_fileStem$date$_fileExt'));
    }
    return _currentFile!;
  }

  /// Delete every log file whose date stamp is older than [retention] days
  /// ago (relative to local midnight).
  Future<void> pruneOlderThan(Duration retention) async {
    try {
      if (!await directory.exists()) return;
      final now = DateTime.now();
      final cutoff = DateTime(now.year, now.month, now.day).subtract(retention);
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final date = _dateFromFilename(p.basename(entity.path));
        if (date == null) continue;
        if (date.isBefore(cutoff)) {
          try {
            await entity.delete();
          } catch (_) {
            // Best-effort.
          }
        }
      }
    } catch (_) {
      // Best-effort.
    }
  }

  /// Return every retained log line across every retained file in
  /// chronological order. Each line is one JSON-encoded [LogRecord].
  Future<List<String>> readAllLines() async {
    final files = await _filesSortedByDate();
    final lines = <String>[];
    for (final file in files) {
      try {
        lines.addAll(await file.readAsLines());
      } catch (_) {
        // Skip unreadable files.
      }
    }
    return lines;
  }

  /// Return every retained log line whose `ts` is at or after [since].
  /// Used by the export flow to restrict a bug report to the current
  /// session by default.
  Future<List<String>> readLinesSince(DateTime since) async {
    final all = await readAllLines();
    return all.where((line) {
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;
        final ts = DateTime.parse(obj['ts'] as String);
        return !ts.isBefore(since);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  Future<List<File>> _filesSortedByDate() async {
    if (!await directory.exists()) return const [];
    final files = <File>[];
    await for (final e in directory.list()) {
      if (e is File && _dateFromFilename(p.basename(e.path)) != null) {
        files.add(e);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  static String _ymd(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static DateTime? _dateFromFilename(String name) {
    final match = _filenamePattern.firstMatch(name);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }
}
