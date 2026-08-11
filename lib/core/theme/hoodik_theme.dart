import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/adaptive.dart';
import 'hoodik_colors.dart';
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

  static CupertinoThemeData cupertinoDark() {
    return const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: HoodikColors.redish400,
      scaffoldBackgroundColor: HoodikColors.brownish900,
      barBackgroundColor: HoodikColors.brownish800,
      textTheme: CupertinoTextThemeData(primaryColor: HoodikColors.textCrimson),
    );
  }

  /// Light theme is unused — the app hardcodes `ThemeMode.dark`.
  /// Returns the dark theme to avoid maintaining a dead code path.
  static CupertinoThemeData cupertinoLight() => cupertinoDark();

  static ThemeData dark() {
    const shape12 = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    const shape10 = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: _fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: HoodikColors.redish400,
        onPrimary: HoodikColors.white,
        primaryContainer: HoodikColors.redish700,
        onPrimaryContainer: HoodikColors.redish50,
        secondary: HoodikColors.orangy600,
        onSecondary: HoodikColors.white,
        secondaryContainer: HoodikColors.orangy800,
        onSecondaryContainer: HoodikColors.orangy50,
        tertiary: HoodikColors.greeny100,
        onTertiary: HoodikColors.greeny900,
        tertiaryContainer: HoodikColors.greeny700,
        onTertiaryContainer: HoodikColors.greeny50,
        surface: HoodikColors.brownish900,
        onSurface: HoodikColors.dirtyWhite,
        surfaceContainerHighest: HoodikColors.brownish600,
        error: HoodikColors.redish400,
        onError: HoodikColors.white,
      ),

      // Screen body — matches the notes editor's main area.
      scaffoldBackgroundColor: HoodikColors.brownish900,

      // App bar is one step lighter than the body, matching the notes
      // editor's sidebar/toolbar chrome. Height shrunk from Material's
      // default 56 to iOS-HIG 44 so the header doesn't eat screen real
      // estate on small phones.
      appBarTheme: const AppBarTheme(
        toolbarHeight: 44,
        backgroundColor: HoodikColors.brownish800,
        foregroundColor: HoodikColors.dirtyWhite,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
      ),

      cardTheme: CardThemeData(
        color: HoodikColors.brownish800,
        elevation: 0,
        shape: shape12,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: HoodikColors.redish400,
        foregroundColor: HoodikColors.white,
      ),

      // Bottom nav — same shade as the app bar so both chromes match.
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: HoodikColors.brownish800,
        indicatorColor: HoodikColors.redish700,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HoodikColors.brownish800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: HoodikColors.brownish500),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: HoodikColors.brownish500),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: HoodikColors.redish400, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        // Material defaults error text to `colorScheme.error`, which is the
        // crimson fill at 2.4:1 — legible as a background, not as the line
        // telling someone what they got wrong.
        errorStyle: const TextStyle(color: HoodikColors.textCrimson),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HoodikColors.redish400,
          foregroundColor: HoodikColors.white,
          shape: shape10,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: HoodikColors.textCrimson),
      ),

      dividerTheme: const DividerThemeData(
        color: HoodikColors.brownish600,
        thickness: 0.5,
        space: 0,
      ),

      // Dialogs match the app-bar shade — slightly raised off the body.
      dialogTheme: const DialogThemeData(
        backgroundColor: HoodikColors.brownish800,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: HoodikColors.dirtyWhite,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: HoodikColors.dirtyWhite,
          fontSize: 14,
        ),
        shape: shape12,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HoodikColors.brownish800,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: HoodikColors.brownish800,
        modalBarrierColor: Color(0x88000000),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      popupMenuTheme: const PopupMenuThemeData(
        color: HoodikColors.brownish800,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: shape10,
        textStyle: TextStyle(color: HoodikColors.dirtyWhite, fontSize: 14),
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: HoodikColors.brownish800,
        contentTextStyle: TextStyle(color: HoodikColors.dirtyWhite),
        actionTextColor: HoodikColors.textCrimson,
        behavior: SnackBarBehavior.floating,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: HoodikColors.brownish700,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(
          color: HoodikColors.dirtyWhite,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: HoodikColors.dirtyWhite,
        unselectedLabelColor: HoodikColors.textMuted,
        indicatorColor: HoodikColors.redish400,
        dividerColor: HoodikColors.brownish600,
      ),

      iconTheme: const IconThemeData(color: HoodikColors.dirtyWhite),

      listTileTheme: const ListTileThemeData(
        iconColor: HoodikColors.iconMuted,
        textColor: HoodikColors.dirtyWhite,
      ),

      cupertinoOverrideTheme: cupertinoDark(),

      // Widgets read semantic roles through `context.colors`; registering the
      // scheme here is what makes that resolve per appearance rather than
      // falling back to the dark constant.
      extensions: const [HoodikScheme.dark],
    );
  }

  /// Light theme is unused — the app hardcodes `ThemeMode.dark`.
  /// Returns the dark theme to avoid maintaining a dead code path.
  static ThemeData light() => dark();
}
