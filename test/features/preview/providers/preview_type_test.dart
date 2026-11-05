import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/features/preview/providers/preview_providers.dart';

void main() {
  group('getPreviewType — audio', () {
    test('detects audio MIME types', () {
      expect(getPreviewType('audio/ogg'), PreviewType.audio);
      expect(getPreviewType('audio/mpeg'), PreviewType.audio);
      expect(getPreviewType('audio/opus'), PreviewType.audio);
      expect(getPreviewType('audio/flac'), PreviewType.audio);
    });

    test('treats an application/ogg container as audio', () {
      expect(getPreviewType('application/ogg'), PreviewType.audio);
      expect(getPreviewType('application/x-ogg'), PreviewType.audio);
    });

    test('falls back to the extension under a generic MIME', () {
      expect(
        getPreviewType('application/octet-stream', fileName: 'voice.ogg'),
        PreviewType.audio,
      );
      expect(
        getPreviewType('application/octet-stream', fileName: 'track.opus'),
        PreviewType.audio,
      );
      expect(
        getPreviewType('application/octet-stream', fileName: 'song.MP3'),
        PreviewType.audio,
      );
    });

    test('an explicit video MIME still wins over an .ogg name', () {
      expect(
        getPreviewType('video/ogg', fileName: 'clip.ogg'),
        PreviewType.video,
      );
    });

    test('leaves unknown binaries unsupported', () {
      expect(
        getPreviewType('application/octet-stream', fileName: 'archive.bin'),
        PreviewType.unsupported,
      );
    });
  });

  group('isPreviewable', () {
    FileItem file(String mime, {String name = 'enc'}) => FileItem(
      id: 'id',
      encryptedName: name,
      mime: mime,
      finishedUploadAt: 1,
    );

    test('accepts audio once the display name is supplied', () {
      expect(isPreviewable(file('application/octet-stream')), isFalse);
      expect(
        isPreviewable(file('application/octet-stream'), fileName: 'voice.ogg'),
        isTrue,
      );
    });

    test('accepts explicit audio MIME without a name', () {
      expect(isPreviewable(file('audio/ogg')), isTrue);
    });
  });
}
