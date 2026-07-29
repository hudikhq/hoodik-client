import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Platform channel used to control the native macOS window.
///
/// Kept separate from title-updating helpers so callers that only need to
/// foreground the app don't have to import unrelated window-title logic.
const MethodChannel _windowChannel = MethodChannel('io.hoodik.app/window');

/// Bring the app window to the front on macOS.
///
/// Best-effort only:
/// - unminimizes the main window if needed
/// - makes it key/main
/// - activates the app so it becomes frontmost
///
/// Other platforms are currently no-ops.
Future<void> bringAppToFront() async {
  if (!Platform.isMacOS) return;

  try {
    await _windowChannel.invokeMethod('showAndActivate');
  } catch (_) {
    // Cosmetic/UX only — failure to foreground the window should never
    // break the caller's primary action.
  }
}
