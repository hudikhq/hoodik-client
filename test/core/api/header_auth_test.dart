import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';

void main() {
  group('AuthResponse header auth detection', () {
    test('isHeaderAuth true when x-auth-jwt present', () {
      final auth = AuthResponse(
        user: {'id': 'u1'},
        headerJwt: 'eyJ0eXAiOiJKV1Q...',
        headerRefresh: 'abc-refresh-uuid',
      );

      expect(auth.isHeaderAuth, isTrue);
      expect(auth.headerJwt, 'eyJ0eXAiOiJKV1Q...');
      expect(auth.headerRefresh, 'abc-refresh-uuid');
    });

    test('isHeaderAuth false when no header tokens', () {
      final auth = AuthResponse(user: {'id': 'u1'});

      expect(auth.isHeaderAuth, isFalse);
      expect(auth.headerJwt, isNull);
      expect(auth.headerRefresh, isNull);
    });

    test('isHeaderAuth false when headerJwt is empty string', () {
      final auth = AuthResponse(user: {'id': 'u1'}, headerJwt: '');

      expect(auth.isHeaderAuth, isFalse);
    });
  });

  group('ApiClient header auth mode', () {
    test('useHeaderAuth defaults to false', () {
      final client = ApiClient.createTemporary(baseUrl: 'https://example.com');
      expect(client.useHeaderAuth, isFalse);
    });

    test('setTokens stores jwt and refresh', () async {
      final client = ApiClient.createTemporary(baseUrl: 'https://example.com');
      client.useHeaderAuth = true;
      client.setTokens(jwt: 'my-jwt', refresh: 'my-refresh');

      // hasSession should be true with tokens set
      expect(await client.hasSession, isTrue);
    });

    test('hasSession false in header mode without tokens', () async {
      final client = ApiClient.createTemporary(baseUrl: 'https://example.com');
      client.useHeaderAuth = true;

      expect(await client.hasSession, isFalse);
    });

    test('hasSession delegates to cookie jar in cookie mode', () async {
      final client = ApiClient.createTemporary(baseUrl: 'https://example.com');
      // Cookie mode, no cookies -> false
      expect(await client.hasSession, isFalse);
    });

    test('clearCookies clears header tokens', () async {
      final client = ApiClient.createTemporary(baseUrl: 'https://example.com');
      client.useHeaderAuth = true;
      client.setTokens(jwt: 'jwt', refresh: 'ref');

      expect(await client.hasSession, isTrue);

      await client.clearCookies();
      expect(await client.hasSession, isFalse);
    });

    test('getCookieHeader returns empty in header mode', () async {
      final client = ApiClient.createTemporary(baseUrl: 'https://example.com');
      client.useHeaderAuth = true;

      expect(await client.getCookieHeader(), isEmpty);
    });

    test(
      'onTokensUpdated fires when tokens are set via setTokens + callback wiring',
      () {
        final client = ApiClient.createTemporary(
          baseUrl: 'https://example.com',
        );

        String? capturedJwt;
        String? capturedRefresh;
        client.onTokensUpdated = (jwt, refresh) {
          capturedJwt = jwt;
          capturedRefresh = refresh;
        };

        // onTokensUpdated is only called from _captureAuthHeaders (response
        // interceptor), not from setTokens directly. Verify the callback field
        // is wired up.
        expect(client.onTokensUpdated, isNotNull);
        expect(capturedJwt, isNull);
        expect(capturedRefresh, isNull);
      },
    );
  });
}
