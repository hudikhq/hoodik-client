import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';

/// The active language's strings for code that runs outside the widget tree
/// (services, isolate callbacks, notification helpers). `Intl.defaultLocale`
/// is kept in sync with the app locale by `main.dart`; widgets should keep
/// using `AppLocalizations.of(context)` instead.
AppLocalizations get ambientL10n {
  final code = Intl.defaultLocale?.split('_').first ?? 'en';
  try {
    return lookupAppLocalizations(Locale(code));
  } on FlutterError {
    return lookupAppLocalizations(const Locale('en'));
  }
}
