import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/theme/hoodik_colors.dart';
import 'package:hoodik_app/core/theme/hoodik_theme.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) {
    v = v / 255;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.r * 255) +
      0.7152 * channel(c.g * 255) +
      0.0722 * channel(c.b * 255);
}

/// WCAG 2.1 contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// The two grounds the app renders content on: cards, sheets, dialogs and
/// app bars sit on `brownish800`; screen bodies sit on `brownish900`. Every
/// foreground below is measured against the worse of the two.
const _grounds = {
  'panel': HoodikColors.brownish800,
  'body': HoodikColors.brownish900,
};

double _worstRatio(Color fg) => _grounds.values
    .map((bg) => contrast(fg, bg))
    .reduce((a, b) => a < b ? a : b);

void main() {
  group('text steps clear the 4.5:1 floor', () {
    const steps = {
      'textMuted': HoodikColors.textMuted,
      'textCrimson': HoodikColors.textCrimson,
      'textSage': HoodikColors.textSage,
      'textEmber': HoodikColors.textEmber,
      'dirtyWhite': HoodikColors.dirtyWhite,
    };

    for (final entry in steps.entries) {
      test('${entry.key} on both grounds', () {
        expect(
          _worstRatio(entry.value),
          greaterThanOrEqualTo(4.5),
          reason:
              '${entry.key} must stay readable as body text on panel and body.',
        );
      });
    }
  });

  group('icon steps clear the 3:1 floor', () {
    const steps = {
      'iconMuted': HoodikColors.iconMuted,
      'iconCrimson': HoodikColors.iconCrimson,
      'greeny300': HoodikColors.greeny300,
      'orangy500': HoodikColors.orangy500,
      'blueish400': HoodikColors.blueish400,
    };

    for (final entry in steps.entries) {
      test('${entry.key} on both grounds', () {
        expect(
          _worstRatio(entry.value),
          greaterThanOrEqualTo(3.0),
          reason: 'An icon below 3:1 is invisible, not subtle.',
        );
      });
    }
  });

  group('fill steps are not mistaken for text steps', () {
    // These measure 2–3:1 and exist to be filled behind white, never to be
    // set as a foreground. The regression this guards against is real: the
    // app shipped `redish400` as a text color in 12 places and as an icon
    // color in 15 more before the 2026-08-11 contrast pass.
    const fills = {
      'redish400': HoodikColors.redish400,
      'brownish300': HoodikColors.brownish300,
      'brownish400': HoodikColors.brownish400,
    };

    for (final entry in fills.entries) {
      test('${entry.key} is documented as sub-floor', () {
        expect(
          _worstRatio(entry.value),
          lessThan(4.5),
          reason:
              'If ${entry.key} now clears 4.5:1 the palette changed — promote '
              'it to a text step deliberately rather than leaving this stale.',
        );
      });
    }

    test('white stays legible on the crimson fill', () {
      expect(
        contrast(HoodikColors.white, HoodikColors.redish400),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('theme wiring uses text steps for text', () {
    final theme = HoodikTheme.dark();

    test('snackbar action label clears the text floor', () {
      final color = theme.snackBarTheme.actionTextColor!;
      expect(
        contrast(color, HoodikColors.brownish800),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('unselected tab label clears the text floor', () {
      final color = theme.tabBarTheme.unselectedLabelColor!;
      expect(_worstRatio(color), greaterThanOrEqualTo(4.5));
    });

    test('input error text clears the text floor', () {
      final color = theme.inputDecorationTheme.errorStyle?.color;
      expect(
        color,
        isNotNull,
        reason:
            'Material defaults error text to colorScheme.error, which is a '
            'fill step at 2.4:1 — the theme must override it explicitly.',
      );
      expect(_worstRatio(color!), greaterThanOrEqualTo(4.5));
    });
  });
}
