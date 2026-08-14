import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/connect_link.dart';

ConnectLink? parse(String uri) => ConnectLink.parse(Uri.parse(uri));

void main() {
  group('ConnectLink.parse', () {
    test('reads the server and email a scanned code carries', () {
      final link = parse(
        'hoodik://connect#s=https%3A%2F%2Fabc123.eu.hoodik.cloud&e=tibor%40hudik.eu',
      );

      expect(link!.serverUrl, 'https://abc123.eu.hoodik.cloud');
      expect(link.email, 'tibor@hudik.eu');
    });

    test('accepts a code with no email', () {
      final link = parse('hoodik://connect#s=https%3A%2F%2Fdrive.example.com');

      expect(link!.serverUrl, 'https://drive.example.com');
      expect(link.email, isNull);
    });

    test('accepts http for self-hosted instances on a local network', () {
      expect(
        parse('hoodik://connect#s=http%3A%2F%2F192.168.1.10%3A5443'),
        isNotNull,
      );
    });

    test('rejects a server URL that is not http(s)', () {
      expect(parse('hoodik://connect#s=javascript%3Aalert(1)'), isNull);
      expect(parse('hoodik://connect#s=file%3A%2F%2F%2Fetc%2Fpasswd'), isNull);
    });

    test('rejects a missing or empty server', () {
      expect(parse('hoodik://connect#e=tibor%40hudik.eu'), isNull);
      expect(parse('hoodik://connect#s='), isNull);
      expect(parse('hoodik://connect'), isNull);
    });

    test('rejects links that are not connect links', () {
      expect(parse('hoodik://something#s=https%3A%2F%2Fexample.com'), isNull);
      expect(
        parse('https://hoodik.io/connect#s=https%3A%2F%2Fexample.com'),
        isNull,
      );
    });

    test('survives a malformed fragment instead of throwing', () {
      expect(parse('hoodik://connect#s=%ZZ'), isNull);
      expect(parse('hoodik://connect#=&&=='), isNull);
    });

    test('drops an email that is junk rather than prefilling it', () {
      final noAt = parse('hoodik://connect#s=https%3A%2F%2Fexample.com&e=nope');
      expect(noAt!.email, isNull);

      final tooLong = parse(
        'hoodik://connect#s=https%3A%2F%2Fexample.com&e=${'a' * 250}%40b.com',
      );
      expect(tooLong!.email, isNull);
    });
  });
}
