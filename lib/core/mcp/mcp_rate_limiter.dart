/// Monotonic time source used by [RateLimiter]. Defaults to `DateTime.now()`
/// but tests can inject a deterministic clock.
typedef Clock = DateTime Function();

DateTime _systemClock() => DateTime.now();

/// Token-bucket rate limiter.
///
/// [refillRatePerSecond] tokens are added to the bucket per second, up to
/// [capacity] total. Each call to [tryConsume] debits one token if available
/// and returns true; when the bucket is empty the call returns false and
/// [retryAfter] tells the caller how long until the next token is available.
///
/// We prefer a token bucket over a fixed-window counter because it handles
/// bursts gracefully: an agent that has been idle can briefly exceed the
/// steady-state rate (up to [capacity]) without being throttled, matching
/// the intuitive expectation that "I've been idle, let me do a batch now".
class RateLimiter {
  final int capacity;
  final double refillRatePerSecond;
  final Clock _clock;

  double _tokens;
  DateTime _lastRefill;

  RateLimiter({
    required this.capacity,
    required this.refillRatePerSecond,
    Clock clock = _systemClock,
  }) : assert(capacity > 0, 'capacity must be positive'),
       assert(refillRatePerSecond > 0, 'refill rate must be positive'),
       _clock = clock,
       _tokens = capacity.toDouble(),
       _lastRefill = clock();

  /// How many whole tokens are currently available. Refills on access so
  /// callers checking this value see the same state [tryConsume] would.
  int get availableTokens {
    _refill();
    return _tokens.floor();
  }

  /// Attempt to debit one token. Returns true on success. On failure the
  /// caller can read [retryAfter] to schedule a retry.
  bool tryConsume() {
    _refill();
    if (_tokens >= 1.0) {
      _tokens -= 1.0;
      return true;
    }
    return false;
  }

  /// Duration until at least one whole token is available. Zero when a
  /// token is already available. Used to populate the `retry after` hint in
  /// the JSON-RPC error response.
  Duration get retryAfter {
    _refill();
    if (_tokens >= 1.0) return Duration.zero;
    final tokensNeeded = 1.0 - _tokens;
    final seconds = tokensNeeded / refillRatePerSecond;
    return Duration(milliseconds: (seconds * 1000).ceil());
  }

  void _refill() {
    final now = _clock();
    final elapsedMs = now.difference(_lastRefill).inMicroseconds / 1000000.0;
    if (elapsedMs <= 0) return;
    final added = elapsedMs * refillRatePerSecond;
    _tokens = (_tokens + added).clamp(0.0, capacity.toDouble());
    _lastRefill = now;
  }
}
