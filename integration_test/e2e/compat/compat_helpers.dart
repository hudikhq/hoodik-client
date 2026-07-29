import 'package:hoodik_app/core/auth/auth_service.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:patrol/patrol.dart';

import '../test_hooks.dart';

/// Which server features a given released hoodik tag ships. Consumed by
/// `integration_test/e2e/compat/*_test.dart` to decide whether a given
/// compat flow runs, skips, or asserts the fallback path kicked in.
///
/// Booleans are the only observable surface tests should branch on —
/// strings like "v1.9.0" belong inside this table, not in test bodies.
class ServerCapabilities {
  final String version;
  final bool hasTarUpload;
  final bool hasTarDownload;
  final bool hasVersioning;
  final bool hasEditableFiles;

  /// Account-to-account sharing (`/api/capabilities` advertising
  /// `sharing.enabled`, plus `move-into-shared` / `move-out-of-shared`). No
  /// released tag ships it yet — it's on master — so every matrix entry is
  /// false, which is exactly the absent-endpoint path the move funnel must
  /// degrade across.
  final bool hasSharing;

  const ServerCapabilities({
    required this.version,
    required this.hasTarUpload,
    required this.hasTarDownload,
    required this.hasVersioning,
    required this.hasEditableFiles,
    required this.hasSharing,
  });

  @override
  String toString() =>
      'ServerCapabilities($version, tarUpload=$hasTarUpload, '
      'tarDownload=$hasTarDownload, versioning=$hasVersioning, '
      'editable=$hasEditableFiles, sharing=$hasSharing)';
}

/// Version → capabilities table. Must cover every released `hudik/hoodik`
/// tag on Docker Hub, not just the ones in the `just e2e-compat-matrix`
/// loop. Tests that conditionally run on "any server without feature X"
/// rely on this table for the answer, so keep it complete:
///
/// * tar-upload route landed on master post-v1.14.1; no tag has it yet.
/// * tar-download (`GET ?format=tar`) shipped in v1.12.0 (PR #149).
/// * `files.editable` column + `set_editable` + `replace_content` shipped
///   in v1.14.0 (PR #153, "markdown editor A1").
/// * File versioning (A2) is still on master as of 2026-04-20, not tagged.
///
/// When bumping to add a new released tag:
///   1. Check `storage/src/routes/` for new route files.
///   2. Flip whichever booleans the release added.
///   3. Add the tag to `just e2e-compat-matrix` if it should be gated.
const _capabilityTable = <String, ServerCapabilities>{
  'v1.7.0': ServerCapabilities(
    version: 'v1.7.0',
    hasTarUpload: false,
    hasTarDownload: false,
    hasVersioning: false,
    hasEditableFiles: false,
    hasSharing: false,
  ),
  'v1.8.0': ServerCapabilities(
    version: 'v1.8.0',
    hasTarUpload: false,
    hasTarDownload: false,
    hasVersioning: false,
    hasEditableFiles: false,
    hasSharing: false,
  ),
  'v1.8.1': ServerCapabilities(
    version: 'v1.8.1',
    hasTarUpload: false,
    hasTarDownload: false,
    hasVersioning: false,
    hasEditableFiles: false,
    hasSharing: false,
  ),
  'v1.9.0': ServerCapabilities(
    version: 'v1.9.0',
    hasTarUpload: false,
    hasTarDownload: false,
    hasVersioning: false,
    hasEditableFiles: false,
    hasSharing: false,
  ),
  'v1.10.0': ServerCapabilities(
    version: 'v1.10.0',
    hasTarUpload: false,
    hasTarDownload: false,
    hasVersioning: false,
    hasEditableFiles: false,
    hasSharing: false,
  ),
  'v1.11.0': ServerCapabilities(
    version: 'v1.11.0',
    hasTarUpload: false,
    hasTarDownload: false,
    hasVersioning: false,
    hasEditableFiles: false,
    hasSharing: false,
  ),
  'v1.12.0': ServerCapabilities(
    version: 'v1.12.0',
    hasTarUpload: false,
    hasTarDownload: true,
    hasVersioning: false,
    hasEditableFiles: false,
    hasSharing: false,
  ),
  'v1.13.0': ServerCapabilities(
    version: 'v1.13.0',
    hasTarUpload: false,
    hasTarDownload: true,
    hasVersioning: false,
    hasEditableFiles: false,
    hasSharing: false,
  ),
  'v1.13.1': ServerCapabilities(
    version: 'v1.13.1',
    hasTarUpload: false,
    hasTarDownload: true,
    hasVersioning: false,
    hasEditableFiles: false,
    hasSharing: false,
  ),
  'v1.13.2': ServerCapabilities(
    version: 'v1.13.2',
    hasTarUpload: false,
    hasTarDownload: true,
    hasVersioning: false,
    hasEditableFiles: false,
    hasSharing: false,
  ),
  'v1.14.0': ServerCapabilities(
    version: 'v1.14.0',
    hasTarUpload: false,
    hasTarDownload: true,
    hasVersioning: false,
    hasEditableFiles: true,
    hasSharing: false,
  ),
  'v1.14.1': ServerCapabilities(
    version: 'v1.14.1',
    hasTarUpload: false,
    hasTarDownload: true,
    hasVersioning: false,
    hasEditableFiles: true,
    hasSharing: false,
  ),
};

