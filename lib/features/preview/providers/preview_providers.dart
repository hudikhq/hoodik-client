import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../services/preview_stream_server.dart';

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

final previewStreamServerProvider = Provider<PreviewStreamServer>((ref) {
  final server = PreviewStreamServer();
  ref.onDispose(server.stop);
  return server;
});

/// The type of preview widget to display for a given file.
enum PreviewType { image, video, audio, pdf, markdown, text, unsupported }

const _audioExtensions = {
  '.mp3',
  '.ogg',
  '.oga',
  '.opus',
  '.flac',
  '.wav',
  '.m4a',
  '.aac',
  '.wma',
  '.aiff',
  '.aif',
  '.alac',
  '.mka',
};

/// Determine the preview type from a MIME string.
///
/// Pass the optional [fileName] so `.md` files with a generic `text/plain`
/// MIME are correctly detected as markdown, and `.ogg`/`.opus` audio that
/// arrives as `application/octet-stream` is still recognised.
PreviewType getPreviewType(String mime, {String? fileName}) {
  final m = mime.toLowerCase();
  final name = fileName?.toLowerCase();

  // Markdown detection: explicit MIME or .md extension
  if (m == 'text/markdown') return PreviewType.markdown;
  if (name != null && name.endsWith('.md')) {
    return PreviewType.markdown;
  }

  if (m.startsWith('image/')) return PreviewType.image;
  if (m.startsWith('video/')) return PreviewType.video;
  if (m.startsWith('audio/')) return PreviewType.audio;
  if (m == 'application/pdf') return PreviewType.pdf;
  if (m.startsWith('text/')) return PreviewType.text;

  if (m == 'application/ogg' || m == 'application/x-ogg') {
    return PreviewType.audio;
  }

  if (name != null &&
      _audioExtensions.any((extension) => name.endsWith(extension))) {
    return PreviewType.audio;
  }

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

const int kPreviewPreloadMaxBytes = 5 * 1024 * 1024;

List<FileItem> previewPreloadCandidates(
  List<FileItem> files,
  int currentIndex, {
  int maxBytes = kPreviewPreloadMaxBytes,
}) {
  final candidates = <FileItem>[];
  for (final offset in const [-1, 1]) {
    final index = currentIndex + offset;
    if (index < 0 || index >= files.length) continue;
    final file = files[index];
    final size = file.size;
    if (size == null || size <= 0 || size > maxBytes) continue;
    if (file.isUploading) continue;
    candidates.add(file);
  }
  return candidates;
}
