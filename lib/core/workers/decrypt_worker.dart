import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import '../../src/rust/api.dart' as rust;
import '../../src/rust/frb_generated.dart';
import '../crypto/pem_key_type.dart';
import '../utils/hex.dart' as hex_utils;
import '../utils/log_redact.dart';
import '../utils/logger.dart';
import 'worker_messages.dart';

const _log = Logger('DecryptWorker');

/// Entry point for the decrypt worker isolate.
///
/// Batch-decrypts file names and keys off the main thread to avoid UI jank
/// when listing directories with many files.
void decryptWorkerEntryPoint(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  bool initialized = false;

  receivePort.listen((message) async {
    if (message is InitCommand) {
      try {
        await RustLib.init();
        initialized = true;
        message.replyPort.send(InitReadyResponse());
      } catch (e) {
        message.replyPort.send(
          WorkerErrorResponse(error: 'Decrypt worker init failed: $e'),
        );
      }
      return;
    }

    if (!initialized) return;

    if (message is PingCommand) {
      mainSendPort.send(PongResponse());
      return;
    }

    if (message is DecryptNamesCommand) {
      _handleDecryptNames(message, mainSendPort);
    }
  });

  // Send our ReceivePort back so the main isolate can send us commands.
  mainSendPort.send(receivePort.sendPort);
}

void _handleDecryptNames(DecryptNamesCommand cmd, SendPort replyPort) {
  final names = <String, String>{};
  final keys = <String, Uint8List>{};

  // Migrated curve25519 accounts wrap file keys with the hybrid key; legacy
  // accounts use RSA. The wrapping key's presence alongside a non-RSA identity key is
  // the same discriminator FileCrypto.decryptFileKey uses.
  final isCurve =
      cmd.wrappingPrivateKeyPem != null && pemIsCurve(cmd.privateKeyPem);

  for (final file in cmd.files) {
    try {
      final Uint8List keyBytes;
      if (isCurve) {
        // The hybrid unwrap returns the raw file key bytes directly.
        keyBytes = rust.wrappingUnwrap(
          blob: file.encryptedKey,
          privatePem: cmd.wrappingPrivateKeyPem!,
        );
      } else {
        final hexKey = rust.rsaDecrypt(
          ciphertextB64: file.encryptedKey,
          privateKeyPem: cmd.privateKeyPem,
        );
        keyBytes = _hexDecode(hexKey);
      }
      keys[file.id] = keyBytes;

      // Symmetric decrypt the file name; the string variant handles both the
      // prepended random nonce and the legacy embedded-nonce layout.
      final ciphertext = _hexDecode(file.encryptedName);
      final plaintext = rust.cipherDecryptString(
        cipher: file.cipher,
        key: keyBytes,
        ciphertext: ciphertext,
      );

      names[file.id] = utf8.decode(plaintext);
    } catch (e) {
      _log.warn(
        'failed to decrypt file',
        fields: {'file_id': file.id, 'error': redactException(e)},
      );
    }
  }

  replyPort.send(DecryptedNamesResponse(names: names, keys: keys));
}

Uint8List _hexDecode(String hex) => hex_utils.hexDecode(hex);
