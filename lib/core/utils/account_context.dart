/// Holds the label of the account whose session is currently active, so the
/// logger can prefix every emitted record with `[<email> / <server-host>]`
/// without individual call sites having to remember to pass it.
///
/// Set by the auth-state transitions: on login, on switch, and cleared on
/// logout. Read by [Logger] at record-emit time.
///
/// This is global-ish state on purpose. A single running app has one active
/// account at a time from the user's perspective — background workers that
/// execute under a different account are rare enough that attaching the
/// currently-active label is good-enough triage metadata for bug reports.
class AccountContext {
  static String? _label;

  /// The current `<email> / <server-host>` label, or `null` when no account
  /// is active (e.g. the onboarding screen, post-logout).
  static String? get current => _label;

  /// Record the active account's identity. Pass both [email] and
  /// [serverHost] to set the label, or pass either as null / empty to
  /// clear it.
  static void set({required String? email, required String? serverHost}) {
    if (email == null ||
        email.isEmpty ||
        serverHost == null ||
        serverHost.isEmpty) {
      _label = null;
      return;
    }
    _label = '$email / $serverHost';
  }

  /// Clear the current context — used on logout and in test teardown.
  static void clear() {
    _label = null;
  }
}
