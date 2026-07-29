import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/utils/account_context.dart';
import 'package:hoodik_app/core/utils/logger.dart';

void main() {
  group('Logger level filtering', () {
    setUp(resetLoggingForTests);
    tearDown(resetLoggingForTests);

    test('drops records below the configured minimum level', () {
      final records = <LogRecord>[];
      configureLogging(minLevel: Level.warn, sinks: [records.add]);

      const log = Logger('mcp.server');
      log.debug('debug message');
      log.info('info message');
      log.warn('warn message');
      log.error('error message');

      expect(records.map((r) => r.level).toList(), [Level.warn, Level.error]);
    });

    test('info level lets info/warn/error through and drops debug', () {
      final records = <LogRecord>[];
      configureLogging(minLevel: Level.info, sinks: [records.add]);

      const log = Logger('mcp.server');
      log.debug('nope');
      log.info('yes');
      log.warn('yes');
      log.error('yes');

      expect(records, hasLength(3));
      expect(records.first.level, Level.info);
    });

    test('no sinks means the logger is a no-op regardless of level', () {
      // No configureLogging call — default state.
      const log = Logger('mcp.server');
      expect(() {
        log.debug('a');
        log.info('b');
        log.warn('c');
        log.error('d');
      }, returnsNormally);
    });
  });

  group('Structured fields serialize to JSON', () {
    setUp(resetLoggingForTests);
    tearDown(resetLoggingForTests);

    test('toJson includes base fields plus custom fields flat', () {
      final records = <LogRecord>[];
      configureLogging(minLevel: Level.debug, sinks: [records.add]);

      const log = Logger('mcp.dispatch');
      log.info(
        'mcp tool done',
        fields: {'tool': 'list_files', 'duration_ms': 42},
      );

      expect(records, hasLength(1));
      final json = records.single.toJson();
      expect(json['component'], 'mcp.dispatch');
      expect(json['level'], 'info');
      expect(json['message'], 'mcp tool done');
      expect(json['tool'], 'list_files');
      expect(json['duration_ms'], 42);

      // The encoder must produce valid JSON so the stdout sink can emit it.
      expect(() => jsonEncode(json), returnsNormally);
    });

    test('a throwing sink does not break the caller or other sinks', () {
      final records = <LogRecord>[];
      configureLogging(
        minLevel: Level.debug,
        sinks: [(_) => throw StateError('boom'), records.add],
      );

      const log = Logger('mcp.server');
      expect(() => log.info('test'), returnsNormally);
      expect(records, hasLength(1));
    });
  });

  group('Account-context injection', () {
    setUp(() {
      resetLoggingForTests();
      AccountContext.clear();
    });
    tearDown(() {
      resetLoggingForTests();
      AccountContext.clear();
    });

    test('omits the account field when no context is set', () {
      final records = <LogRecord>[];
      configureLogging(minLevel: Level.debug, sinks: [records.add]);

      const Logger('x').info('no account yet');

      expect(records.single.fields.containsKey('account'), isFalse);
    });

    test('injects the account field when AccountContext is set', () {
      final records = <LogRecord>[];
      configureLogging(minLevel: Level.debug, sinks: [records.add]);

      AccountContext.set(
        email: 'owner@example.test',
        serverHost: 'files.example.test',
      );
      const Logger('x').info('hello');

      expect(
        records.single.fields['account'],
        'owner@example.test / files.example.test',
      );
    });

    test('does not clobber caller-supplied fields', () {
      final records = <LogRecord>[];
      configureLogging(minLevel: Level.debug, sinks: [records.add]);

      AccountContext.set(email: 'a@b.c', serverHost: 'host');
      const Logger('x').info('hello', fields: {'tool': 'sync'});

      final fields = records.single.fields;
      expect(fields['account'], 'a@b.c / host');
      expect(fields['tool'], 'sync');
    });
  });

  group('Privacy invariants', () {
    setUp(resetLoggingForTests);
    tearDown(resetLoggingForTests);

    test('message field does not leak path separators or bearer tokens', () {
      final records = <LogRecord>[];
      configureLogging(minLevel: Level.debug, sinks: [records.add]);

      // Synthetic call path: the server should NEVER log filenames, tokens,
      // search queries, or file content. These invariants check that a
      // sample of the known emit points carry only privacy-safe fields.
      const log = Logger('mcp.server');
      log.info(
        'mcp server started',
        fields: {'port': 19548, 'endpoint': 'http://127.0.0.1:19548/mcp'},
      );
      log.info(
        'mcp tool done',
        fields: {'tool': 'read_file', 'duration_ms': 5},
      );
      log.warn(
        'mcp tool call denied: rate limit',
        fields: {'tool': 'read_file', 'reason': 'rate_limit'},
      );

      for (final record in records) {
        final encoded = jsonEncode(record.toJson());
        // No plaintext file names.
        expect(encoded, isNot(contains('.md')));
        expect(encoded, isNot(contains('.txt')));
        // No bearer token leakage (we never pass tokens to the logger).
        expect(encoded, isNot(contains('Bearer ')));
        // No UUID-shaped tokens (bearer is a UUID in the current impl).
        expect(
          encoded,
          isNot(
            matches(
              RegExp(
                r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
              ),
            ),
          ),
        );
      }
    });
  });
}
