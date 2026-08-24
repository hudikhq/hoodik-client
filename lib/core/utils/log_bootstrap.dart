import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;

import 'log_file_sink.dart';
import 'logger.dart';

/// Wire the rotating on-disk sink (and stdout in debug) before any other
/// code logs. Extracted from [main] so that file stays under the line
/// ceiling; behaviour is unchanged.
Future<void> bootstrapLogging() async {
  final sinks = <LogSink>[];
  if (kDebugMode) {
    sinks.add(stdoutLogSink);
  }
  try {
    final fileSink = await LogFileSink.open();
    sinks.add(fileSink.record);
    unawaited(fileSink.pruneOlderThan(const Duration(days: 3)));
  } catch (_) {
    // Best-effort: never block app start on a logging failure.
  }
  configureLogging(
    minLevel: kDebugMode ? Level.debug : Level.info,
    sinks: sinks,
  );
}
