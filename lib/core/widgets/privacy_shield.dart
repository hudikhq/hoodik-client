import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/cupertino.dart';

import 'app_icons.dart';
import '../../core/theme/hoodik_scheme.dart';

/// Covers the app content with a blurred overlay whenever the app goes
/// out of focus on phones/tablets. Keeps sensitive data (file names,
/// note content, thumbnails) from leaking into the app switcher
/// snapshot, notification pull-downs, or briefly-on-top system UI.
///
/// Only active on iOS and Android — desktop OSes don't generate the
/// same kind of thumbnail previews, and blurring a desktop window every
/// time it loses focus would be annoying.
class PrivacyShield extends StatefulWidget {
  final Widget child;

  const PrivacyShield({super.key, required this.child});

  @override
  State<PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends State<PrivacyShield>
    with WidgetsBindingObserver {
  bool _shielded = false;

  bool get _mobileOnly => Platform.isIOS || Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_mobileOnly) return;

    // `inactive` fires when the app switcher is visible, a call comes
    // in, or control center / notification shade is pulled down.
    // `hidden` is iOS 17+ for about-to-background. `paused` fires once
    // the app is fully backgrounded. All three should obscure content.
    final shouldShield =
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused;

    if (shouldShield != _shielded) {
      setState(() => _shielded = shouldShield);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [widget.child, if (_shielded) const _ShieldOverlay()],
    );
  }
}

class _ShieldOverlay extends StatelessWidget {
  const _ShieldOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: ColoredBox(
            color: context.colors.canvas.withValues(alpha: 0.72),
            child: Center(
              child: Icon(
                Platform.isIOS ? CupertinoIcons.lock_fill : AppIcons.locked,
                size: 48,
                color: context.colors.iconEmber.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
