import 'package:flutter/material.dart';

import '../widgets/adaptive.dart';

/// The app's type scale, named by the job each role does.
///
/// DESIGN.md pins four roles for app surfaces — Title, Body, Label and Code —
/// and two rules that this file exists to make unbreakable:
///
/// * **No-Caps.** No uppercase transform and no letter-spaced labels anywhere.
///   Hierarchy comes from weight, size and color. A label is 12 at 600, not
///   small caps with tracking.
/// * **Honest Mono.** Monospace only where the user could type, run or verify
///   the thing on screen — commands, hashes, fingerprints, recovery keys.
///
/// Sizes stay at the app's established density rather than the marketing
/// scale: an Operate surface earns its scanability from a tight, consistent
/// ramp, and the standard leaves density to the platform. What changes is
/// that every value now has a name, so a screen can no longer invent one.
///
/// Nothing here clamps scaling. Flutter multiplies these by the reader's text
/// size at paint, and that is deliberate.
class HoodikType {
  HoodikType._();

  /// Font family — system (San Francisco) on Apple, Inter elsewhere.
  static String? get fontFamily => isApplePlatform ? null : 'Inter';

  /// Monospace, for the Honest Mono rule's content only.
  static const String monoFamily = 'monospace';

  /// Below this, iOS considers text illegible. Nothing in the ramp goes under.
  static const double minimumSize = 11;

  static TextTheme theme(Color text, Color muted) => TextTheme(
    // Titles — dialogs, sheets, panels, cards. Slight negative tracking is
    // the one place the standard allows any.
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: -0.25,
      color: text,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: text,
    ),
    titleSmall: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: text,
    ),

    // Body — DESIGN.md's 0.875rem app body, with its relaxed leading.
    bodyLarge: TextStyle(fontSize: 14, height: 1.625, color: text),
    // Dense rows and secondary paragraphs.
    bodyMedium: TextStyle(fontSize: 13, height: 1.5, color: text),
    // Metadata: timestamps, counts, the second line of a list row.
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: muted),

    // Labels — badges, chips, field labels, table headers. Weight carries
    // these, never tracking.
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: text,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: text,
    ),
    labelSmall: TextStyle(
      fontSize: minimumSize,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: muted,
    ),
  );

  /// Code, hashes, fingerprints and recovery keys. Tabular figures so columns
  /// of hex line up instead of shimmering.
  static TextStyle code(Color color, {double fontSize = 13}) => TextStyle(
    fontFamily: monoFamily,
    fontSize: fontSize,
    height: 1.6,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
