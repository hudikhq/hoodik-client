/// Per-base-URL memory of whether the server understood `?format=tar` last
/// time we asked. The tar download and upload FFI calls are strictly faster
/// than per-chunk loops on any modern server, but older Hoodik deployments
/// (pre-v1.0.2) only accept per-chunk requests. We learn which bucket a
/// server falls into on the first attempt and remember it for the rest of
/// the session so every subsequent transfer skips the failed probe.
///
/// Scope: one cache per logged-in session. Cleared on logout so a new
/// account against the same base URL still gets a fresh capability probe.
class TarCapabilityCache {
  final Map<String, bool> _supportsTar = {};

  /// `true` / `false` if we've already learned the answer for [baseUrl],
  /// otherwise `null` meaning "try tar first and record the outcome".
  bool? lookup(String baseUrl) => _supportsTar[baseUrl];

  void markSupported(String baseUrl) => _supportsTar[baseUrl] = true;

  void markUnsupported(String baseUrl) => _supportsTar[baseUrl] = false;

  void clear() => _supportsTar.clear();
}

/// Decide whether an error raised by the tar FFI calls means "this server
/// doesn't speak tar, retry per-chunk" or "this is a real failure, bubble
/// up".
///
/// Falls back when the failure is one a per-chunk retry plausibly survives:
///
///   * Capability rejection from an old server that doesn't grok
///     `?format=tar` (405 / 415 / 400+format / 422+probe / etc.).
///   * Proxy / origin lid on the *single big POST* that tar relies on —
///     CF body-size 413, CF origin-timeout 524, gateway 502, gateway
///     timeout 504, or a TCP RST mid-stream (status null + "connection
///     reset" / "broken pipe" / "operation timed out"). Per-chunk POSTs
///     are ~4 MiB / ~2 s each, well inside any sane proxy budget, so the
///     fallback is exactly what users behind Cloudflare / Caddy / nginx
///     with default body-size or read-timeout limits need.
///
/// Doesn't fall back on generic non-tar-shaped errors (DNS, auth 401/403,
/// server 500 with no probe context) — per-chunk would hit the same wall.
bool shouldFallbackToPerChunk(Object error) {
  final msg = error.toString().toLowerCase();
  // DioException.toString() on the iOS & Android runtime omits the request
  // URL, so `msg.contains('format=tar')` can miss a real tar probe. Pull
  // the URL directly off the exception when it's a DioException.
  final uri = _requestUriOf(error);
  final urlStr = uri?.toString().toLowerCase() ?? '';
  final isTarProbe =
      msg.contains('format=tar') || urlStr.contains('format=tar');

  if (msg.contains('malformed_tar') || msg.contains('unknown format')) {
    return true;
  }

  if (_matchesStatus(msg, 405)) return true;

  if (_matchesStatus(msg, 400) &&
      (msg.contains('format') || msg.contains('malformed_tar'))) {
    return true;
  }

  if (_matchesStatus(msg, 404) && isTarProbe) {
    return true;
  }

  // Pre-tar-upload servers (v1.14.x and earlier) silently ignore the
  // `?format=tar` query and interpret the tar-archive body as a single
  // misshapen chunk, which bounces off the chunk-size / checksum validator
  // with `422 Unprocessable Entity`. Without this branch the upload would
  // fail permanently instead of falling back to per-chunk — the compat
  // gate's `tar_fallback_compat_test` pinned this regression.
  if (_matchesStatus(msg, 422) && isTarProbe) {
    return true;
  }

  // Fall-through tar-URL fallback: any status-code rejection of a URL
  // with `?format=tar` should trigger the fallback, since the tar
  // endpoint is what's being probed. Keeps us robust to servers that
  // return 501, 415, etc.
  if (isTarProbe && _anyClientErrorStatus(msg)) {
    return true;
  }

  // Proxy lids on the single big POST. CF / Caddy / nginx all enforce a
  // body-size cap (default 100 MB on CF Free/Pro) and a request-time cap
  // (100 s on CF). When either bites, the user sees one of these. The
  // per-chunk path issues many small POSTs and survives whichever budget
  // tar busted, so a fallback for an upload that's already locally
  // encrypted is essentially free.
  if (isTarProbe && _isProxyOrTransportLid(msg)) {
    return true;
  }

  return false;
}

/// Statuses (and connection-level error markers) that mean "this single
/// big request hit a proxy / network ceiling — try smaller requests."
/// Only consulted on a tar probe so a normal API blip on an unrelated
/// route never gets reinterpreted as a fallback signal.
bool _isProxyOrTransportLid(String lowercaseMsg) {
  // 413 — body too large (CF Free 100 MB, Pro 100 MB, Business 200 MB,
  //   nginx default 1 MB, Caddy unlimited but any custom limit possible)
  // 502 — bad gateway (proxy ↔ origin breakdown mid-upload)
  // 504 — gateway timeout (origin took too long to respond)
  // 524 — Cloudflare-specific origin timeout (100 s default)
  for (final status in const [413, 502, 504, 524]) {
    if (_matchesStatus(lowercaseMsg, status)) return true;
  }
  // Connection-level failures — status is null because no HTTP response
  // ever arrived. Match the OS-native uploader's description text. The
  // markers below cover URLSession (iOS / macOS), HttpClient (Android),
  // and Dart's SocketException directly.
  const transportMarkers = [
    'connection reset',
    'connection refused',
    'connection closed',
    'connection aborted',
    'broken pipe',
    'operation timed out',
    'request timeout',
    'socketexception',
    'timeoutexception',
    'network is unreachable',
    'software caused connection abort',
  ];
  for (final marker in transportMarkers) {
    if (lowercaseMsg.contains(marker)) return true;
  }
  return false;
}

/// Pull the request URI off a typed Dio exception when available, so the
/// matcher can check for `?format=tar` without depending on the Dio error's
/// stringified form (which omits the URL on recent versions).
Uri? _requestUriOf(Object error) {
  try {
    // Avoid an import dependency on Dio — use dynamic so this file stays
    // cheap to load. `requestOptions.uri` is the only hot path we care about.
    final dyn = error as dynamic;
    final opts = dyn.requestOptions;
    final uri = opts?.uri;
    if (uri is Uri) return uri;
  } catch (_) {
    // Not a DioException — fine, fall through and let the msg-only checks
    // do their thing.
  }
  return null;
}

/// Broad "some 4xx" check — used only when we've already confirmed the
/// request was a tar probe, so a false positive means we retry per-chunk
/// which is the safe fallback direction.
bool _anyClientErrorStatus(String lowercaseMsg) {
  for (final status in const [400, 415, 422, 501]) {
    if (_matchesStatus(lowercaseMsg, status)) return true;
  }
  return false;
}

/// Cheap check for HTTP status markers embedded in stringified errors.
/// Transfer-crate errors emit `status: 400` / `status 400`; Dio emits
/// `[status code: 400]`. We avoid substring-matching the bare number
/// (would false-hit on payloads like "400 bytes") — always require a
/// `status` token adjacent to it.
bool _matchesStatus(String lowercaseMsg, int status) {
  final s = status.toString();
  return lowercaseMsg.contains('status $s') ||
      lowercaseMsg.contains('status=$s') ||
      lowercaseMsg.contains('status: $s') ||
      lowercaseMsg.contains('status code: $s') ||
      // Dio >=5.x phrases errors as "status code of 422 and …".
      lowercaseMsg.contains('status code of $s') ||
      lowercaseMsg.contains('http $s') ||
      lowercaseMsg.contains('[$s]');
}
