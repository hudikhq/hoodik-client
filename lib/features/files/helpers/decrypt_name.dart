import '../../../core/api/api_client.dart';
import '../../../core/crypto/file_crypto.dart';

/// Decrypt [file]'s name from the wrapped key the row carries, or null when the
/// row has no key/name, [fileCrypto] is unavailable, or decryption fails.
///
/// For surfaces where the listing's decrypt cache can miss — a folder reached
/// from "Shared with me", a drop onto a folder shown outside the current
/// listing — so the real name shows instead of the "[Encrypted]" placeholder.
/// Callers fall back to their own cache or placeholder on null.
String? decryptOwnName(FileCrypto? fileCrypto, FileItem file) {
  final encryptedKey = file.encryptedKey;
  if (fileCrypto == null ||
      encryptedKey == null ||
      encryptedKey.isEmpty ||
      file.encryptedName.isEmpty) {
    return null;
  }
  try {
    return fileCrypto.decryptFileName(
      encryptedNameHex: file.encryptedName,
      fileKey: fileCrypto.decryptFileKey(encryptedKey),
      cipher: file.cipher,
    );
  } catch (_) {
    return null;
  }
}
