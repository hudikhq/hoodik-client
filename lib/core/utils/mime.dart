/// Small extension-to-MIME lookup for paths the OS hasn't already labelled.
///
/// Uploads pass the guessed type into [FileOperations.createFileEntry] so the
/// server stores a usable `mime` column. Unknown extensions fall back to
/// `application/octet-stream`, matching the web frontend's behaviour and
/// letting callers still tell "known" from "unknown" at a glance.
String guessMimeFromFileName(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  return _mimeByExtension[ext] ?? 'application/octet-stream';
}

const Map<String, String> _mimeByExtension = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'svg': 'image/svg+xml',
  'bmp': 'image/bmp',
  'ico': 'image/x-icon',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'avi': 'video/x-msvideo',
  'mkv': 'video/x-matroska',
  'webm': 'video/webm',
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
  'flac': 'audio/flac',
  'aac': 'audio/aac',
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'zip': 'application/zip',
  'tar': 'application/x-tar',
  'gz': 'application/gzip',
  'rar': 'application/vnd.rar',
  '7z': 'application/x-7z-compressed',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'html': 'text/html',
  'css': 'text/css',
  'js': 'application/javascript',
  'json': 'application/json',
  'xml': 'application/xml',
  'md': 'text/markdown',
  'yaml': 'text/yaml',
  'yml': 'text/yaml',
  'toml': 'application/toml',
  'rs': 'text/x-rust',
  'dart': 'text/x-dart',
  'py': 'text/x-python',
};
