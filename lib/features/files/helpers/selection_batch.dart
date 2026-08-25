import '../../../core/api/api_client.dart';

const bulkConfirmMinFiles = 2;
const bulkLargeFileCount = 50;
const bulkLargeBytes = 500 * 1024 * 1024;

/// Files in a selection that export / offline can actually run on.
class SelectionBatch {
  final List<FileItem> files;
  final int folderCount;
  final int uploadCount;
  final int totalBytes;

  const SelectionBatch({
    required this.files,
    required this.folderCount,
    required this.uploadCount,
    required this.totalBytes,
  });

  factory SelectionBatch.resolve(
    Iterable<FileItem> listing,
    Set<String> selectedIds,
  ) {
    final files = <FileItem>[];
    var folderCount = 0;
    var uploadCount = 0;
    var totalBytes = 0;
    for (final file in listing) {
      if (!selectedIds.contains(file.id)) continue;
      if (file.isDir) {
        folderCount++;
        continue;
      }
      if (file.isUploading) {
        uploadCount++;
        continue;
      }
      files.add(file);
      totalBytes += file.size ?? 0;
    }
    return SelectionBatch(
      files: files,
      folderCount: folderCount,
      uploadCount: uploadCount,
      totalBytes: totalBytes,
    );
  }

  bool get isEmpty => files.isEmpty;
  bool get needsConfirm => files.length >= bulkConfirmMinFiles;
  bool get isLarge =>
      files.length > bulkLargeFileCount || totalBytes > bulkLargeBytes;
}