/// Read the version the caller pinned this run to, fail loud when it's
/// missing. Passed via `--dart-define=SERVER_VERSION=vX.Y.Z` by the
/// `just e2e-compat` recipe. There's no safe default — a silent default
/// would report false-green after the recipe forgets to pass it.
ServerCapabilities loadCompatTarget() {
  const raw = String.fromEnvironment('SERVER_VERSION');
  if (raw.isEmpty) {
    throw StateError(
      'compat: --dart-define=SERVER_VERSION=<tag> is required. '
      "Run via 'just e2e-compat v1.9.0' or similar — tests must know "
      "which server they're gating.",
    );
  }
  final caps = _capabilityTable[raw];
  if (caps == null) {
    throw StateError(
      "compat: unknown SERVER_VERSION '$raw'. Add it to "
      '_capabilityTable in integration_test/e2e/compat/compat_helpers.dart.',
    );
  }
  return caps;
}

/// Deterministic compat test user. Registered by
/// `scripts/compat/bootstrap.sh` before the Patrol session starts, so
/// the Patrol test only has to log in. Different from `TestEnv` in the
/// sibling e2e/ folder — the release-check E2E suite uses a different
/// password/pin, and we don't want a cross-contamination foot-gun.
class CompatEnv {
  static const serverUrl = String.fromEnvironment(
    'COMPAT_BASE_URL',
    defaultValue: 'http://127.0.0.1:5443',
  );

  static const email = String.fromEnvironment(
    'COMPAT_EMAIL',
    defaultValue: 'compat@hoodik.local',
  );

  static const password = String.fromEnvironment(
    'COMPAT_PASSWORD',
    defaultValue: 'compat-user-pass-1234',
  );

  static const pin = String.fromEnvironment(
    'COMPAT_PIN',
    defaultValue: '123456',
  );
}

/// Whether the tar-capability probe has been observed by the running
/// session. `null` means no upload or download has exercised the probe
/// yet — the app only populates the cache lazily on the first transfer.
bool? tarCapabilityKnown() {
  final container = TestHooks.containerForTest();
  final cache = container.read(tarCapabilityCacheProvider);
  return cache.lookup(CompatEnv.serverUrl);
}

/// Drive the app through add-server + login using the public `AuthService`
/// API directly, skipping every UI tap and route transition.
///
/// Why this exists: Patrol-based UI onboarding on Android keeps getting
/// tripped up by keyboard-over-field issues and post-login PIN routing —
/// none of which are what the compat gate is checking. The gate's job is to prove the *protocol* (chunked upload,
/// encrypted-key decrypt, tar probe, version reporting) interoperates
/// between this app and an older server. Driving `AuthService` directly
/// exercises exactly that layer; the UI is a separate concern that the
/// release-check E2E suite already covers.
///
/// Returns the logged-in [Account] and the [Server] row Drift persisted.
/// Asserts that [AuthService.decryptedPrivateKey] is non-null — the
/// Ascon-128a round-trip is the single thing this call proves works
/// against the target server version, and a null private key means a
/// regression in either the client crypto or the server's stored
/// `encrypted_private_key` shape.
Future<({Account account, Server server})> compatLogin(
  PatrolIntegrationTester $,
) async {
  // `unawaited(app.main())` in the caller only schedules main(); waitForContainer
  // polls + pumps frames until `appRouter` and its ProviderScope are actually
  // up. Direct `containerForTest()` here races and dies with a LateError.
  final container = await TestHooks.waitForContainer($);
  final auth = container.read(authServiceProvider);

  final server = await auth.addServer(CompatEnv.serverUrl);
  final account = await auth.login(
    server: server,
    email: CompatEnv.email,
    password: CompatEnv.password,
  );

  if (auth.decryptedPrivateKey == null) {
    throw StateError(
      'compatLogin: login succeeded but decryptedPrivateKey is null — '
      'the Ascon-128a private-key decryption against '
      '${CompatEnv.serverUrl} (${CompatEnv.email}) failed. Verify that '
      'scripts/compat/register_test_user.py ran against this same version '
      'and that lib/core/crypto/crypto_service.dart\'s password padding '
      'still matches. Without the private key no file operation can '
      'succeed.',
    );
  }

  // Propagate the successful login into the Riverpod providers the rest of
  // the app (and subsequent compat assertions like `apiClientProvider`) read
  // from. Mirrors what `LoginScreen` does via `ref.setLoggedIn` minus the
  // GoRouter navigation — the compat tests don't need the UI, only the
  // providers wired up for ApiClient lookups.
  container.read(isLoggedInProvider.notifier).state = true;
  container.read(activeAccountProvider.notifier).state = account;
  container.read(activeServerProvider.notifier).state = server;
  container.read(decryptedPrivateKeyProvider.notifier).state =
      auth.decryptedPrivateKey;
  container.invalidate(apiClientProvider);

  return (account: account, server: server);
}
