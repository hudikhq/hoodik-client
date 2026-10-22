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

  test('download complete notifications are on by default', () async {
    final container = await containerWith({});
    expect(container.read(downloadCompleteNotificationsProvider), isTrue);
  });

  test('turning them off writes through to storage', () async {
    final container = await containerWith({});
    await container
        .read(downloadCompleteNotificationsProvider.notifier)
        .set(false);

    expect(container.read(downloadCompleteNotificationsProvider), isFalse);
    expect((await Preferences.load()).downloadCompleteNotifications, isFalse);
  });
}
