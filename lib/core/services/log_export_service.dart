import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/app_session.dart';
import '../utils/l10n_lookup.dart';
import '../utils/log_file_sink.dart';

/// Coordinates the bug-report export flow:
///   1. read rolling log lines off disk,
///   2. render them into a human-readable form for the redactor UI,
///   3. write the user-approved subset to a temp file,
///   4. hand that file to the native share sheet pre-filled with
///      `security@hoodik.io`.
///
/// Keeping all of this in a service (rather than inline in the screens)
/// means the UI can stay thin and the logic is easy to unit-test.
class LogExportService {
  LogExportService({
    LogFileSink? sinkOverride,
    Directory? tempDirOverride,
    DateTime Function()? nowOverride,
  }) : _sinkOverride = sinkOverride,
       _tempDirOverride = tempDirOverride,
       _now = nowOverride ?? DateTime.now;

  final LogFileSink? _sinkOverride;
  final Directory? _tempDirOverride;
  final DateTime Function() _now;

  /// Destination address the user sees pre-filled in their mail client.
  static const String supportEmail = 'security@hoodik.io';

  /// Load log lines, either from the current app session only or from
  /// every retained file (past 3 days).
  ///
  /// Each returned entry is already formatted in the human-readable form
  /// the redactor renders.
  Future<List<String>> loadLines({required bool currentSessionOnly}) async {
    final sink = _sinkOverride ?? await LogFileSink.open();
    final raw = currentSessionOnly
        ? await sink.readLinesSince(AppSession.startedAt)
        : await sink.readAllLines();
    return raw.map(formatLine).toList();
  }

  /// Render one JSON-encoded [LogRecord] as a single human-readable line.
  ///
  /// Invalid lines (parse errors, missing fields) fall through as-is so the
  /// user can see them and decide what to do — better to surface garbage
  /// than to hide it during an export.
  ///
  /// Format:
  ///   `[ts] [LEVEL] [account / host] Component: message (k=v, k=v)`
  static String formatLine(String jsonLine) {
    final Map<String, dynamic> record;
    try {
      record = jsonDecode(jsonLine) as Map<String, dynamic>;
    } catch (_) {
      return jsonLine;
    }

    final ts = (record['ts'] as String?) ?? '';
    final level =
        (record['level'] as String?)?.toUpperCase().padRight(5) ?? '?';
    final component = (record['component'] as String?) ?? 'unknown';
    final message = (record['message'] as String?) ?? '';

    final buffer = StringBuffer()
      ..write('[')
      ..write(ts)
      ..write('] [')
      ..write(level)
      ..write('] ');

    final account = record['account'];
    if (account is String && account.isNotEmpty) {
      buffer
        ..write('[')
        ..write(account)
        ..write('] ');
    }

    buffer
      ..write(component)
      ..write(': ')
      ..write(message);

    final extras = <String>[];
    for (final entry in record.entries) {
      if (_baseKeys.contains(entry.key)) continue;
      extras.add('${entry.key}=${entry.value}');
    }
    if (extras.isNotEmpty) {
      buffer
        ..write(' (')
        ..writeAll(extras, ', ')
        ..write(')');
    }
    return buffer.toString();
  }

  static const _baseKeys = {'ts', 'level', 'component', 'message', 'account'};

  /// Join [lines] with the app + OS banner and write the result to a temp
  /// file, then return the file path so the caller can hand it to the
  /// share sheet or the clipboard.
  Future<File> writeExportFile(List<String> lines) async {
    final tmp = _tempDirOverride ?? await getTemporaryDirectory();
    final stamp = _now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(p.join(tmp.path, 'hoodik-logs-$stamp.txt'));
    await file.writeAsString(_compose(lines), flush: true);
    return file;
  }

  String _compose(List<String> lines) {
    final header = [
      'Hoodik bug report',
      'Generated: ${_now().toIso8601String()}',
      '',
      'The log lines below are the ones YOU chose to share in the redactor.',
      'Plaintext filenames may appear here; file contents, passwords,',
      'encryption keys, tokens, and cookies never do.',
      '',
      '----- logs -----',
      '',
    ].join('\n');
    return '$header${lines.join('\n')}\n';
  }

  /// Invoke the native share sheet with [file] attached and the support
  /// email pre-filled. Falls back to the default share sheet on platforms
  /// that cannot target a specific app.
  Future<void> shareViaEmail(File file) async {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/plain')],
      subject: ambientL10n.serviceBugReportSubject,
      text: ambientL10n.serviceBugReportShareText(supportEmail),
    );
  }

  /// Join the redacted lines into a single string for clipboard copy.
  String clipboardContent(List<String> lines) => _compose(lines);
}
