import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/tar_fallback.dart';

void main() {
  group('shouldFallbackToPerChunk', () {
    test('returns true when the error mentions malformed_tar', () {
      expect(
        shouldFallbackToPerChunk(Exception('server responded: malformed_tar')),
        isTrue,
      );
    });

    test('returns true on HTTP 405 Method Not Allowed', () {
      expect(
        shouldFallbackToPerChunk('request failed with status 405'),
        isTrue,
      );
      expect(
        shouldFallbackToPerChunk(Exception('DioException: [status code: 405]')),
        isTrue,
      );
    });

    test('returns true on 400 with format keyword', () {
      expect(
        shouldFallbackToPerChunk('status 400 Bad Request: unknown format=tar'),
        isTrue,
      );
    });

    test('returns true on 404 for the ?format=tar URL', () {
      expect(
        shouldFallbackToPerChunk(
          Exception('status 404 at /api/storage/abc?format=tar'),
        ),
        isTrue,
      );
    });

    test('returns true on 422 for a ?format=tar upload', () {
      // Servers ≤ v1.14.x silently ignore the `format=tar` query param and
      // parse the tar-archive body as a single chunk. Chunk validation
      // rejects it with 422 Unprocessable Entity. This is the real-world
      // rejection shape on every pre-tar-upload release — without it the
      // fallback path never triggers for those self-hosters.
      expect(
        shouldFallbackToPerChunk(
          Exception('status 422 at /api/storage/abc?format=tar: bad chunk'),
        ),
        isTrue,
      );
    });

    test('returns true for Dio 5.x "status code of 422" on tar probe', () {
      // Dio >=5 phrases its stringified error as "status code of N and
      // RequestOptions.validateStatus was configured to throw…". _matchesStatus
      // has to recognise that wording — the compat gate surfaced it first
      // on v1.9.0 / Android where Dio stopped including the URL in toString().
      expect(
        shouldFallbackToPerChunk(
          Exception(
            'DioException: ...status code of 422 at /api/storage/abc?format=tar',
          ),
        ),
        isTrue,
      );
    });

    test('returns false on 422 that is NOT a tar probe', () {
      // Don't swallow legitimate per-chunk validation failures just because
      // they share the 422 code — only the tar path earns the fallback.
      expect(
        shouldFallbackToPerChunk(
          Exception('status 422: chunk_size_mismatch on /api/storage/abc'),
        ),
        isFalse,
      );
    });

    test('returns false on a network timeout', () {
      expect(
        shouldFallbackToPerChunk(
          Exception('Connection timed out after 30 seconds'),
        ),
        isFalse,
      );
    });

    test('returns false on a generic 500 error', () {
      expect(
        shouldFallbackToPerChunk(Exception('status 500 Internal Server Error')),
        isFalse,
      );
    });

    test('returns false on a DNS error', () {
      expect(
        shouldFallbackToPerChunk(
          Exception('Failed host lookup: drive.example.com'),
        ),
        isFalse,
      );
    });

    group('proxy / transport lids on the single big tar POST', () {
      // Cloudflare specifics:
      //   - Free / Pro plans cap proxied request bodies at 100 MB and
      //     total request time at 100 s. Big tars blow both budgets.
      //   - 524 is a CF-only "origin took too long to respond"; 413 is
      //     the body-size verdict; 502 / 504 are the gateway-error
      //     family Caddy / nginx / cloudflared can also emit.
      //   - When CF cuts the TCP without an HTTP response, the OS-native
      //     uploader surfaces a connection-reset / operation-timed-out
      //     style error with status null — that's the case the user hit
      //     on 2026-04-27 with a 300 MB upload to files.example.test.
      //
      // Every shape below MUST trigger fallback when the URL was a tar
      // probe — the per-chunk path issues many ~4 MiB POSTs that finish
      // in ~2 s each and survives every limit a tar request hits.

      test('CF origin timeout 524 on a tar probe → fall back to per-chunk', () {
        expect(
          shouldFallbackToPerChunk(
            Exception(
              'status 524 at /api/storage/abc?format=tar: '
              'a timeout occurred',
            ),
          ),
          isTrue,
        );
      });

      test('CF body-too-large 413 on a tar probe → fall back', () {
        expect(
          shouldFallbackToPerChunk(
            Exception(
              'status 413 at /api/storage/abc?format=tar: '
              'Request Entity Too Large',
            ),
          ),
          isTrue,
        );
      });

      test('gateway 502 / 504 on a tar probe → fall back (proxy ↔ origin '
          'breakdown mid-upload)', () {
        expect(
          shouldFallbackToPerChunk(
            Exception('status 502 at /api/storage/abc?format=tar'),
          ),
          isTrue,
        );
        expect(
          shouldFallbackToPerChunk(
            Exception('status 504 at /api/storage/abc?format=tar'),
          ),
          isTrue,
        );
      });

      test('real-world Cloudflare TCP RST on a tar probe — status null, '
          'message carries the OS-native description and the URL — must '
          'now fall back instead of failing the upload outright', () {
        // Verbatim shape of the failure logged on 2026-04-27 when a
        // 300 MB tar upload through files.example.test was killed by CF
        // at the 100 s mark. Pre-fix this returned false and the
        // upload hard-failed.
        expect(
          shouldFallbackToPerChunk(
            Exception(
              'ClientException with SocketException: Connection reset '
              'by peer (OS Error: Connection reset by peer, errno = 54), '
              'address = files.example.test, port = 49464, '
              'uri=https://files.example.test/api/storage/abc?format=tar',
            ),
          ),
          isTrue,
        );
      });

      test('operation timed out on a tar probe → fall back (URLSession '
          'phrasing for hit-the-100s-CF-budget)', () {
        expect(
          shouldFallbackToPerChunk(
            Exception(
              'NSURLErrorDomain operation timed out for '
              'https://drive.example.com/api/storage/abc?format=tar',
            ),
          ),
          isTrue,
        );
      });

      test('broken pipe on a tar probe → fall back (origin closed the '
          'TCP mid-stream)', () {
        expect(
          shouldFallbackToPerChunk(
            Exception(
              'broken pipe writing to '
              'https://drive.example.com/api/storage/abc?format=tar',
            ),
          ),
          isTrue,
        );
      });

      test('proxy lid keywords WITHOUT a tar probe must NOT fall back — '
          'a regular API timeout has no smaller-request alternative', () {
        // Same connection-reset shape but on /api/files (no format=tar).
        // Pre-tax-tar-probe gate, this would have wrongly fallen back
        // and called perChunk for an unrelated request.
        expect(
          shouldFallbackToPerChunk(
            Exception(
              'ClientException with SocketException: Connection reset '
              'by peer, uri=https://drive.example.com/api/files',
            ),
          ),
          isFalse,
        );
        expect(
          shouldFallbackToPerChunk(
            Exception('status 524 at /api/files: timeout'),
          ),
          isFalse,
        );
        expect(
          shouldFallbackToPerChunk(
            Exception('status 413 at /api/files: too large'),
          ),
          isFalse,
        );
      });
    });
  });

  group('TarCapabilityCache', () {
    test('lookup returns null before anything is recorded', () {
      final cache = TarCapabilityCache();
      expect(cache.lookup('https://example.com'), isNull);
    });

    test('mark + lookup round-trip tracks supported and unsupported', () {
      final cache = TarCapabilityCache();
      cache.markSupported('https://a.example.com');
      cache.markUnsupported('https://b.example.com');

      expect(cache.lookup('https://a.example.com'), isTrue);
      expect(cache.lookup('https://b.example.com'), isFalse);
      expect(cache.lookup('https://other.example.com'), isNull);
    });

    test('clear drops every recorded entry', () {
      final cache = TarCapabilityCache();
      cache.markSupported('https://a.example.com');
      cache.markUnsupported('https://b.example.com');

      cache.clear();

      expect(cache.lookup('https://a.example.com'), isNull);
      expect(cache.lookup('https://b.example.com'), isNull);
    });

    test(
      'markUnsupported overwrites a prior markSupported on the same URL',
      () {
        final cache = TarCapabilityCache();
        cache.markSupported('https://example.com');
        cache.markUnsupported('https://example.com');
        expect(cache.lookup('https://example.com'), isFalse);
      },
    );
  });
}
