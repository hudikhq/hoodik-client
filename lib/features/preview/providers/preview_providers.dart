import 'dart:typed_data';

import '../../../core/api/api_client.dart';

/// Context passed from the files screen to the preview screen.
///
/// Contains the list of previewable files in the current directory, along
/// with their decrypted names and symmetric keys.
class PreviewContext {
  final List<FileItem> files;
  final Map<String, String> names;
  final Map<String, Uint8List> keys;
  final String? parentDirId;

  const PreviewContext({
    required this.files,
    required this.names,
    required this.keys,
    this.parentDirId,
  });
}

/// The type of preview widget to display for a given file.
enum PreviewType { image, video, pdf, markdown, text, unsupported }

/// Determine the preview type from a MIME string.
///
/// Pass the optional [fileName] so `.md` files with a generic `text/plain`
/// MIME are correctly detected as markdown.
PreviewType getPreviewType(String mime, {String? fileName}) {
  final m = mime.toLowerCase();

  // Markdown detection: explicit MIME or .md extension
  if (m == 'text/markdown') return PreviewType.markdown;
  if (fileName != null && fileName.toLowerCase().endsWith('.md')) {
    return PreviewType.markdown;
  }

  if (m.startsWith('image/')) return PreviewType.image;
  if (m.startsWith('video/')) return PreviewType.video;
  if (m == 'application/pdf') return PreviewType.pdf;
  if (m.startsWith('text/')) return PreviewType.text;

  // Common code/config files that may not have a text/ MIME
  const textMimes = {
    'application/json',
    'application/xml',
    'application/javascript',
    'application/typescript',
    'application/x-yaml',
    'application/toml',
    'application/x-sh',
  };
  if (textMimes.contains(m)) return PreviewType.text;

  return PreviewType.unsupported;
}

/// Whether a file can be previewed.
///
/// Must not be a directory, must have finished uploading, and must have a
/// supported MIME type. Pass [fileName] for extension-based detection (e.g. `.md`).
bool isPreviewable(FileItem file, {String? fileName}) {
  if (file.isDir) return false;
  if (file.isUploading) return false;
  return getPreviewType(file.mime, fileName: fileName) !=
      PreviewType.unsupported;
}
