import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/transfer_manager.dart';

/// Opening a note or a preview downloads bytes to do the job the user
/// actually asked for, and the screen they are looking at draws its own
/// progress. The ambient strip appearing on top of that is a second bar for
/// something nobody asked to watch.
void main() {
  late TransferManager manager;

  setUp(() => manager = TransferManager());

  TransferItem start({required bool silent, String name = 'note.md'}) =>
      manager.startTransfer(
        fileName: name,
        type: TransferType.downloadHttp,
        totalBytes: 100,
        totalChunks: 1,
        fileId: 'file-$name',
        silent: silent,
      );

  test('a silent fetch stays out of the strip', () {
    start(silent: true);

    expect(manager.visibleTransfers, isEmpty);
    expect(manager.hasVisibleTransfers, isFalse);
  });

  test('an export the user asked for shows', () {
    start(silent: false, name: 'invoice.pdf');

    expect(manager.visibleTransfers, hasLength(1));
    expect(manager.hasVisibleTransfers, isTrue);
  });

  test('a silent fetch is still tracked, just not surfaced', () {
    // The preview screen looks its own transfer up by fileId to read
    // progress from, so hiding it from the strip must not drop it.
    final item = start(silent: true);

    expect(manager.transfers, contains(item));
    expect(manager.hasTransfers, isTrue);
  });

  test('one loud transfer is enough to show the strip', () {
    start(silent: true);
    start(silent: true, name: 'photo.jpg');
    start(silent: false, name: 'export.zip');

    expect(manager.hasVisibleTransfers, isTrue);
    expect(manager.visibleTransfers.map((t) => t.fileName), ['export.zip']);
  });

  test('transfers are loud unless a caller says otherwise', () {
    final item = manager.startTransfer(
      fileName: 'x',
      type: TransferType.uploadHttp,
      totalBytes: 1,
      totalChunks: 1,
    );

    expect(item.silent, isFalse);
  });
}
