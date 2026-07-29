import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/widgets/adaptive.dart';
import 'package:hoodik_app/features/admin/widgets/admin_settings_tab.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

class _FakeAdminClient extends Fake implements AdminClient {
  _FakeAdminClient(this._initial);

  final ServerSettings _initial;
  ServerSettings? lastSaved;

  @override
  Future<ServerSettings> getSettings() async => _initial;

  @override
  Future<ServerSettings> updateSettings(ServerSettings settings) async {
    lastSaved = settings;
    return settings;
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._admin);
  final AdminClient _admin;
  @override
  AdminClient get admin => _admin;
}

void main() {
  Future<_FakeAdminClient> pump(
    WidgetTester tester,
    ServerSettings initial,
  ) async {
    final admin = _FakeAdminClient(initial);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(_FakeApiClient(admin))],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AdminSettingsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return admin;
  }

  // The toggle is a Switch.adaptive inside the sharing AdaptiveListTile, so it
  // renders as a CupertinoSwitch on Apple hosts and a Switch elsewhere. Scope to
  // that one tile so the registration and email switches above don't match.
  Finder sharingSwitch() {
    final tile = find.ancestor(
      of: find.text('Account-to-account sharing'),
      matching: find.byType(AdaptiveListTile),
    );
    final cupertino = find.descendant(
      of: tile,
      matching: find.byType(CupertinoSwitch),
    );
    if (cupertino.evaluate().isNotEmpty) return cupertino;
    return find.descendant(of: tile, matching: find.byType(Switch));
  }

  bool sharingSwitchValue(WidgetTester tester) {
    final w = tester.widget(sharingSwitch());
    return w is CupertinoSwitch ? w.value : (w as Switch).value;
  }

  testWidgets('shows the sharing toggle reflecting the enabled state', (
    tester,
  ) async {
    await pump(
      tester,
      ServerSettings(
        allowRegister: true,
        enforceEmailActivation: false,
        sharingEnabled: true,
        sharingSupported: true,
      ),
    );

    expect(find.text('Account-to-account sharing'), findsOneWidget);
    expect(sharingSwitchValue(tester), isTrue);
  });

  testWidgets('reflects a disabled sharing state from the server', (
    tester,
  ) async {
    await pump(
      tester,
      ServerSettings(
        allowRegister: true,
        enforceEmailActivation: false,
        sharingEnabled: false,
        sharingSupported: true,
      ),
    );

    expect(sharingSwitchValue(tester), isFalse);
  });

  testWidgets('flipping the toggle and saving PUTs the new sharing value', (
    tester,
  ) async {
    final admin = await pump(
      tester,
      ServerSettings(
        allowRegister: true,
        enforceEmailActivation: false,
        sharingEnabled: true,
        sharingSupported: true,
      ),
    );

    await tester.tap(sharingSwitch());
    await tester.pumpAndSettle();
    expect(sharingSwitchValue(tester), isFalse);

    await tester.tap(find.text('Save Settings'));
    await tester.pumpAndSettle();

    expect(admin.lastSaved, isNotNull);
    expect(admin.lastSaved!.sharingEnabled, isFalse);
    // The block must travel on the wire, or an older server's serde default
    // would silently flip sharing back on.
    expect(admin.lastSaved!.toJson()['sharing'], {'enabled': false});
  });

  testWidgets('hides the sharing toggle when the server does not report it', (
    tester,
  ) async {
    // A server older than the kill-switch returns no sharing block; the toggle
    // must not appear, and a save must omit the sharing field entirely.
    final admin = await pump(
      tester,
      ServerSettings(
        allowRegister: true,
        enforceEmailActivation: false,
        sharingSupported: false,
      ),
    );

    expect(find.text('Account-to-account sharing'), findsNothing);
    expect(find.text('SHARING'), findsNothing);

    await tester.tap(find.text('Save Settings'));
    await tester.pumpAndSettle();

    expect(admin.lastSaved, isNotNull);
    expect(admin.lastSaved!.toJson().containsKey('sharing'), isFalse);
  });
}
