import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'file_actions_sheet.dart';

/// Floating action button that opens the "Create Folder / Upload /
/// Take Photo" bottom sheet. Hidden while the screen is in selection
/// mode (batch actions live in the app bar there instead).
class FilesFab extends StatelessWidget {
  final bool busy;
  final VoidCallback onCreateFolder;
  final VoidCallback onUploadFile;
  final VoidCallback onUploadPhoto;
  final VoidCallback onTakePhoto;

  const FilesFab({
    super.key,
    required this.busy,
    required this.onCreateFolder,
    required this.onUploadFile,
    required this.onUploadPhoto,
    required this.onTakePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      key: const Key('filesFab'),
      onPressed: busy
          ? null
          : () {
              final isDesktop =
                  Platform.isMacOS || Platform.isWindows || Platform.isLinux;
              showFabMenuSheet(
                context: context,
                onCreateFolder: onCreateFolder,
                onUploadFile: onUploadFile,
                onUploadPhoto: isDesktop ? null : onUploadPhoto,
                onTakePhoto: isDesktop ? null : onTakePhoto,
              );
            },
      child: const Icon(Icons.add),
    );
  }
}
