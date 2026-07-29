import '../../../core/api/api_client.dart';
import '../../../core/api/shares_models.dart';
import '../../../core/crypto/file_crypto.dart';
import '../../../core/crypto/share_crypto.dart';

/// Hard cap on the file count a single folder share may carry, matching the
/// server's `entries_too_many` limit (`shares/src/repository/share.rs`). A
/// folder above this must be split before it can be shared.
const int subtreeHardCap = 5000;

/// Raised when a folder's subtree exceeds [subtreeHardCap]. The dialog turns
/// this into the "share a sub-folder instead" message rather than letting the
/// server reject the oversized request.
class SubtreeTooLarge implements Exception {
  SubtreeTooLarge(this.count);

  final int count;

  @override
  String toString() => 'SubtreeTooLarge($count)';
}

/// Walks a folder's full subtree and re-wraps every descendant's file key for
/// a share recipient. Mirrors `web/services/shares/subtree.ts` so the mobile
/// `entries` array matches the set the server reconstructs in
/// `verify_entries_match_subtree`: a folder share must carry one entry per file
/// in the tree, not just the root.
///
/// The decrypt-then-rewrap pair is two RSA operations per file, so this is the
/// dominant cost of a large folder share — the caller surfaces progress.
class FolderShareSubtree {
  FolderShareSubtree({
    required this.client,
    required this.fileCrypto,
    required this.shareCrypto,
  });

  final ApiClient client;

  /// Holds the caller's private key — used to unwrap each file's own key.
  final FileCrypto fileCrypto;

  /// Re-wraps each unwrapped key under the recipient's public key.
  final ShareCrypto shareCrypto;

  /// Collect [root] plus every descendant breadth-first. A non-directory root
  /// returns just itself. Throws [SubtreeTooLarge] before returning an oversize
  /// result so the caller never wraps keys for more files than the server
  /// accepts.
  Future<List<FileItem>> collect(FileItem root) async {
    final resolved = await _rootWithKey(root);
    final collected = <FileItem>[resolved];
    if (!resolved.isDir) return collected;

    final queue = <String>[resolved.id];
    while (queue.isNotEmpty) {
      final dirId = queue.removeAt(0);
      final response = await client.files.listFiles(dirId: dirId);
      for (final child in response.children) {
        collected.add(child);
        if (collected.length > subtreeHardCap) {
          throw SubtreeTooLarge(collected.length);
        }
        if (child.isDir) queue.add(child.id);
      }
    }
    return collected;
  }

  /// The folder share surface reaches the controller via a route that carries
  /// only the folder id, so [root] can arrive without its own `encrypted_key`.
  /// Re-wrapping the subtree needs every node's key — the root included — so
  /// recover it from the file's metadata when absent. Child nodes always carry
  /// their key from `listFiles`.
  Future<FileItem> _rootWithKey(FileItem root) async {
    final key = root.encryptedKey;
    if (key != null && key.isNotEmpty) return root;
    return FileItem.fromJson(await client.files.getFileMetadata(root.id));
  }

  /// Build the `entries` array for a recipient by unwrapping each file's own
  /// key and re-wrapping it under [recipient]'s key. [onProgress] fires after
  /// every file so the UI can render a determinate bar.
  ///
  /// A file whose key can't be unwrapped (missing or corrupt `encrypted_key`)
  /// throws — the server requires an entry for every file in the subtree, so a
  /// silent skip would fail `entries_do_not_match_subtree` rather than degrade.
  List<ShareEntryInput> buildEntries(
    List<FileItem> subtree,
    DiscoveredUser recipient, {
    void Function(int done, int total)? onProgress,
  }) {
    final entries = <ShareEntryInput>[];
    for (var i = 0; i < subtree.length; i++) {
      final node = subtree[i];
      final encryptedKey = node.encryptedKey;
      if (encryptedKey == null || encryptedKey.isEmpty) {
        throw StateError('File ${node.id} has no key to re-wrap for sharing.');
      }
      final fileKey = fileCrypto.decryptFileKey(encryptedKey);
      final wrap = shareCrypto.wrapForRecipient(
        fileKey: fileKey,
        recipientPubkey: recipient.pubkey,
        recipientKeyType: recipient.keyType,
        recipientWrappingPubkey: recipient.wrappingPubkey,
      );
      entries.add(ShareEntryInput(fileId: node.id, encryptedKey: wrap));
      onProgress?.call(i + 1, subtree.length);
    }
    return entries;
  }

  /// Build the `entries` array for a folder cascade move into a shared folder:
  /// one [CascadeEntry] per node, each carrying that node's file key wrapped
  /// once per [members] recipient. The server recomputes the subtree and
  /// requires an entry for every node, so a node whose key can't be unwrapped
  /// throws rather than being skipped.
  ///
  /// Each node's key is decrypted once and re-wrapped for every member, so the
  /// cost is `subtree` RSA decrypts plus `subtree × members` RSA wraps — the
  /// dominant cost of a large move, hence [onProgress] firing per node.
  /// [callerId] marks the caller's own row on each node with `is_owner_of_file`,
  /// matching the single-file move path the server inherits σ_member from.
  List<CascadeEntry> buildCascadeEntries(
    List<FileItem> subtree,
    List<FolderMember> members, {
    required String callerId,
    void Function(int done, int total)? onProgress,
  }) {
    final entries = <CascadeEntry>[];
    for (var i = 0; i < subtree.length; i++) {
      final node = subtree[i];
      final encryptedKey = node.encryptedKey;
      if (encryptedKey == null || encryptedKey.isEmpty) {
        throw StateError('File ${node.id} has no key to re-wrap for sharing.');
      }
      final fileKey = fileCrypto.decryptFileKey(encryptedKey);
      final memberKeys = members
          .map(
            (m) => MemberKey(
              userId: m.userId,
              encryptedKey: shareCrypto.wrapForRecipient(
                fileKey: fileKey,
                recipientPubkey: m.pubkey,
                recipientKeyType: m.keyType,
                recipientWrappingPubkey: m.wrappingPubkey,
              ),
              isOwnerOfFile: m.userId == callerId,
            ),
          )
          .toList();
      entries.add(CascadeEntry(fileId: node.id, memberKeys: memberKeys));
      onProgress?.call(i + 1, subtree.length);
    }
    return entries;
  }
}
