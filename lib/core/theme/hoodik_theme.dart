import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/adaptive.dart';
import 'hoodik_scheme.dart';

/// Hoodik's global theme.
///
/// The palette is modelled after the notes editor: a `brownish900` body
/// with `brownish800` chrome (app bars, bottom nav, dialogs, menus). The
/// redish family is the only action color — text buttons, indicators, and
/// snackbar actions included; orangy is reserved for warnings and signals
/// (dirty dots, saving spinners). Every component theme is filled in so
/// screens never need to hardcode a backgroundColor — the rare exceptions
/// should be commented explaining why the theme default wasn't enough.
class HoodikTheme {
  HoodikTheme._();

  /// Font family — system default (San Francisco) on Apple, Inter elsewhere.
  static String? get _fontFamily => isApplePlatform ? null : 'Inter';

  static CupertinoThemeData cupertinoDark() => CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: HoodikScheme.dark.crimsonFill,
    scaffoldBackgroundColor: HoodikScheme.dark.canvas,
    barBackgroundColor: HoodikScheme.dark.panel,
    textTheme: CupertinoTextThemeData(
      primaryColor: HoodikScheme.dark.textCrimson,
    ),
  );

  static CupertinoThemeData cupertinoLight() => CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: HoodikScheme.light.crimsonFill,
    scaffoldBackgroundColor: HoodikScheme.light.canvas,
    barBackgroundColor: HoodikScheme.light.panel,
    textTheme: CupertinoTextThemeData(
      primaryColor: HoodikScheme.light.textCrimson,
    ),
  );

  static ThemeData dark() => _build(HoodikScheme.dark, Brightness.dark);

  static ThemeData light() => _build(HoodikScheme.light, Brightness.light);

  static ThemeData _build(HoodikScheme c, Brightness brightness) {
    const shape12 = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    const shape10 = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _fontFamily,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.crimsonFill,
        onPrimary: c.onFill,
        primaryContainer: c.crimsonContainer,
        onPrimaryContainer: c.onCrimsonContainer,
        secondary: c.emberFill,
        onSecondary: c.onFill,
        secondaryContainer: c.textEmber,
        onSecondaryContainer: c.onFill,
        tertiary: c.sageFill,
        onTertiary: c.onFill,
        tertiaryContainer: c.sageWash,
        onTertiaryContainer: c.textSage,
        surface: c.canvas,
        onSurface: c.text,
        surfaceContainerHighest: c.seam,
        error: c.dangerFill,
        onError: c.onFill,
      ),

      // Screen body — matches the notes editor's main area.
      scaffoldBackgroundColor: c.canvas,

      // App bar is one step lighter than the body, matching the notes
      // editor's sidebar/toolbar chrome. Height shrunk from Material's
      // default 56 to iOS-HIG 44 so the header doesn't eat screen real
      // estate on small phones.
      appBarTheme: AppBarTheme(
        toolbarHeight: 44,
        backgroundColor: c.panel,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
      ),

      cardTheme: CardThemeData(color: c.panel, elevation: 0, shape: shape12),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.crimsonFill,
        foregroundColor: c.onFill,
      ),

      // Bottom nav — same shade as the app bar so both chromes match.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.panel,
        indicatorColor: c.crimsonContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.seamStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.seamStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.crimsonFill, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        // Material defaults error text to `colorScheme.error`, which is the
        // crimson fill at 2.4:1 — legible as a background, not as the line
        // telling someone what they got wrong.
        errorStyle: TextStyle(color: c.textCrimson),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.crimsonFill,
          foregroundColor: c.onFill,
          shape: shape10,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.textCrimson),
      ),

      dividerTheme: DividerThemeData(color: c.seam, thickness: 0.5, space: 0),

      // Dialogs match the app-bar shade — slightly raised off the body.
      dialogTheme: DialogThemeData(
        backgroundColor: c.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: c.text, fontSize: 14),
        shape: shape12,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.panel,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.panel,
        modalBarrierColor: Color(0x88000000),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: c.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: shape10,
        textStyle: TextStyle(color: c.text, fontSize: 14),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.panel,
        contentTextStyle: TextStyle(color: c.text),
        actionTextColor: c.textCrimson,
        behavior: SnackBarBehavior.floating,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.recess,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(color: c.text, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: c.text,
        unselectedLabelColor: c.textMuted,
        indicatorColor: c.crimsonFill,
        dividerColor: c.seam,
      ),

      iconTheme: IconThemeData(color: c.text),

      listTileTheme: ListTileThemeData(
        iconColor: c.iconMuted,
        textColor: c.text,
      ),

      cupertinoOverrideTheme: brightness == Brightness.dark
          ? cupertinoDark()
          : cupertinoLight(),

      // Widgets read semantic roles through `context.colors`; registering the
      // scheme here is what makes that resolve per appearance rather than
      // falling back to the dark constant.
      extensions: [c],
    );
  }
}
