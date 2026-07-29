import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../shares/widgets/share_dialog.dart';
import '../providers/files_notifier.dart';
import 'decrypt_name.dart';

/// Open the right share surface for [file]: a folder routes to the dedicated
/// members screen (roster, roles, cascade-aware revoke), a file opens the
/// recipient dialog. Kept out of `FilesScreen` so that god-class stays under
/// the file-size ceiling rather than growing with each share entry point.
void openShareSurface(
  BuildContext context,
  WidgetRef ref, {
  required String? dirId,
  required FileItem file,
}) {
  if (file.isDir) {
    // The notifier's decrypted-name cache can be empty for a folder reached
    // from "Shared with me" (its names decrypt in a worker that may not have
    // run yet), which leaves the members screen titled "[Encrypted] …".
    // Decrypt on demand from the row's own key, falling back to the cache.
    final name =
        decryptOwnName(ref.read(fileCryptoProvider), file) ??
        ref.read(filesNotifierProvider(dirId)).displayName(file);
    context.push(
      '/shares/folder/${file.id}/members?name=${Uri.encodeQueryComponent(name)}',
    );
    return;
  }
  showShareDialog(context: context, ref: ref, dirId: dirId, file: file);
}
