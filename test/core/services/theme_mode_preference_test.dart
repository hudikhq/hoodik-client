import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await Preferences.load();
  final container = ProviderContainer(
    overrides: [preferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('follows the system until the user says otherwise', () async {
    final container = await containerWith({});
    expect(container.read(appThemeModeProvider), ThemeMode.system);
  });

  test('a stored choice survives the next launch', () async {
    final container = await containerWith({'app.themeMode': 'light'});
    expect(container.read(appThemeModeProvider), ThemeMode.light);
  });

  test('setting writes through to storage', () async {
    final container = await containerWith({});
    await container.read(appThemeModeProvider.notifier).set(ThemeMode.dark);

    expect(container.read(appThemeModeProvider), ThemeMode.dark);
    // Re-read from a fresh Preferences over the same backing store — the
    // preference only matters if it outlives the process that set it.
    expect((await Preferences.load()).themeMode, ThemeMode.dark);
  });

  test('an unknown stored value falls back rather than throwing', () async {
    final container = await containerWith({'app.themeMode': 'sepia'});
    expect(container.read(appThemeModeProvider), ThemeMode.system);
  });
}
