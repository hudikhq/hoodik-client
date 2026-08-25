import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/media_picker_channel.dart';

/// Drives the channel with synthesized platform events — the same envelopes
/// the Swift side posts — and pins the parsing plus the stream's lifecycle:
/// it must close itself after `done`, because the controller's `await for`
/// would otherwise never return.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const eventChannelName = 'io.hoodik.app/media_picker/events';
  const codec = StandardMethodCodec();

  Future<void> emit(Object? event) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          eventChannelName,
          codec.encodeSuccessEnvelope(event),
          (_) {},
        );
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('io.hoodik.app/media_picker'),
          (call) async => true,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          eventChannelName,
          (message) async => codec.encodeSuccessEnvelope(null),
        );
  });

  test('parses the native event sequence and closes after done', () async {
    final channel = MediaPickerChannel();
    final collected = <MediaPickEvent>[];

    final consumed = channel.pickMedia().forEach(collected.add);
    await Future<void>.delayed(Duration.zero);

    await emit({
      'type': 'picked',
      'items': [
        {'index': 0, 'name': 'IMG_0001'},
        {'index': 1, 'name': 'clip'},
      ],
    });
    await emit({'type': 'progress', 'index': 1, 'fraction': 0.5});
    await emit({'type': 'ready', 'index': 1, 'path': '/tmp/clip.mov'});
    await emit({'type': 'failed', 'index': 0, 'message': 'iCloud said no'});
    await emit({'type': 'done'});

    await consumed;

    expect(collected, hasLength(4));
    final selection = collected[0] as MediaPickSelection;
    expect(selection.items.map((i) => i.name), ['IMG_0001', 'clip']);
    final progress = collected[1] as MediaPickProgress;
    expect(progress.index, 1);
    expect(progress.fraction, 0.5);
    final ready = collected[2] as MediaPickReady;
    expect(ready.path, '/tmp/clip.mov');
    final failed = collected[3] as MediaPickFailed;
    expect(failed.message, 'iCloud said no');
  });

  test('a cancelled pick yields an empty selection then closes', () async {
    final channel = MediaPickerChannel();
    final collected = <MediaPickEvent>[];

    final consumed = channel.pickMedia().forEach(collected.add);
    await Future<void>.delayed(Duration.zero);

    await emit({'type': 'picked', 'items': []});
    await emit({'type': 'done'});

    await consumed;

    expect(collected, hasLength(1));
    expect((collected.single as MediaPickSelection).items, isEmpty);
  });
}
