import 'package:flutter/material.dart';

import '../../../core/theme/hoodik_colors.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart' as fmt;
import '../../shares/shared_constants.dart';
import '../../../core/widgets/app_icons.dart';

/// Format a byte count into a human-readable string (B, KB, MB, GB).
String formatFileSize(int? bytes) {
  return fmt.formatBytesOrEmpty(bytes);
}

/// Format a Unix timestamp (seconds) into a relative or absolute date string.
String formatFileDate(int? timestamp) {
  return fmt.formatRelativeTimestamp(timestamp, fallback: '');
}

/// Whether [file] is a markdown note.
///
/// Uses MIME type when set, falling back to the `.md` / `.markdown`
/// extension on [displayName] so notes still get recognized when a file
/// was uploaded with a generic `text/plain` MIME.
bool isMarkdownNote(FileItem file, {String? displayName}) {
  if (file.isDir) return false;
  final mime = file.mime.toLowerCase();
  if (mime == 'text/markdown' || mime.contains('markdown')) return true;
  if (displayName == null) return false;
  final lower = displayName.toLowerCase();
  return lower.endsWith('.md') || lower.endsWith('.markdown');
}

/// Return the appropriate icon for a file based on its type.
///
/// Pass [displayName] so markdown notes get recognized even when their
/// MIME is generic `text/plain`.
IconData fileIcon(FileItem file, {String? displayName}) {
  if (file.id == sharedWithMeDirId) return Icons.folder_shared;
  if (file.isDir) return AppIcons.folder;
  if (file.isUploading) return Icons.upload;
  if (isMarkdownNote(file, displayName: displayName)) {
    // Distinct icon (vs. plain-text .description) so notes stand out in
    // mixed file listings and match the Notes tab styling.
    return AppIcons.note;
  }
  final mime = file.mime.toLowerCase();
  if (mime.startsWith('image/')) return Icons.image;
  if (mime.startsWith('video/')) return Icons.videocam;
  if (mime.startsWith('audio/')) return Icons.audiotrack;
  if (mime.contains('pdf')) return Icons.picture_as_pdf;
  if (mime.contains('zip') || mime.contains('tar') || mime.contains('gz')) {
    return Icons.archive;
  }
  if (mime.contains('text')) return Icons.description;
  return Icons.insert_drive_file;
}

/// Return the icon color for a file based on its type.
///
/// Pass [displayName] so markdown notes pick up the notes accent color
/// (otherwise they'd share the generic blue with other files).
Color fileIconColor(FileItem file, {String? displayName}) {
  if (file.id == sharedWithMeDirId) return HoodikColors.blueish400;
  if (file.isDir) return HoodikColors.orangy600;
  if (file.isUploading) return HoodikColors.brownish50;
  if (isMarkdownNote(file, displayName: displayName)) {
    return HoodikColors.orangy500;
  }
  return HoodikColors.blueish400;
}

/// Strip the 'Exception: ' prefix from an error message.
String formatErrorMessage(Object e) {
  return e.toString().replaceFirst('Exception: ', '');
}

/// Rect for the iPad share-sheet popover, computed from [context]'s render
/// object. Callers compute it eagerly before any async gap so the render
/// object doesn't go stale; falls back to a zero-size rect at screen center
/// when the box isn't laid out yet.
Rect shareOriginRect(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize) {
    final position = box.localToGlobal(Offset.zero);
    return position & box.size;
  }
  final size = MediaQuery.of(context).size;
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 0,
    height: 0,
  );
}
