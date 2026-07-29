import 'dart:isolate';
import 'dart:typed_data';

/// Base class for all commands sent from the main isolate to workers.
sealed class WorkerCommand {}

/// Initialize a worker with shared state.
class InitCommand extends WorkerCommand {
  final SendPort replyPort;
  final String baseUrl;

  InitCommand({required this.replyPort, required this.baseUrl});
}

/// Serialized file metadata for batch name decryption.
class FileItemData {
  final String id;
  final String encryptedKey;
  final String encryptedName;
  final String cipher;

  FileItemData({
    required this.id,
    required this.encryptedKey,
    required this.encryptedName,
    required this.cipher,
  });
}

/// Batch-decrypt file names and keys (sent to the decrypt worker).
///
/// On a migrated curve25519 account the per-file key is hybrid-wrapped, so the
/// worker unwraps with [wrappingPrivateKeyPem]; on a legacy RSA account it is
/// null and the RSA identity key does the decrypt.
class DecryptNamesCommand extends WorkerCommand {
  final String privateKeyPem;
  final String? wrappingPrivateKeyPem;
  final List<FileItemData> files;

  DecryptNamesCommand({
    required this.privateKeyPem,
    this.wrappingPrivateKeyPem,
    required this.files,
  });
}

/// Download all encrypted chunks as a tar archive (no decryption).
///
/// The tar is fetched in a single HTTP request using `?format=tar`,
/// then extracted to individual `.enc` chunk files on disk. Decryption
/// happens later, on demand, via [decryptChunksToFile].
class DownloadChunksCommand extends WorkerCommand {
  final String fileId;
  final int totalChunks;
  final int fileSize;
  final String outputDir;
  final String transferToken;

  DownloadChunksCommand({
    required this.fileId,
    required this.totalChunks,
    required this.fileSize,
    required this.outputDir,
    required this.transferToken,
  });
}

/// Encrypt a local file into chunks on disk (sent to the encrypt worker).
///
/// Reads the source file, hashes it with SHA-256 (Dart crypto), encrypts
/// each chunk via Rust FFI, computes CRC-16 checksums, and writes the
/// encrypted chunks to [outputDir] as `{index:06}.enc`.
class EncryptFileCommand extends WorkerCommand {
  final String localPath;
  final String outputDir;
  final Uint8List fileKey;
  final String cipher;
  final int totalChunks;
  final int fileSize;

  /// Temporary ID used for progress tracking before the server file ID exists.
  final String tempFileId;

  EncryptFileCommand({
    required this.localPath,
    required this.outputDir,
    required this.fileKey,
    required this.cipher,
    required this.totalChunks,
    required this.fileSize,
    required this.tempFileId,
  });
}

/// Upload pre-encrypted chunks from disk (sent to the upload worker).
///
/// The upload worker reads `.enc` files and sends them with Bearer auth.
/// No encryption logic — pure HTTP.
class UploadChunksCommand extends WorkerCommand {
  final String fileId;
  final String chunksDir;
  final int totalChunks;
  final int fileSize;
  final String transferToken;
  final Map<int, String> checksums; // chunk index → CRC-16 hex
  final List<int> alreadyUploaded;

  UploadChunksCommand({
    required this.fileId,
    required this.chunksDir,
    required this.totalChunks,
    required this.fileSize,
    required this.transferToken,
    required this.checksums,
    this.alreadyUploaded = const [],
  });
}

/// Cancel an in-progress operation.
class CancelCommand extends WorkerCommand {
  final String fileId;

  CancelCommand({required this.fileId});
}

/// Health check request — worker should reply with [PongResponse].
class PingCommand extends WorkerCommand {}

/// Base class for all responses sent from workers back to the main isolate.
sealed class WorkerResponse {}

/// Worker has finished initialization and is ready for commands.
class InitReadyResponse extends WorkerResponse {}

/// Encrypted chunks have been saved to disk (no decryption performed).
class DownloadChunksCompleteResponse extends WorkerResponse {
  final String fileId;
  final String chunksDir;

  DownloadChunksCompleteResponse({
    required this.fileId,
    required this.chunksDir,
  });
}

/// Encryption of a file into chunks completed successfully.
class EncryptCompleteResponse extends WorkerResponse {
  final String tempFileId;
  final String sha256;
  final Map<int, String> checksums; // chunk index → CRC-16 hex

  EncryptCompleteResponse({
    required this.tempFileId,
    required this.sha256,
    required this.checksums,
  });
}

/// All pre-encrypted chunks have been uploaded.
class UploadChunksCompleteResponse extends WorkerResponse {
  final String fileId;

  UploadChunksCompleteResponse({required this.fileId});
}

/// Batch name decryption completed.
class DecryptedNamesResponse extends WorkerResponse {
  final Map<String, String> names;
  final Map<String, Uint8List> keys;

  DecryptedNamesResponse({required this.names, required this.keys});
}

/// Progress update for an in-flight transfer.
///
/// For downloads: [transferred] = bytes downloaded, [total] = total bytes.
/// For uploads: [transferred] = chunks completed, [total] = total chunks.
class TransferProgressResponse extends WorkerResponse {
  final String fileId;
  final int transferred;
  final int total;

  TransferProgressResponse({
    required this.fileId,
    required this.transferred,
    required this.total,
  });
}

/// Health check reply — confirms the worker isolate is alive and responsive.
class PongResponse extends WorkerResponse {}

/// An error occurred in the worker.
class WorkerErrorResponse extends WorkerResponse {
  final String? fileId;
  final String error;

  WorkerErrorResponse({this.fileId, required this.error});
}
