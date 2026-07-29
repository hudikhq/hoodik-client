import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/transfer_errors.dart';

void main() {
  group('TransferCancelledException', () {
    test('is an Exception subtype so generic catches still see it', () {
      final e = const TransferCancelledException('file-1');
      expect(e, isA<Exception>());
    });

    test('toString preserves the "Transfer cancelled" wording that legacy '
        'loops and tests still look at', () {
      final e = const TransferCancelledException('file-1');
      expect(e.toString(), 'Transfer cancelled');
    });

    test('carries the fileId so callers can distinguish which transfer '
        'was cancelled when several are in flight', () {
      final e = const TransferCancelledException('abc-123');
      expect(e.fileId, 'abc-123');
    });

    test('is catchable by type — the pattern the refactored main-thread '
        'loops rely on to skip failTransfer() for user cancellations', () {
      bool caughtByType = false;
      try {
        throw const TransferCancelledException('file-1');
      } on TransferCancelledException {
        caughtByType = true;
      } catch (_) {
        fail(
          'Should have matched the typed catch before falling through to '
          'the generic handler',
        );
      }
      expect(caughtByType, isTrue);
    });
  });
}
