import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/background_tar_transfer.dart';

/// Regression coverage for the failure-path logging shape.
///
/// Bug history (2026-04-27): a Cloudflare 524 / 413 / abrupt TCP drop
/// killed the upload, but the on-disk log line carried only
/// `{task_id, status}` — and `status` was `null` for the most common
/// case (CF cuts the TCP before the response). The user couldn't see
/// what went wrong without instrumenting and rebuilding.
///
/// These tests pin the structured shape at the data-class level so a
/// regression that drops `cause` / `body` from the log fields fails
/// the build before it lands.
void main() {
  group('TransferFailure', () {
    UploadTask makeTask() => UploadTask(
      taskId: 'tar-ul:abc',
      url: 'https://drive.example.com/api/storage/abc?format=tar',
      filename: 'upload.tar',
    );

    TaskStatusUpdate failureUpdate({
      TaskException? exception,
      String? body,
      int? status,
    }) {
      return TaskStatusUpdate(
        makeTask(),
        TaskStatus.failed,
        exception,
        body,
        null, // headers
        status,
      );
    }

    test('CF 100s timeout — TCP cut before a response: status null, cause '
        'carries the OS-native description, log fields preserve all of it '
        'so the failure is debuggable from the log alone', () {
      final update = failureUpdate(
        exception: TaskException('Operation timed out'),
        status: null,
        body: null,
      );

      final failure = TransferFailure.fromTaskStatusUpdate(update);

      expect(failure.status, isNull);
      expect(failure.cause, equals('Operation timed out'));
      expect(failure.body, isNull);

      expect(failure.asLogFields('tar-ul:abc'), {
        'task_id': 'tar-ul:abc',
        'status': null,
        'cause': 'Operation timed out',
        'body': null,
      });
    });

    test('CF 524 origin timeout — status + body land in the log so the user '
        'sees both the proxy verdict and the HTML hint', () {
      final update = failureUpdate(
        exception: TaskException('HTTP error'),
        status: 524,
        body: '<!DOCTYPE html><html>error code: 524 — origin timeout</html>',
      );

      final failure = TransferFailure.fromTaskStatusUpdate(update);

      expect(failure.status, equals(524));
      expect(failure.cause, equals('HTTP error'));
      expect(failure.body, contains('error code: 524'));

      final fields = failure.asLogFields('tar-ul:abc');
      expect(fields['status'], 524);
      expect(fields['cause'], 'HTTP error');
      expect(fields['body'], contains('error code: 524'));
    });

    test('CF 413 body-too-large — status surfaces; the body excerpt is kept '
        'so the log distinguishes 413 (size) from 524 (timeout) without '
        'guessing', () {
      final update = failureUpdate(
        exception: TaskException('HTTP error'),
        status: 413,
        body: 'Request Entity Too Large',
      );

      final failure = TransferFailure.fromTaskStatusUpdate(update);

      expect(failure.status, 413);
      expect(failure.body, equals('Request Entity Too Large'));
    });

    test('response body longer than the cap is truncated with an ellipsis '
        'so the log line stays bounded — full body remains accessible '
        'through background_downloader if the caller wants more', () {
      final huge = 'x' * (TransferFailure.bodyMaxLength + 250);
      final update = failureUpdate(status: 500, body: huge);

      final failure = TransferFailure.fromTaskStatusUpdate(update);

      expect(failure.body!.length, equals(TransferFailure.bodyMaxLength + 1));
      expect(failure.body, endsWith('…'));
    });

    test('empty response body is normalised to null so the log doesn\'t '
        'carry an empty string', () {
      final update = failureUpdate(status: 500, body: '');
      expect(TransferFailure.fromTaskStatusUpdate(update).body, isNull);
    });

    test('asLogFields always emits every diagnostic dimension as its own '
        'top-level key — explicit nulls beat missing keys for downstream '
        'log pipelines that filter by presence', () {
      final empty = const TransferFailure();
      expect(empty.asLogFields('tar-ul:xyz').keys.toSet(), {
        'task_id',
        'status',
        'cause',
        'body',
      });
    });

    test('message stitches cause + status + body into the rethrown '
        'Exception\'s text so callers up the stack still see context', () {
      final f = const TransferFailure(
        cause: 'Operation timed out',
        status: 524,
        body: 'origin timeout',
      );
      expect(
        f.message,
        equals('Operation timed out (status 524): origin timeout'),
      );
    });

    test('message degrades gracefully when fields are missing — no null '
        'literals, no dropped sections', () {
      expect(const TransferFailure().message, equals('unknown cause'));
      expect(
        const TransferFailure(status: 422).message,
        equals('unknown cause (status 422)'),
      );
    });
  });
}
