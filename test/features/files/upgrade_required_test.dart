import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/features/files/helpers/file_helpers.dart';

DioException _response(int status, {Object? data}) => DioException(
      requestOptions: RequestOptions(path: '/api/storage/search'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/storage/search'),
        statusCode: status,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );

void main() {
  group('isUpgradeRequired', () {
    test('recognizes 426, which the server returns for a stale client', () {
      expect(isUpgradeRequired(_response(HttpStatus.upgradeRequired)), isTrue);
    });

    test('does not fire on ordinary failures', () {
      for (final status in [400, 401, 403, 404, 409, 500, 503]) {
        expect(
          isUpgradeRequired(_response(status)),
          isFalse,
          reason: '$status must not read as "update the app"',
        );
      }
    });

    test('does not fire on non-Dio errors', () {
      expect(isUpgradeRequired(Exception('boom')), isFalse);
    });
  });

  group('formatErrorMessage', () {
    /// The regression this exists for: a bare `DioException.toString()` is
    /// four lines of transport internals ending in advice to "fix your request
    /// code or fix the server code", which used to land in front of users in
    /// crimson where their search results should have been.
    test('never surfaces Dio internals', () {
      final message = formatErrorMessage(_response(500));

      expect(message, isNot(contains('DioException')));
      expect(message, isNot(contains('validateStatus')));
      expect(message, isNot(contains('developer.mozilla.org')));
      expect(message.split('\n').length, 1);
    });

    test('prefers the server\'s own message when there is one', () {
      final message = formatErrorMessage(
        _response(409, data: {'message': 'another_edit_is_in_progress'}),
      );

      expect(message, 'another_edit_is_in_progress');
    });

    test('falls back to the status when the body carries no message', () {
      expect(formatErrorMessage(_response(503)), 'HTTP 503');
    });

    test('still strips the Exception prefix off plain errors', () {
      expect(formatErrorMessage(Exception('no key')), 'no key');
    });
  });
}
