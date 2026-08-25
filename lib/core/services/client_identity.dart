import 'package:package_info_plus/package_info_plus.dart';

/// Header every request carries so the server knows which client is calling
/// and how old it is.
const clientIdentityHeader = 'X-Hoodik-Client';

/// What this app puts in [clientIdentityHeader]: `app/<version>`.
///
/// The server refuses writes from a client too old to produce the data shapes
/// it stores, and its only other way to tell is to recognise an old-shaped
/// payload after the request has already arrived. Saying so up front lets it
/// answer at the door instead — and lets a future server draw the line
/// wherever it needs to, without a client of that era having to have
/// anticipated it.
///
/// The absence of this header therefore means a client from before it
/// existed, which is exactly the population a version check wants to catch.
/// It is a courtesy, not a credential: anything can send it, so nothing that
/// protects data may rely on it.
String get clientIdentity => _identity ?? _fallback;

String? _identity;

/// Used before [loadClientIdentity] has run — in tests, and in the window
/// before startup finishes. Deliberately versionless rather than a guessed
/// number: a wrong version is worse than an unknown one.
const _fallback = 'app';

/// Reads the running version once. Call before the first request goes out;
/// `main` awaits it during startup.
Future<void> loadClientIdentity() async {
  if (_identity != null) return;
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty) _identity = 'app/${info.version}';
  } catch (_) {
    // Platform channel unavailable (tests, some desktop shells). The
    // fallback still identifies the caller as the app.
  }
}
