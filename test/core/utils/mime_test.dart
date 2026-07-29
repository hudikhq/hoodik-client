import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/utils/mime.dart';

void main() {
  group('guessMimeFromFileName', () {
    test('maps common image extensions', () {
      expect(guessMimeFromFileName('photo.jpg'), 'image/jpeg');
      expect(guessMimeFromFileName('photo.jpeg'), 'image/jpeg');
      expect(guessMimeFromFileName('screen.png'), 'image/png');
      expect(guessMimeFromFileName('logo.svg'), 'image/svg+xml');
      expect(guessMimeFromFileName('IMG_0001.HEIC'), 'image/heic');
      expect(guessMimeFromFileName('burst.heif'), 'image/heif');
    });

    test('maps video extensions', () {
      expect(guessMimeFromFileName('clip.mp4'), 'video/mp4');
      expect(guessMimeFromFileName('clip.mov'), 'video/quicktime');
    });

    test('maps text and code extensions', () {
      expect(guessMimeFromFileName('notes.md'), 'text/markdown');
      expect(guessMimeFromFileName('main.rs'), 'text/x-rust');
      expect(guessMimeFromFileName('app.dart'), 'text/x-dart');
    });

    test('is case-insensitive on the extension', () {
      expect(guessMimeFromFileName('IMG_0001.JPG'), 'image/jpeg');
      expect(guessMimeFromFileName('Archive.ZIP'), 'application/zip');
    });

    test('uses the last dot as the extension boundary', () {
      expect(
        guessMimeFromFileName('my.photo.set.png'),
        'image/png',
        reason: 'Multi-dot names must pick the trailing extension',
      );
    });

    test('falls back to octet-stream for unknown or missing extensions', () {
      expect(
        guessMimeFromFileName('README'),
        'application/octet-stream',
        reason: 'No extension means no guess',
      );
      expect(
        guessMimeFromFileName('data.xyz'),
        'application/octet-stream',
        reason: 'Unknown extension should use the generic fallback',
      );
    });
  });
}
