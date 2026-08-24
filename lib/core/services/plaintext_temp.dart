import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const plaintextTempDirName = 'hoodik_plaintext';

/// Override for tests. Null in production (uses [getTemporaryDirectory]).
Directory? plaintextTempRootOverride;

/// `{temp}/hoodik_plaintext/`. Created if missing.
Future<Directory> plaintextTempDirectory() async {
  final root = plaintextTempRootOverride ?? await getTemporaryDirectory();
  final dir = Directory(p.join(root.path, plaintextTempDirName));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// Unique path for a decrypted file: `{dir}/{fileId}_{basename}`.
///
/// Two files that share a display name cannot overwrite each other.
Future<String> plaintextTempPath({
  required String fileId,
  required String basename,
}) async {
  final dir = await plaintextTempDirectory();
  final safe = basename.replaceAll(RegExp(r'[/\\]'), '_');
  return p.join(dir.path, '${fileId}_$safe');
}

/// Delete and recreate the plaintext temp directory. Best-effort: never
/// throws into startup or logout.
Future<void> sweepPlaintextTemp() async {
  try {
    final root = plaintextTempRootOverride ?? await getTemporaryDirectory();
    final dir = Directory(p.join(root.path, plaintextTempDirName));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
  } catch (_) {}
}
