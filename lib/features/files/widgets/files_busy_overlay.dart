import 'package:flutter/material.dart';

/// Dimmed backdrop that blocks input while a mutation is in flight.
///
/// The picker's load phase used to render here too; it shows as a row in
/// the transfer overlay now, so a slow iCloud export no longer locks the
/// screen.
class FilesBusyOverlay extends StatelessWidget {
  final bool busy;

  const FilesBusyOverlay({super.key, this.busy = false});

  @override
  Widget build(BuildContext context) {
    if (!busy) return const SizedBox.shrink();

    return Container(
      color: Colors.black54,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
