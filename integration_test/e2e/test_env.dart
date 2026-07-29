/// Shared environment + defaults for Patrol E2E tests (spec §4).
///
/// All values are overridable via `--dart-define=KEY=VALUE` so CI can
/// point at a different ephemeral server or demo credentials without
/// editing the test source.
class TestEnv {
  static const serverUrl = String.fromEnvironment(
    'HOODIK_E2E_URL',
    defaultValue: 'http://127.0.0.1:5443',
  );

  static const email = String.fromEnvironment(
    'HOODIK_E2E_EMAIL',
    defaultValue: 'e2e@hoodik.local',
  );

  static const password = String.fromEnvironment(
    'HOODIK_E2E_PASSWORD',
    defaultValue: 'e2e-user-password-1234',
  );

  static const pin = String.fromEnvironment(
    'HOODIK_E2E_PIN',
    defaultValue: '123456',
  );
}
