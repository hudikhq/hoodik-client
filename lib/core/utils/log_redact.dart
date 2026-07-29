import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Pure redaction helpers used by every call site that emits a log record.
///
/// Each function is deterministic and allocation-light so it can be called
/// on hot paths (request interceptors, worker message handlers) without a
/// measurable cost. The goal is that, by construction, a log record produced
/// via these helpers cannot contain secrets, server response bodies, URL
/// query strings, or raw exception detail.

/// Marker string used wherever a value is scrubbed. Consistent across helpers
/// so a human reviewer can grep the exported log for it.
const String redactedMarker = '[REDACTED]';

/// Exact-match denylist for field keys that must never carry their raw
/// value into a log record. Case-insensitive.
const Set<String> _sensitiveExactKeys = {
  'password',
  'passwd',
  'pwd',
  'token',
  'cookie',
  'authorization',
  'auth',
  'pin',
  'private_key',
  'privatekey',
  'secret',
  'bearer',
  'session',
  'session_id',
  'sessionid',
  'api_key',
  'apikey',
  'access_token',
  'refresh_token',
  'id_token',
};

/// Suffix patterns that catch compound keys like `user_password` or
/// `oauth_token`. Over-matches `public_key` — acceptable trade: the
/// redactor prefers a false positive ('[REDACTED]' shown for a harmless
/// value) over a false negative (a real secret leaking through).
final RegExp _sensitiveSuffix = RegExp(
  r'_(password|passwd|token|cookie|secret|key|auth|bearer|pin)$',
  caseSensitive: false,
);

/// Strip query, fragment, and userinfo from [uri], returning only
/// `scheme://host[:port]/path`.
///
/// Query strings carry search terms, resource IDs, and pagination state.
/// Fragments carry link keys on public-link URLs. Userinfo can embed
/// credentials. All three must be dropped before any URI ends up in a log.
String redactUri(Uri uri) {
  final buffer = StringBuffer();
  if (uri.hasScheme) {
    buffer
      ..write(uri.scheme)
      ..write('://');
  }
  if (uri.host.isNotEmpty) {
    buffer.write(uri.host);
    if (uri.hasPort) {
      buffer
        ..write(':')
        ..write(uri.port);
    }
  }
  buffer.write(uri.path);
  return buffer.toString();
}

/// Reduce [exception] to just its runtime type name.
///
/// Raw `.toString()` on framework exceptions often embeds the failing
/// argument, a response body, or a stack trace — none of which belong in
/// a log we may later export to `security@hoodik.io`.
///
/// Use this at call sites where the runtime type alone is enough to act
/// on the failure (auth refresh, IAP, tray glue). For network and
/// transfer-pipeline failures where the actual cause / status / body is
/// what makes the log useful, prefer [describeError] — same privacy
/// guarantees, more diagnostic detail.
String redactException(Object exception) => exception.runtimeType.toString();

/// Render [exception] for a diagnostic log line: the runtime type plus the
/// exception's `.toString()` with high-confidence secret patterns scrubbed.
///
/// **Why this exists**: a `BackgroundTarTransfer` upload that dies because
/// Cloudflare returned 524 / 413 builds an `Exception` whose message
/// carries the cause, status, and a snippet of the response body — exactly
/// the data the user (and we) need to debug. [redactException] would
/// collapse it to `_Exception` and the failure becomes invisible. This
/// helper keeps that information while stripping bearer tokens, query
/// strings, link-key fragments, and Cookie / Set-Cookie headers that
/// occasionally show up in framework exception text.
///
/// The redactor UI + the user's manual review remain the final privacy
/// gate before a log is shared.
String describeError(Object exception) {
  final type = exception.runtimeType.toString();
  final raw = exception.toString();
  final scrubbed = _scrubSecretPatterns(raw);
  // Many exception toStrings already start with the runtime type
  // (`Exception:`, `FormatException:`, `DioException [...]:`); avoid
  // doubling it up. The leading-underscore stripper covers Dart's quirk
  // where `Exception('foo').runtimeType.toString()` is `_Exception` but
  // `.toString()` returns `'Exception: foo'`.
  final typePublic = type.startsWith('_') ? type.substring(1) : type;
  if (scrubbed.startsWith(type) ||
      scrubbed.startsWith('$type:') ||
      scrubbed.startsWith(typePublic) ||
      scrubbed.startsWith('$typePublic:')) {
    return scrubbed;
  }
  return '$type: $scrubbed';
}

