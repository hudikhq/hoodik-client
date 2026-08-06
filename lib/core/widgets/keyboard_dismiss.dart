import 'package:flutter/widgets.dart';

/// App-level tap-to-dismiss for the on-screen keyboard.
///
/// Installed once in each MaterialApp `builder` so every screen gets the
/// behavior without carrying its own GestureDetector. Translucent hit-test
/// behavior means it only receives taps no descendant claimed — buttons,
/// fields, and list rows keep winning the gesture arena, while taps on
/// empty space release focus and drop the keyboard.
class KeyboardDismissOnTap extends StatelessWidget {
  const KeyboardDismissOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
