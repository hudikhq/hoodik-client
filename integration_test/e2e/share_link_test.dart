import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../fixtures.dart';
import 'test_env.dart';
import 'test_hooks.dart';

/// Flow for public link creation + anonymous consumption.
///
/// Upload, create link (fragment-only key), then as an anonymous client:
/// fetch metadata, unwrap the real file key with the link key (client only),
/// fetch raw ciphertext from the content endpoint (server sends no plaintext),
/// and decrypt client-side using the file cipher + unwrapped key.
///
/// The final plaintext bytes must match the original upload.
/// The link key lives only in the fragment (never query or body for content).
///
/// This exercises the E2EE closure for public links: server never decrypts.
void main() {
  late Fixtures fixtures;

  patrolSetUp(() async {
    fixtures = await Fixtures.prepare();
    await TestHooks.wipeLocalState();
  });

  patrolTearDown(() async {
    await fixtures.cleanup();
  });

  patrolTest(
    'share link carries key in fragment and downloads matching bytes',
    ($) async {
      unawaited(app.main());
      await $.pumpAndSettle();

      await TestHooks.onboardAndLogin(
        $,
        TestEnv.serverUrl,
        TestEnv.email,
        TestEnv.password,
        TestEnv.pin,
      );

      await TestHooks.openUploadPicker($);
      final fixtureName = fixtures.png2mb.uri.pathSegments.last;
      await $.waitUntilVisible(
        $(fixtureName),
        timeout: const Duration(seconds: 60),
      );

      await $(fixtureName).longPress();
      await $('Create Link').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));

      final linkUrl = _extractDialogLink($);
      expect(
        linkUrl,
        isNotNull,
        reason: 'Link Created dialog must render a URL',
      );

      final uri = Uri.parse(linkUrl!);
      expect(
        uri.fragment.isNotEmpty,
        isTrue,
        reason: 'link key MUST ride in the URL fragment',
      );
      expect(
        uri.queryParameters,
        isEmpty,
        reason: 'link key MUST NEVER appear as a query parameter',
      );

      final downloaded = await _downloadAnonymous(uri);
      final originalHash = crypto.sha256.convert(
        await fixtures.png2mb.readAsBytes(),
      );
      final downloadedHash = crypto.sha256.convert(downloaded);
      expect(
        downloadedHash,
        equals(originalHash),
        reason: 'anonymous link download must yield byte-identical content',
      );
    },
  );
}

String? _extractDialogLink(PatrolIntegrationTester $) {
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    final data = widget.data;
    if (data != null && data.contains('#') && data.contains('://')) {
      return data;
    }
  }
  return null;
}

Future<List<int>> _downloadAnonymous(Uri linkUri) async {
  final dio = Dio(
    BaseOptions(
      responseType: ResponseType.bytes,
      followRedirects: true,
      validateStatus: (_) => true,
    ),
  );

  final linkId = linkUri.pathSegments.last;
  final linkKeyHex = linkUri.fragment;
  if (linkKeyHex.isEmpty) {
    throw StateError('public link key must be present in URL fragment');
  }
  final linkKey = _hexDecode(linkKeyHex);

  // 1. Metadata is public and carries the encrypted_file_key + file_cipher.
  //    Recipient uses the fragment linkKey to unwrap client-side (E2EE).
  final metaUrl = '${linkUri.origin}/api/links/$linkId/metadata';
  final metaResp = await dio.get<Map<String, dynamic>>(metaUrl);
  if (metaResp.statusCode != 200 || metaResp.data == null) {
    throw StateError('failed to fetch link metadata');
  }
  final meta = metaResp.data!;
  final encryptedFileKey = meta['encrypted_file_key'] as String;
  final fileCipher = (meta['file_cipher'] as String?) ?? 'aegis256';

  // 2. Unwrap the real file key using the link key (ascon layer, client only).
  final cryptoSvc = const CryptoService();
  final fileKeyCt = _hexDecode(encryptedFileKey);
  final fileKeyInner = cryptoSvc.symmetricDecrypt(
    cipher: 'ascon128a',
    key: linkKey,
    ciphertext: fileKeyCt,
  );
  final fileKeyHex = utf8.decode(fileKeyInner);
  final fileKey = _hexDecode(fileKeyHex);

  // 3. Fetch raw ciphertext from the content endpoint.
  //    No link_key is sent; server must not decrypt (E2EE closure).
  final contentUrl = '${linkUri.origin}/api/links/$linkId';
  final contentResp = await dio.post<List<int>>(
    contentUrl,
    // empty body — link_key is deliberately omitted
    options: Options(responseType: ResponseType.bytes),
  );
  if (contentResp.statusCode != 200) {
    File('${Directory.systemTemp.path}/share_link_err.txt').writeAsStringSync(
      'status=${contentResp.statusCode} body=${contentResp.data}',
    );
    throw StateError(
      'anonymous content download failed: ${contentResp.statusCode}',
    );
  }

  final ct = Uint8List.fromList(contentResp.data!);

  // 4. Client decrypts the actual file content using the file cipher + unwrapped key.
  final plaintext = cryptoSvc.symmetricDecrypt(
    cipher: fileCipher,
    key: fileKey,
    ciphertext: ct,
  );

  return plaintext.toList();
}

Uint8List _hexDecode(String hex) {
  final result = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(result);
}