/// Strip known-secret patterns from a free-form string so it can land in
/// a diagnostic log without leaking credentials. Conservative by design —
/// each pattern is an exact match for a credential-bearing token, never a
/// guess.
String _scrubSecretPatterns(String s) {
  return s
      // `Bearer <token>` in headers.
      .replaceAll(
        RegExp(r'Bearer\s+[A-Za-z0-9._\-+/=]+', caseSensitive: false),
        'Bearer $redactedMarker',
      )
      // Query strings on http(s) URLs — they carry chunk indices, name
      // hashes, transfer-token query params, etc. Drop everything from `?`
      // up to the next whitespace / quote / closing bracket.
      .replaceAllMapped(
        RegExp(r'(https?://[^\s?#"<>]+)\?[^\s"<>]*'),
        (m) => m.group(1)!,
      )
      // URL fragments — public-link keys ride here. Same termination set.
      .replaceAllMapped(
        RegExp(r'(https?://[^\s#"<>]+)#[^\s"<>]*'),
        (m) => m.group(1)!,
      )
      // Cookie / Set-Cookie header values. Replacement normalises the
      // header name to lowercase so callers see a deterministic shape
      // regardless of how the source rendered it.
      .replaceAllMapped(
        RegExp(
          r'(?:^|\s)(set-cookie|cookie)\s*[:=]\s*[^\s,;]+',
          caseSensitive: false,
        ),
        (m) => ' ${m.group(1)!.toLowerCase()}: $redactedMarker',
      );
}

/// Truncate an opaque identifier (file ID, directory ID, upload ID) to the
/// first 8 characters followed by an ellipsis.
///
/// Short enough that the exported log stays scannable, long enough that a
/// single user's log can distinguish thousands of distinct IDs without
/// collision.
String redactId(String id) {
  if (id.length <= 8) return id;
  return '${id.substring(0, 8)}\u2026';
}

/// Always returns [redactedMarker]. Use at any call site that handles a
/// password, PIN, bearer token, session cookie, or encryption key — the
/// function signature itself is the proof that nothing leaked.
String redactSecret(Object? _) => redactedMarker;

/// Return a copy of [fields] with the value of every sensitive-looking key
/// replaced by [redactedMarker].
///
/// "Sensitive" is judged against a curated exact-match set plus a suffix
/// regex (see [_sensitiveExactKeys] / [_sensitiveSuffix]). Nested maps are
/// not walked — callers that want to log a nested structure must flatten
/// it or redact it explicitly before calling this helper.
Map<String, Object?> redactFields(Map<String, Object?> fields) {
  if (fields.isEmpty) return const {};
  final result = <String, Object?>{};
  for (final entry in fields.entries) {
    result[entry.key] = _isSensitiveKey(entry.key)
        ? redactedMarker
        : entry.value;
  }
  return result;
}

bool _isSensitiveKey(String key) {
  final lower = key.toLowerCase();
  if (_sensitiveExactKeys.contains(lower)) return true;
  if (_sensitiveSuffix.hasMatch(lower)) return true;
  return false;
}

/// SHA256-hash a search query or other user-supplied string and return the
/// first 16 hex chars.
///
/// This mirrors the hash the server already receives (file names are
/// tokenised + hashed client-side before search), so logging the hash
/// rather than the plaintext preserves debuggability without widening the
/// information the recipient of an exported log can recover.
///
/// An empty input returns an empty string — "no query, no hash".
String redactQueryHash(String query) {
  if (query.isEmpty) return '';
  final digest = sha256.convert(utf8.encode(query));
  return digest.toString().substring(0, 16);
}
