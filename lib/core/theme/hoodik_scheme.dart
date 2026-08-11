import 'package:flutter/material.dart';

import 'hoodik_colors.dart';

/// The app's semantic colors, resolved per appearance.
///
/// [HoodikColors] holds the raw ramps; this holds what each role *means* and
/// which step that role takes in light and in dark. A widget asks for
/// `context.colors.textMuted` and gets a value that already clears its
/// contrast floor against the ground it will be painted on — which is the
/// only way one codebase renders two appearances without a second audit.
///
/// The dark values are the shipped app. The light values come from DESIGN.md's
/// Text Steps table and paper ramp, except for four neutral steps the standard
/// does not define yet — [recess], [seamStrong], [track] and [crimsonWash] —
/// which are interpolated within the paper ramp and marked below.
@immutable
class HoodikScheme extends ThemeExtension<HoodikScheme> {
  const HoodikScheme({
    required this.canvas,
    required this.panel,
    required this.recess,
    required this.seam,
    required this.seamStrong,
    required this.track,
    required this.text,
    required this.textMuted,
    required this.textDim,
    required this.textCrimson,
    required this.textSage,
    required this.textEmber,
    required this.iconMuted,
    required this.iconCrimson,
    required this.iconSage,
    required this.iconEmber,
    required this.iconSlate,
    required this.crimsonFill,
    required this.dangerFill,
    required this.sageFill,
    required this.emberFill,
    required this.onFill,
    required this.crimsonWash,
    required this.onCrimsonWash,
    required this.sageWash,
    required this.crimsonContainer,
    required this.onCrimsonContainer,
  });

  /// Page ground.
  final Color canvas;

  /// Raised surfaces: app bars, cards, dialogs, sheets, the rail.
  final Color panel;

  /// Sunken surfaces: pills, tooltips, code interiors.
  final Color recess;

  /// The default 1px border on every card, window and divider.
  final Color seam;

  /// Borders on secondary buttons and emphasized containers.
  final Color seamStrong;

  /// Progress tracks and disabled ink.
  final Color track;

  /// Headings and primary text.
  final Color text;

  /// Secondary text, metadata, field help. Clears 4.5:1 on every ground.
  final Color textMuted;

  /// Large muted paragraphs only — clears AA at large sizes, nothing smaller.
  final Color textDim;

  /// Links, errors, destructive verbs.
  final Color textCrimson;

  /// Success and verified states, as text.
  final Color textSage;

  /// Warnings and pending states, as text.
  final Color textEmber;

  /// Icons answer to 3:1 rather than 4.5:1, so they sit one step warmer than
  /// the matching text role and keep more of the brand.
  final Color iconMuted;
  final Color iconCrimson;
  final Color iconSage;
  final Color iconEmber;
  final Color iconSlate;

  /// Solid fills. These carry [onFill] and read the same in both appearances,
  /// because the brand mark should not shift with the system setting.
  final Color crimsonFill;
  final Color dangerFill;
  final Color sageFill;
  final Color emberFill;
  final Color onFill;

  /// Tinted ground for the fingerprint-mismatch banner, and its text.
  final Color crimsonWash;
  final Color onCrimsonWash;

  /// Tinted ground for a success badge.
  final Color sageWash;

  /// Deep crimson container: the selection indicator and the account avatar.
  /// A container, not a text step — it is filled and something sits on it.
  final Color crimsonContainer;
  final Color onCrimsonContainer;

  static const HoodikScheme dark = HoodikScheme(
    canvas: HoodikColors.brownish900,
    panel: HoodikColors.brownish800,
    recess: HoodikColors.brownish700,
    seam: HoodikColors.brownish600,
    seamStrong: HoodikColors.brownish500,
    track: HoodikColors.brownish400,
    text: HoodikColors.dirtyWhite,
    textMuted: HoodikColors.textMuted,
    textDim: HoodikColors.brownish100,
    textCrimson: HoodikColors.textCrimson,
    textSage: HoodikColors.greeny300,
    textEmber: HoodikColors.orangy400,
    iconMuted: HoodikColors.brownish100,
    iconCrimson: HoodikColors.redish200,
    iconSage: HoodikColors.greeny300,
    iconEmber: HoodikColors.orangy500,
    iconSlate: HoodikColors.blueish300,
    crimsonFill: HoodikColors.redish400,
    dangerFill: HoodikColors.redish500,
    sageFill: HoodikColors.greeny400,
    emberFill: HoodikColors.orangy600,
    onFill: HoodikColors.white,
    crimsonWash: HoodikColors.redish900,
    onCrimsonWash: HoodikColors.redish50,
    sageWash: HoodikColors.greeny900,
    crimsonContainer: HoodikColors.redish700,
    onCrimsonContainer: HoodikColors.dirtyWhite,
  );

