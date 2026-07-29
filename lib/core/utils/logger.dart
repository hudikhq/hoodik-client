import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'account_context.dart';

/// Structured log level. Ordered from most to least verbose so handlers can
/// filter by minimum level using [Level.index].
enum Level { debug, info, warn, error }

/// A single structured log record emitted by [Logger] to registered
/// [LogSink]s. Fields beyond the base four go under [fields] and are
/// serialized flat into the JSON output.
class LogRecord {
  final DateTime timestamp;
  final Level level;
  final String component;
  final String message;
  final Map<String, Object?> fields;

  const LogRecord({
    required this.timestamp,
    required this.level,
    required this.component,
    required this.message,
    required this.fields,
  });

  /// JSON-per-line encoding used by [stdoutLogSink].
  Map<String, Object?> toJson() => {
    'ts': timestamp.toIso8601String(),
    'level': level.name,
    'component': component,
    'message': message,
    ...fields,
  };
}

/// A [LogRecord] consumer. Kept as a typedef so production can use a closure
/// over `print`/stderr while tests can plug in a list-append callback.
typedef LogSink = void Function(LogRecord record);

class _LoggerConfig {
  Level minLevel = Level.info;
  final List<LogSink> sinks = [];
}

final _LoggerConfig _config = _LoggerConfig();

/// Emit JSON-per-line to stdout. The default sink when no others are
/// registered — fine for development and for any release build the user has
/// opted into structured logging for.
void stdoutLogSink(LogRecord record) {
  // ignore: avoid_print
  print(jsonEncode(record.toJson()));
}

/// Top-level logging configuration. Invoked once from [main] (or a test
/// `setUp`) to choose which sinks receive records and what the minimum
/// emitted level is.
///
/// An empty [sinks] list turns logging into a no-op so release builds pay
/// zero cost on the hot path unless the user opts in.
void configureLogging({Level minLevel = Level.info, List<LogSink>? sinks}) {
  _config.minLevel = minLevel;
  _config.sinks
    ..clear()
    ..addAll(sinks ?? const []);
}

/// Reset logging back to the startup defaults (info level, no sinks).
///
/// Test helper — exposed so `tearDown` can undo any config a test installed
/// and avoid leaking sinks into the next test's records.
@visibleForTesting
void resetLoggingForTests() {
  _config.minLevel = Level.info;
  _config.sinks.clear();
}

/// Tiny, dependency-free logger. Each component (server, gateway, dispatch,
/// ...) creates one instance and emits records through
/// [debug]/[info]/[warn]/[error]. Levels below the configured minimum are
/// dropped before any allocation happens.
class Logger {
  final String component;

  const Logger(this.component);

  void debug(String message, {Map<String, Object?>? fields}) =>
      _emit(Level.debug, message, fields);

  void info(String message, {Map<String, Object?>? fields}) =>
      _emit(Level.info, message, fields);

  void warn(String message, {Map<String, Object?>? fields}) =>
      _emit(Level.warn, message, fields);

  void error(String message, {Map<String, Object?>? fields}) =>
      _emit(Level.error, message, fields);

  void _emit(Level level, String message, Map<String, Object?>? fields) {
    if (level.index < _config.minLevel.index) return;
    if (_config.sinks.isEmpty) return;

    final account = AccountContext.current;
    final Map<String, Object?> resolvedFields;
    if (account == null) {
      resolvedFields = fields ?? const {};
    } else {
      resolvedFields = <String, Object?>{'account': account, ...?fields};
    }

    final record = LogRecord(
      timestamp: DateTime.now(),
      level: level,
      component: component,
      message: message,
      fields: resolvedFields,
    );
    for (final sink in _config.sinks) {
      try {
        sink(record);
      } catch (_) {
        // Never let a sink crash the caller — logging is observational.
      }
    }
  }
}
