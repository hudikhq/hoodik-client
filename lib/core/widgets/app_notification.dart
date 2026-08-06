import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/hoodik_colors.dart';

/// Semantic type for in-app notifications.
enum NotificationType { success, error, info }

/// Top-positioned overlay notification that doesn't interfere with bottom UI.
///
/// Call [AppNotification.show] from anywhere with a valid [BuildContext].
/// Only one notification is visible at a time — showing a new one dismisses
/// the previous automatically.
class AppNotification {
  AppNotification._();

  static OverlayEntry? _currentEntry;
  static _AppNotificationState? _currentState;

  /// Show a notification banner at the top of the screen.
  static void show(
    BuildContext context, {
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Dismiss any existing notification immediately.
    dismiss();

    // A light tick for confirmations, a firm one for failures — the banner
    // is the app's single feedback surface, so this covers every flow.
    switch (type) {
      case NotificationType.success:
        HapticFeedback.lightImpact();
      case NotificationType.error:
        HapticFeedback.heavyImpact();
      case NotificationType.info:
        break;
    }

    final overlay = Overlay.of(context);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AppNotificationWidget(
        message: message,
        type: type,
        duration: duration,
        onDismissed: () {
          if (_currentEntry == entry) {
            _currentEntry?.remove();
            _currentEntry = null;
            _currentState = null;
          }
        },
        onStateCreated: (state) {
          if (_currentEntry == entry) {
            _currentState = state;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  /// Dismiss the current notification (if any) immediately.
  static void dismiss() {
    _currentState?.dismissNow();
    _currentState = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _AppNotificationWidget extends StatefulWidget {
  final String message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback onDismissed;
  final ValueChanged<_AppNotificationState> onStateCreated;

  const _AppNotificationWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismissed,
    required this.onStateCreated,
  });

  @override
  State<_AppNotificationWidget> createState() => _AppNotificationState();
}

class _AppNotificationState extends State<_AppNotificationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  Timer? _autoHideTimer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    widget.onStateCreated(this);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    _controller.forward();

    _autoHideTimer = Timer(widget.duration, () {
      if (mounted && !_dismissed) _animateOut();
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void dismissNow() {
    _dismissed = true;
    _autoHideTimer?.cancel();
  }

  void _animateOut() {
    _dismissed = true;
    _autoHideTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  Color get _accentColor => switch (widget.type) {
    NotificationType.success => HoodikColors.greeny300,
    NotificationType.error => HoodikColors.redish400,
    NotificationType.info => HoodikColors.brownish100,
  };

  IconData get _icon => switch (widget.type) {
    NotificationType.success => Icons.check_circle,
    NotificationType.error => Icons.error_outline,
    NotificationType.info => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Semantics(
          liveRegion: true,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 0),
              child: GestureDetector(
                onTap: _animateOut,
                child: Container(
                  decoration: BoxDecoration(
                    color: HoodikColors.brownish800,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: HoodikColors.brownish600,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        // Accent stripe
                        Container(width: 4, color: _accentColor),
                        const SizedBox(width: 12),
                        Icon(_icon, color: _accentColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              widget.message,
                              style: const TextStyle(
                                color: HoodikColors.dirtyWhite,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.close,
                          color: HoodikColors.brownish300,
                          size: 16,
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
