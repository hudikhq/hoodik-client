import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/theme/hoodik_colors.dart';
import 'package:hoodik_app/core/theme/hoodik_scheme.dart';
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

/// Worst ratio across every ground the scheme paints content on.
double _worst(HoodikScheme s, Color fg) => [
  s.canvas,
  s.panel,
  s.recess,
].map((bg) => contrast(fg, bg)).reduce(math.min);

void main() {
  // Both appearances answer to the same floors. Running the identical table
  // against each is what stops light shipping as a mechanical invert whose
  // text happens to land at 3:1.
  for (final theme in [
    (name: 'dark', scheme: HoodikScheme.dark),
    (name: 'light', scheme: HoodikScheme.light),
  ]) {
    final s = theme.scheme;

    group('${theme.name}: text roles clear 4.5:1 on every ground', () {
      final steps = {
        'text': s.text,
        'textMuted': s.textMuted,
        'textCrimson': s.textCrimson,
        'textSage': s.textSage,
        'textEmber': s.textEmber,
      };
      steps.forEach((name, color) {
        test(name, () {
          expect(
            _worst(s, color),
            greaterThanOrEqualTo(4.5),
            reason: '$name must read as body text on canvas, panel and recess.',
          );
        });
      });

      test('textDim clears the large-text floor', () {
        // Documented as large-text only, so it answers to 3:1.
        expect(_worst(s, s.textDim), greaterThanOrEqualTo(3.0));
      });
    });

    group('${theme.name}: icon roles clear 3:1 on every ground', () {
      final steps = {
        'iconMuted': s.iconMuted,
        'iconCrimson': s.iconCrimson,
        'iconSage': s.iconSage,
        'iconEmber': s.iconEmber,
        'iconSlate': s.iconSlate,
      };
      steps.forEach((name, color) {
        test(name, () {
          expect(
            _worst(s, color),
            greaterThanOrEqualTo(3.0),
            reason: 'An icon below 3:1 is invisible, not subtle.',
          );
        });
      });
    });

    group('${theme.name}: fills carry their own foreground', () {
      test('onFill reads on the crimson fill', () {
        expect(contrast(s.onFill, s.crimsonFill), greaterThanOrEqualTo(4.5));
      });
      test('onFill reads on the danger fill', () {
        expect(contrast(s.onFill, s.dangerFill), greaterThanOrEqualTo(4.5));
      });
      test('onCrimsonWash reads on the crimson wash', () {
        expect(
          contrast(s.onCrimsonWash, s.crimsonWash),
          greaterThanOrEqualTo(4.5),
        );
      });
      test('onCrimsonContainer reads on the crimson container', () {
        expect(
          contrast(s.onCrimsonContainer, s.crimsonContainer),
          greaterThanOrEqualTo(4.5),
        );
      });
      test('textSage reads on the sage wash', () {
        expect(contrast(s.textSage, s.sageWash), greaterThanOrEqualTo(4.5));
      });
    });

    test('${theme.name}: surfaces are distinguishable from each other', () {
      // Depth here is tonal, not shadow, so the steps have to actually differ.
      expect(s.canvas, isNot(s.panel));
      expect(s.panel, isNot(s.recess));
      expect(s.seam, isNot(s.seamStrong));
    });
  }

  group('the two appearances are genuinely different', () {
    test('light is lighter than dark on every surface', () {
      expect(
        _luminance(HoodikScheme.light.canvas),
        greaterThan(_luminance(HoodikScheme.dark.canvas)),
      );
      expect(
        _luminance(HoodikScheme.light.panel),
        greaterThan(_luminance(HoodikScheme.dark.panel)),
      );
    });

    test('text flips direction between them', () {
      expect(
        _luminance(HoodikScheme.light.text),
        lessThan(_luminance(HoodikScheme.dark.text)),
      );
    });

    test('the brand fill is the same in both', () {
      // The crimson mark should not shift with a system setting.
      expect(HoodikScheme.light.crimsonFill, HoodikScheme.dark.crimsonFill);
    });
  });

  group('fill steps are never mistaken for text steps', () {
    // The regression this guards is real: the app shipped `redish400` as a
    // text color in 12 places and an icon color in 15 more before the
    // 2026-08-11 contrast pass.
    const fills = {
      'redish400': HoodikColors.redish400,
      'brownish300': HoodikColors.brownish300,
      'brownish400': HoodikColors.brownish400,
    };
    fills.forEach((name, color) {
      test('$name stays sub-floor on dark', () {
        expect(
          _worst(HoodikScheme.dark, color),
          lessThan(4.5),
          reason:
              'If $name now clears 4.5:1 the palette changed — promote it to '
              'a text step deliberately rather than leaving this stale.',
        );
      });
    });
  });

  group('both ThemeData variants carry the scheme', () {
    test('dark', () {
      expect(
        HoodikTheme.dark().extension<HoodikScheme>(),
        same(HoodikScheme.dark),
      );
    });
    test('light', () {
      expect(
        HoodikTheme.light().extension<HoodikScheme>(),
        same(HoodikScheme.light),
      );
    });
    test('input error text clears the floor in both', () {
      for (final t in [HoodikTheme.dark(), HoodikTheme.light()]) {
        final s = t.extension<HoodikScheme>()!;
        final color = t.inputDecorationTheme.errorStyle?.color;
        expect(color, isNotNull);
        expect(_worst(s, color!), greaterThanOrEqualTo(4.5));
      }
    });
  });
}
