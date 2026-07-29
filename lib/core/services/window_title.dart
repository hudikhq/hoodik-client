import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../theme/hoodik_colors.dart';

/// Platform channel used by [setWindowTitle] to push the current title
/// to the native macOS window. See `macos/Runner/MainFlutterWindow.swift`
/// for the handler.
const MethodChannel _channel = MethodChannel('io.hoodik.app/window');

/// ARGB value of [HoodikColors.redish400] — the app's primary brand
/// color. Precomputed because `setApplicationSwitcherDescription` needs
/// a non-null int; the Android-side JSON codec throws otherwise.
final int _kAppSwitcherTintArgb = HoodikColors.redish400.toARGB32();

/// Update the window chrome to reflect the given title.
///
/// - **macOS**: sets `NSWindow.title` (the label in the title bar and
///   window menu) via a method channel.
/// - **Android**: sets the app-switcher description (recent-apps card
///   label + accent color).
/// - **iOS / Windows / Linux**: currently no-op. Title bars on iOS are
///   the app bar, which we already paint from Flutter; Windows/Linux
///   support can be added by extending this helper when needed.
///
/// All failures are swallowed — a wrong/stale window title never
/// justifies interrupting the UI.
Future<void> setWindowTitle(String title) async {
  // Fire-and-forget — the Android platform channel returns a Future we
  // don't need to wait on, and the overall call is best-effort.
  //
  // Note: `primaryColor` MUST be non-null or Android's JSON codec
  // throws "Value null at primaryColor ... cannot be converted to int"
  // on every call (spams stderr indefinitely).
  unawaited(
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: title,
        primaryColor: _kAppSwitcherTintArgb,
      ),
    ),
  );

  if (Platform.isMacOS) {
    try {
      await _channel.invokeMethod('setTitle', title);
    } catch (_) {
      // Cosmetic — ignore.
    }
  }
}
