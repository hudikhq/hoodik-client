import 'package:flutter/material.dart';

/// Reusable avatar that displays the first letter of the user's email
/// inside a [CircleAvatar]. Keeps the pattern consistent across all
/// screens that show a user identifier.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.email,
    required this.radius,
    this.backgroundColor,
    this.textColor,
  });

  /// The user's email address. The first character (uppercased) is displayed.
  /// Falls back to '?' when [email] is empty.
  final String email;

  /// Radius passed directly to [CircleAvatar.radius].
  final double radius;

  /// Background colour override. Defaults to
  /// `theme.colorScheme.primary.withValues(alpha: 0.15)`.
  final Color? backgroundColor;

  /// Text colour override. Defaults to `theme.colorScheme.primary`.
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ?? theme.colorScheme.primary.withValues(alpha: 0.15),
      child: Text(
        (email.isNotEmpty ? email[0] : '?').toUpperCase(),
        style: TextStyle(
          color: textColor ?? theme.colorScheme.primary,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
