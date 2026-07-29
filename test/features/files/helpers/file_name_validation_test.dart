import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/features/files/helpers/file_name_validation.dart';

void main() {
  group('validateFileName', () {
    test('returns NameUnchanged when input is null', () {
      expect(validateFileName(null), isA<NameUnchanged>());
    });

    test('returns NameUnchanged for empty input', () {
      expect(validateFileName(''), isA<NameUnchanged>());
    });

    test('returns NameUnchanged for whitespace-only input', () {
      expect(validateFileName('   '), isA<NameUnchanged>());
    });

    test('returns NameUnchanged when trimmed equals current name', () {
      expect(validateFileName(' foo ', current: 'foo'), isA<NameUnchanged>());
    });

    test('rejects names containing forward slash', () {
      final result = validateFileName('a/b');
      expect(result, isA<NameInvalid>());
      expect((result as NameInvalid).reason, contains('/'));
    });

    test('rejects names containing backslash', () {
      final result = validateFileName('a\\b');
      expect(result, isA<NameInvalid>());
      expect((result as NameInvalid).reason, contains('\\'));
    });

    test('rejects dot and dot-dot', () {
      expect(validateFileName('.'), isA<NameInvalid>());
      expect(validateFileName('..'), isA<NameInvalid>());
    });

    test('accepts a plain valid name and returns it trimmed', () {
      final result = validateFileName('  my file.txt  ');
      expect(result, isA<NameOk>());
      expect((result as NameOk).trimmed, 'my file.txt');
    });

    test('accepts unicode names', () {
      final result = validateFileName('café.md');
      expect(result, isA<NameOk>());
      expect((result as NameOk).trimmed, 'café.md');
    });
  });
}
