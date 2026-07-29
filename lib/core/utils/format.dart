/// Shared formatting utilities.
///
/// Replaces 7+ private copies of byte formatting, 4+ copies of date
/// formatting, and 3 copies of quota conversion scattered across the codebase.
///
/// These helpers run outside the widget tree (services, isolate callbacks),
/// so they read the active language from `Intl.defaultLocale` — kept in sync
/// with the app locale by `main.dart` — instead of a BuildContext.
library;

import 'package:clock/clock.dart';
import 'package:intl/intl.dart';

import 'l10n_lookup.dart';

String _decimal(double value) => NumberFormat.decimalPatternDigits(
  locale: Intl.defaultLocale ?? 'en',
  decimalDigits: 1,
).format(value);

/// Format a byte count into a human-readable string (B, KB, MB, GB).
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${_decimal(bytes / 1024)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${_decimal(bytes / (1024 * 1024))} MB';
  }
  return '${_decimal(bytes / (1024 * 1024 * 1024))} GB';
}

/// Format a nullable byte count. Returns empty string for null.
String formatBytesOrEmpty(int? bytes) {
  if (bytes == null) return '';
  return formatBytes(bytes);
}

/// Format a [DateTime] as a relative time string ("just now", "5m ago", etc.).
///
/// Falls back to ISO date (YYYY-MM-DD) for dates older than 30 days.
/// Returns [fallback] when [date] is null.
///
/// "Now" is read through `package:clock` so tests can pin a deterministic
/// instant via `withClock(Clock.fixed(...))` — golden tests rely on this.
String formatRelativeTime(DateTime? date, {String? fallback}) {
  if (date == null) return fallback ?? ambientL10n.commonNever;
  final diff = clock.now().difference(date);
  if (diff.inMinutes < 1) return ambientL10n.relativeJustNow;
  if (diff.inHours < 1) return ambientL10n.relativeMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return ambientL10n.relativeHoursAgo(diff.inHours);
  if (diff.inDays < 30) return ambientL10n.relativeDaysAgo(diff.inDays);
  return _isoDate(date);
}

/// Format a Unix timestamp (seconds since epoch) as relative time.
/// Returns [fallback] for 0 or null timestamps.
String formatRelativeTimestamp(int? timestamp, {String? fallback}) {
  if (timestamp == null || timestamp == 0) {
    return fallback ?? ambientL10n.commonNever;
  }
  return formatRelativeTime(
    DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
    fallback: fallback,
  );
}

/// Format a [DateTime] as an absolute date string (YYYY-MM-DD).
/// Optionally includes time (YYYY-MM-DD HH:MM) when [includeTime] is true.
String formatAbsoluteDate(DateTime date, {bool includeTime = false}) {
  final s = _isoDate(date);
  if (!includeTime) return s;
  return '$s '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

/// Format a Unix timestamp as an absolute date string.
/// Returns [fallback] for 0 or null timestamps.
String formatAbsoluteTimestamp(
  int? timestamp, {
  bool includeTime = false,
  String? fallback,
}) {
  if (timestamp == null || timestamp == 0) {
    return fallback ?? ambientL10n.commonNever;
  }
  return formatAbsoluteDate(
    DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
    includeTime: includeTime,
  );
}

/// Parse a GB text field value and convert to bytes.
/// Returns null if the text is empty, non-numeric, or <= 0.
int? quotaGbToBytes(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final gb = double.tryParse(trimmed);
  if (gb == null || gb <= 0) return null;
  return (gb * 1024 * 1024 * 1024).round();
}

/// Convert bytes to a GB string for display in quota text fields.
String quotaBytesToGb(int bytes) {
  return (bytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
}

String _isoDate(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
