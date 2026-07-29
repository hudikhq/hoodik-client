import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';
import 'package:hoodik_app/src/rust/api.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('Rust crypto roundtrip', (WidgetTester tester) async {
    final keypair = generateRsaKeypair();
    expect(keypair.privateKeyPem.contains('BEGIN RSA PRIVATE KEY'), true);
    expect(keypair.publicKeyPem.contains('BEGIN RSA PUBLIC KEY'), true);
    expect(keypair.fingerprint.isNotEmpty, true);
  });
}
