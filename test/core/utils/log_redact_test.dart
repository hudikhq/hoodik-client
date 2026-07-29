import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/utils/log_redact.dart';

void main() {
  group('redactUri', () {
    test('keeps scheme, host, port, path — drops query and fragment', () {
      final uri = Uri.parse(
        'https://api.example.com:8443/files?q=secret&page=3#link-key',
      );
      expect(redactUri(uri), 'https://api.example.com:8443/files');
    });

    test('strips userinfo so embedded credentials cannot leak', () {
      final uri = Uri.parse('https://user:pass@drive.example.com/api/files');
      expect(redactUri(uri), 'https://drive.example.com/api/files');
    });

    test('handles path-only URIs (no scheme, no host)', () {
      final uri = Uri.parse('/api/files/abc123');
      expect(redactUri(uri), '/api/files/abc123');
    });

    test('returns empty string for an empty URI', () {
      expect(redactUri(Uri()), '');
    });

    test('drops a query-only URI down to the empty path', () {
      // A bare "?q=secret" has no scheme, no host, and an empty path —
      // nothing survives redaction.
      final uri = Uri.parse('?q=secret');
      expect(redactUri(uri), '');
    });

    test('preserves default port 443 when it was explicit in the URI', () {
      final uri = Uri.parse('https://example.com:443/path');
      // Uri.parse normalises away the default port — we follow suit.
      expect(redactUri(uri), 'https://example.com/path');
    });
  });

  group('redactException', () {
    test('returns the runtime type name for a common exception', () {
      expect(
        redactException(const FormatException('oh no')),
        'FormatException',
      );
    });

    test('returns the runtime type name for a subclass of Error', () {
      expect(redactException(StateError('bad state')), 'StateError');
    });

    test('returns the runtime type for a custom exception class', () {
      expect(redactException(_TestException()), '_TestException');
    });

    test('does not call toString() so payload never leaks', () {
      final sneaky = _ThrowingToString();
      expect(() => redactException(sneaky), returnsNormally);
      expect(redactException(sneaky), '_ThrowingToString');
    });
  });

  group('describeError', () {
    test('preserves the exception message (the whole point) so a CF 524 / '
        'origin-timeout / 413 surfaces in the log instead of being '
        'collapsed to "_Exception"', () {
      final e = Exception('Operation timed out (status 524): server is busy');
      final described = describeError(e);
      expect(described, contains('Operation timed out'));
      expect(described, contains('524'));
      expect(described, contains('server is busy'));
    });

    test('includes the runtime type when toString does not already start '
        'with it — covers custom exception classes whose toString returns '
        'just the message', () {
      final described = describeError(_BareMessageException('bad chunk'));
      expect(described, startsWith('_BareMessageException'));
      expect(described, contains('bad chunk'));
    });

    test(
      'does not double up the type prefix when toString already begins '
      'with the runtime type (the common Exception/FormatException case)',
      () {
        final described = describeError(const FormatException('oh no'));
        expect(described, equals('FormatException: oh no'));
      },
    );

    test('scrubs `Bearer <token>` from the message so a leaked auth header '
        'in an exception text does not survive into the log', () {
      final e = Exception(
        'request failed Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload',
      );
      final described = describeError(e);
      expect(described, contains('Bearer [REDACTED]'));
      expect(described, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
    });

    test('drops the query string from any http(s) URL embedded in the '
        'message — DioException toString often carries chunk indices, '
        'transfer tokens, and name hashes there', () {
      final e = Exception(
        'POST https://drive.example.com/api/storage/abc?chunk=3&checksum=xyz failed',
      );
      final described = describeError(e);
      expect(described, contains('https://drive.example.com/api/storage/abc'));
      expect(described, isNot(contains('chunk=3')));
      expect(described, isNot(contains('checksum=xyz')));
    });

    test('drops the URL fragment so a public-link key never lands in the '
        'log, even when reflected inside an exception message', () {
      final e = Exception(
        'navigated to https://drive.example.com/links/abc#deadbeefcafe before crash',
      );
      final described = describeError(e);
      expect(described, contains('https://drive.example.com/links/abc'));
      expect(described, isNot(contains('deadbeefcafe')));
    });

    test('redacts a Cookie header value', () {
      final e = Exception('headers: Cookie: hoodik_session=abc.def.ghi');
      final described = describeError(e);
      expect(described, contains('cookie: [REDACTED]'));
      expect(described, isNot(contains('abc.def.ghi')));
    });

    test('leaves an HTTP error status + body alone — exactly the diagnostic '
        'detail BackgroundTarTransfer needs to surface', () {
      final e = Exception('Operation timed out (status 524): error code: 524');
      expect(
        describeError(e),
        equals('Exception: Operation timed out (status 524): error code: 524'),
      );
    });
  });

  group('redactId', () {
    test('truncates a long ID to 8 chars plus ellipsis', () {
      expect(redactId('abc123def456789ghijkl'), 'abc123de\u2026');
    });

    test('leaves a short ID unchanged', () {
      expect(redactId('abc'), 'abc');
    });

    test('leaves an empty ID unchanged', () {
      expect(redactId(''), '');
    });

    test('leaves an 8-char ID untruncated (no ellipsis)', () {
      expect(redactId('abcdefgh'), 'abcdefgh');
    });

    test('truncates a 9-char ID (ellipsis added)', () {
      expect(redactId('abcdefghi'), 'abcdefgh\u2026');
    });
  });

  group('redactSecret', () {
    test('always returns the redaction marker, regardless of input', () {
      expect(redactSecret('hunter2'), '[REDACTED]');
      expect(redactSecret(null), '[REDACTED]');
      expect(redactSecret(''), '[REDACTED]');
      expect(redactSecret(42), '[REDACTED]');
      expect(redactSecret({'nested': 'secret'}), '[REDACTED]');
    });
  });

  group('redactFields', () {
    test('redacts exact-match sensitive keys (case-insensitive)', () {
      final out = redactFields(<String, Object?>{
        'password': 'hunter2',
        'Token': 'abc',
        'AUTHORIZATION': 'Bearer xyz',
        'userId': 42,
      });
      expect(out['password'], '[REDACTED]');
      expect(out['Token'], '[REDACTED]');
      expect(out['AUTHORIZATION'], '[REDACTED]');
      expect(out['userId'], 42);
    });

    test('redacts keys matching the suffix regex', () {
      final out = redactFields(<String, Object?>{
        'user_password': 'x',
        'oauth_token': 'y',
        'encryption_key': 'z',
      });
      expect(out['user_password'], '[REDACTED]');
      expect(out['oauth_token'], '[REDACTED]');
      expect(out['encryption_key'], '[REDACTED]');
    });

    test('leaves unrelated keys untouched even if they embed short words', () {
      // 'author' contains 'auth' but does not hit the exact-match set or
      // the word-boundary suffix — it must pass through unchanged.
      final out = redactFields(<String, Object?>{
        'author': 'Alice',
        'authored_at': 1234,
        'count': 5,
      });
      expect(out['author'], 'Alice');
      expect(out['authored_at'], 1234);
      expect(out['count'], 5);
    });

    test('over-redacts public_key — false positive acceptable', () {
      // Policy trade: better to scrub a harmless-looking "public_key" than
      // to let a real "private_key" slip through because of regex nuance.
      final out = redactFields(<String, Object?>{'public_key': 'PEM data'});
      expect(out['public_key'], '[REDACTED]');
    });

    test('returns an empty map for empty input', () {
      expect(redactFields(const {}), isEmpty);
    });
  });

  group('redactQueryHash', () {
    test('returns empty string for empty input', () {
      expect(redactQueryHash(''), '');
    });

    test('returns 16 hex chars for a non-empty input', () {
      final hash = redactQueryHash('hello world');
      expect(hash.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(hash), isTrue);
    });

    test('is deterministic — same input produces same hash', () {
      expect(redactQueryHash('tax returns'), redactQueryHash('tax returns'));
    });

    test('distinguishes different inputs', () {
      expect(
        redactQueryHash('tax returns'),
        isNot(redactQueryHash('tax return')),
      );
    });

    test('handles multi-byte UTF-8 input', () {
      final hash = redactQueryHash('файл');
      expect(hash.length, 16);
    });
  });
}

class _TestException implements Exception {}

class _ThrowingToString {
  @override
  String toString() => throw StateError('should not be called');
}

/// Custom exception whose `toString()` returns just a free-form message —
/// no runtime-type prefix. Mirrors hand-written `Exception` subclasses
/// across the codebase. Used by the [describeError] tests to verify the
/// helper still prefixes the type for clarity.
class _BareMessageException implements Exception {
  final String message;
  _BareMessageException(this.message);
  @override
  String toString() => message;
}
