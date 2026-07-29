import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Platform-appropriate biometric icon.
IconData biometricIcon() {
  if (Platform.isIOS || Platform.isMacOS) {
    return CupertinoIcons.person_crop_circle;
  }
  return Icons.fingerprint;
}

/// Platform-appropriate biometric label.
/// Set [withUsePrefix] to true for action buttons ("Use Face ID / Touch ID").
String biometricLabel({bool withUsePrefix = false}) {
  if (Platform.isIOS || Platform.isMacOS) {
    return withUsePrefix ? 'Use Face ID / Touch ID' : 'Face ID / Touch ID';
  }
  return withUsePrefix ? 'Use Biometric' : 'Biometric Unlock';
}
