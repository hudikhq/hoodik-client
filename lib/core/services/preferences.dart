import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../providers.dart' show FilesViewMode;
import '../utils/l10n_lookup.dart';

/// Which top-level bottom-nav tab is shown at app launch. Persisted
/// across restarts via [Preferences.setLandingBranch].
enum LandingBranch {
  files('/'),
  notes('/notes');

  final String route;

  const LandingBranch(this.route);

  String get label => switch (this) {
    files => ambientL10n.serviceLandingBranchFiles,
    notes => ambientL10n.serviceLandingBranchNotes,
  };
}

/// Thin wrapper around [SharedPreferences] that exposes strongly-typed
/// accessors for the app's user preferences. Reads are synchronous
/// (`SharedPreferences` caches keys on load); writes return futures that
/// the caller can await but usually don't need to — cosmetic prefs
/// failing to persist won't break the session, only the *next* launch's
/// initial state.
class Preferences {
  final SharedPreferences _prefs;

  Preferences(this._prefs);

  /// Load once at app start. Must be called after `ensureInitialized`.
  static Future<Preferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Preferences(prefs);
  }

  // ── Re-index sweep ────────────────────────────────────────────────
  static const _kReindexGaveUp = 'reindex.gaveUpFileIds';

  /// Files the sweep has tried and failed on, so it stops asking.
  ///
  /// Without this the sweep is a trap: a file it can never index stays
  /// pending forever, so the dialog returns on every single launch with no
  /// way for the user to make it stop. They are still retried quietly on
  /// later sweeps — a file that becomes readable again recovers on its own —
  /// but they no longer earn a modal.
  Set<String> get reindexGaveUpFileIds =>
      (_prefs.getStringList(_kReindexGaveUp) ?? const []).toSet();

  Future<void> setReindexGaveUpFileIds(Set<String> ids) =>
      _prefs.setStringList(_kReindexGaveUp, ids.toList());

  // ── Files screen view mode ────────────────────────────────────────
  static const _kFilesViewMode = 'files.viewMode';

  FilesViewMode get filesViewMode {
    final raw = _prefs.getString(_kFilesViewMode);
    if (raw == null) return FilesViewMode.list;
    return FilesViewMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => FilesViewMode.list,
    );
  }

  Future<void> setFilesViewMode(FilesViewMode mode) =>
      _prefs.setString(_kFilesViewMode, mode.name);

  // ── App display language ──────────────────────────────────────────
  static const _kAppLocale = 'app.locale';

  /// Language code the app renders in, or null to follow the device.
  String? get appLocale => _prefs.getString(_kAppLocale);

  Future<void> setAppLocale(String? code) => code == null
      ? _prefs.remove(_kAppLocale)
      : _prefs.setString(_kAppLocale, code);

  // ── Default landing branch ────────────────────────────────────────
  static const _kLandingBranch = 'app.landingBranch';

  LandingBranch get landingBranch {
    final raw = _prefs.getString(_kLandingBranch);
    if (raw == null) return LandingBranch.files;
    return LandingBranch.values.firstWhere(
      (b) => b.name == raw,
      orElse: () => LandingBranch.files,
    );
  }

  Future<void> setLandingBranch(LandingBranch branch) =>
      _prefs.setString(_kLandingBranch, branch.name);

  // ── Appearance ────────────────────────────────────────────────────
  static const _kThemeMode = 'app.themeMode';

  /// Light, dark, or [ThemeMode.system] to follow the OS setting.
  ThemeMode get themeMode {
    final raw = _prefs.getString(_kThemeMode);
    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);
}