  static const HoodikScheme light = HoodikScheme(
    canvas: HoodikColors.paper,
    panel: HoodikColors.paperRaised,
    recess: HoodikColors.paperSunken,
    seam: HoodikColors.paperEdge,
    seamStrong: HoodikColors.paperEdgeStrong,
    track: HoodikColors.paperTrack,
    text: HoodikColors.brownish700,
    textMuted: HoodikColors.brownish400,
    textDim: HoodikColors.brownish300,
    textCrimson: HoodikColors.redish700,
    textSage: HoodikColors.greeny500,
    textEmber: HoodikColors.orangy800,
    iconMuted: HoodikColors.brownish100,
    iconCrimson: HoodikColors.redish400,
    iconSage: HoodikColors.greeny400,
    // orangy600 measures 2.52:1 on Paper — below the icon floor — so light
    // ember icons take the same step as ember text.
    iconEmber: HoodikColors.orangy800,
    iconSlate: HoodikColors.blueish400,
    crimsonFill: HoodikColors.redish400,
    dangerFill: HoodikColors.redish500,
    sageFill: HoodikColors.greeny400,
    emberFill: HoodikColors.orangy600,
    onFill: HoodikColors.white,
    crimsonWash: HoodikColors.paperCrimsonWash,
    onCrimsonWash: HoodikColors.redish700,
    sageWash: HoodikColors.paperSageWash,
    crimsonContainer: HoodikColors.paperCrimsonWash,
    onCrimsonContainer: HoodikColors.redish700,
  );

  @override
  HoodikScheme copyWith({
    Color? canvas,
    Color? panel,
    Color? recess,
    Color? seam,
    Color? seamStrong,
    Color? track,
    Color? text,
    Color? textMuted,
    Color? textDim,
    Color? textCrimson,
    Color? textSage,
    Color? textEmber,
    Color? iconMuted,
    Color? iconCrimson,
    Color? iconSage,
    Color? iconEmber,
    Color? iconSlate,
    Color? crimsonFill,
    Color? dangerFill,
    Color? sageFill,
    Color? emberFill,
    Color? onFill,
    Color? crimsonWash,
    Color? onCrimsonWash,
    Color? sageWash,
    Color? crimsonContainer,
    Color? onCrimsonContainer,
  }) {
    return HoodikScheme(
      canvas: canvas ?? this.canvas,
      panel: panel ?? this.panel,
      recess: recess ?? this.recess,
      seam: seam ?? this.seam,
      seamStrong: seamStrong ?? this.seamStrong,
      track: track ?? this.track,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textDim: textDim ?? this.textDim,
      textCrimson: textCrimson ?? this.textCrimson,
      textSage: textSage ?? this.textSage,
      textEmber: textEmber ?? this.textEmber,
      iconMuted: iconMuted ?? this.iconMuted,
      iconCrimson: iconCrimson ?? this.iconCrimson,
      iconSage: iconSage ?? this.iconSage,
      iconEmber: iconEmber ?? this.iconEmber,
      iconSlate: iconSlate ?? this.iconSlate,
      crimsonFill: crimsonFill ?? this.crimsonFill,
      dangerFill: dangerFill ?? this.dangerFill,
      sageFill: sageFill ?? this.sageFill,
      emberFill: emberFill ?? this.emberFill,
      onFill: onFill ?? this.onFill,
      crimsonWash: crimsonWash ?? this.crimsonWash,
      onCrimsonWash: onCrimsonWash ?? this.onCrimsonWash,
      sageWash: sageWash ?? this.sageWash,
      crimsonContainer: crimsonContainer ?? this.crimsonContainer,
      onCrimsonContainer: onCrimsonContainer ?? this.onCrimsonContainer,
    );
  }

  @override
  HoodikScheme lerp(ThemeExtension<HoodikScheme>? other, double t) {
    if (other is! HoodikScheme) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return HoodikScheme(
      canvas: c(canvas, other.canvas),
      panel: c(panel, other.panel),
      recess: c(recess, other.recess),
      seam: c(seam, other.seam),
      seamStrong: c(seamStrong, other.seamStrong),
      track: c(track, other.track),
      text: c(text, other.text),
      textMuted: c(textMuted, other.textMuted),
      textDim: c(textDim, other.textDim),
      textCrimson: c(textCrimson, other.textCrimson),
      textSage: c(textSage, other.textSage),
      textEmber: c(textEmber, other.textEmber),
      iconMuted: c(iconMuted, other.iconMuted),
      iconCrimson: c(iconCrimson, other.iconCrimson),
      iconSage: c(iconSage, other.iconSage),
      iconEmber: c(iconEmber, other.iconEmber),
      iconSlate: c(iconSlate, other.iconSlate),
      crimsonFill: c(crimsonFill, other.crimsonFill),
      dangerFill: c(dangerFill, other.dangerFill),
      sageFill: c(sageFill, other.sageFill),
      emberFill: c(emberFill, other.emberFill),
      onFill: c(onFill, other.onFill),
      crimsonWash: c(crimsonWash, other.crimsonWash),
      onCrimsonWash: c(onCrimsonWash, other.onCrimsonWash),
      sageWash: c(sageWash, other.sageWash),
      crimsonContainer: c(crimsonContainer, other.crimsonContainer),
      onCrimsonContainer: c(onCrimsonContainer, other.onCrimsonContainer),
    );
  }
}

/// `context.colors.textMuted` — the way every widget reaches the scheme.
///
/// Falls back to the dark scheme when no theme carries the extension, which
/// only happens in a bare test harness; the app always registers both.
extension HoodikSchemeContext on BuildContext {
  HoodikScheme get colors =>
      Theme.of(this).extension<HoodikScheme>() ?? HoodikScheme.dark;
}
