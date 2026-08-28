import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/mcp/mcp_client_configs.dart';

void main() {
  group('mcpServerKey', () {
    test('tibor@hudik.eu on drive.hoodik.io', () {
      expect(
        mcpServerKey(
          email: 'tibor@hudik.eu',
          serverUrl: 'https://drive.hoodik.io',
        ),
        'hoodik_tibor_at_hudik.eu_drive.hoodik.io',
      );
    });

    test('backup account on the same host is distinct', () {
      expect(
        mcpServerKey(
          email: 'backup@hudik.eu',
          serverUrl: 'https://drive.hoodik.io',
        ),
        'hoodik_backup_at_hudik.eu_drive.hoodik.io',
      );
    });

    test('self-host tailscale hostname', () {
      expect(
        mcpServerKey(
          email: 'tibor@hudik.eu',
          serverUrl: 'https://macbook.taild318f.ts.net',
        ),
        'hoodik_tibor_at_hudik.eu_macbook.taild318f.ts.net',
      );
    });

    test('drive.hudik.eu', () {
      expect(
        mcpServerKey(
          email: 'tibor@hudik.eu',
          serverUrl: 'https://drive.hudik.eu',
        ),
        'hoodik_tibor_at_hudik.eu_drive.hudik.eu',
      );
    });

    test('non-default port is kept, colon replaced', () {
      expect(
        mcpServerKey(
          email: 'tibor@hudik.eu',
          serverUrl: 'http://macbook.taild318f.ts.net:8080',
        ),
        'hoodik_tibor_at_hudik.eu_macbook.taild318f.ts.net_8080',
      );
    });

    test('falls back to hoodik when email and url are missing', () {
      expect(mcpServerKey(), 'hoodik');
    });
  });

  group('buildClientConfigSnippet', () {
    test('Claude/Cursor JSON is keyed by the account label', () {
      final snippet = buildClientConfigSnippet(
        kind: McpClientKind.claudeDesktop,
        port: 19548,
        bearerToken: 'tok',
        accountEmail: 'tibor@hudik.eu',
        serverUrl: 'https://drive.hoodik.io',
      );
      expect(snippet, contains('"hoodik_tibor_at_hudik.eu_drive.hoodik.io"'));
      expect(snippet, contains('http://127.0.0.1:19548/mcp'));
      expect(snippet, contains('Bearer tok'));
      expect(snippet, isNot(contains('"hoodik":')));
    });
  });
}
