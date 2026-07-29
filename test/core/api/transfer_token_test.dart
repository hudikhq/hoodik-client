import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/transfer_token.dart';

void main() {
  group('TransferToken', () {
    test('fromJson parses all fields', () {
      final json = {
        'token': 'eyJhbGciOiJIUzI1NiJ9.test',
        'expires_at': 1717200000,
        'file_id': 'abc-123',
        'action': 'upload',
      };

      final token = TransferToken.fromJson(json);

      expect(token.token, 'eyJhbGciOiJIUzI1NiJ9.test');
      expect(token.expiresAt, 1717200000);
      expect(token.fileId, 'abc-123');
      expect(token.action, 'upload');
    });

    test('fromJson works for download action', () {
      final json = {
        'token': 'jwt.download.token',
        'expires_at': 1717300000,
        'file_id': 'def-456',
        'action': 'download',
      };

      final token = TransferToken.fromJson(json);

      expect(token.action, 'download');
      expect(token.fileId, 'def-456');
    });
  });
}
