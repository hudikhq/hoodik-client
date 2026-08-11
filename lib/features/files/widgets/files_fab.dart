import 'package:flutter/material.dart';
import '../../../core/widgets/app_icons.dart';

/// Floating action button that opens the create/upload sheet. Hidden while
/// the screen is in selection mode (batch actions live in the app bar
/// there instead).
class FilesFab extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;

  const FilesFab({super.key, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      key: const Key('filesFab'),
      onPressed: busy ? null : onPressed,
      child: Icon(AppIcons.add),
    );
  }
}
