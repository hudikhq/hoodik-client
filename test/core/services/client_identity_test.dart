import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/services/client_identity.dart';

void main() {
  test('the header name is the one the server reads', () {
    // Spelled out rather than derived: the server matches this string, and a
    // rename on one side alone is the failure this pins.
    expect(clientIdentityHeader, 'X-Hoodik-Client');
  });

  test('identifies the caller as the app even before startup ran', () {
    // loadClientIdentity has not run here, which is also what a request sent
    // during startup would see. Versionless, never a guessed number.
    expect(clientIdentity, startsWith('app'));
  });

  test('every request carries it', () {
    final client = ApiClient.createTemporary(
      baseUrl: 'https://example.invalid',
    );

    expect(client.dio.options.headers[clientIdentityHeader], clientIdentity);
  });
}
