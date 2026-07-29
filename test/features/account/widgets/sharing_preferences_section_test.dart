import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/account/widgets/sharing_preferences_section.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

class _FakeAuthClient extends Fake implements AuthClient {
  _FakeAuthClient(this.enabled);

  final bool enabled;

  @override
  Future<AuthResponse> getSelf() async {
    return AuthResponse(user: {'share_notifications_enabled': enabled});
  }
}

class _RecordingSharesClient extends Fake implements SharesClient {
  bool? lastPatched;
  bool throwOnPatch = false;

  @override
  Future<void> patchMe({
    bool? shareNotificationsEnabled,
    String? locale,
  }) async {
    if (throwOnPatch) throw Exception('server rejected');
    lastPatched = shareNotificationsEnabled;
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient({required this.auth, required this.shares});

  @override
  final AuthClient auth;

  @override
  final SharesClient shares;
}

Capabilities _caps({required bool sharingEnabled}) {
  return Capabilities(
    sharingEnabled: sharingEnabled,
    roles: const [ShareRole.reader],
    editableFolders: false,
    shareGroups: false,
    auditLog: false,
    fork: false,
  );
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool sharingEnabled,
    required bool currentValue,
    required _RecordingSharesClient shares,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(
            _FakeApiClient(auth: _FakeAuthClient(currentValue), shares: shares),
          ),
          shareCapabilitiesProvider.overrideWith(
            (ref) async => _caps(sharingEnabled: sharingEnabled),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SharingPreferencesSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hidden entirely on a server that does not advertise sharing', (
    tester,
  ) async {
    final shares = _RecordingSharesClient();
    await pump(
      tester,
      sharingEnabled: false,
      currentValue: true,
      shares: shares,
    );

    expect(find.byType(CupertinoSwitch), findsNothing);
    expect(find.text('Email me when a file is shared with me'), findsNothing);
  });

  testWidgets('renders the current enabled value from the user row', (
    tester,
  ) async {
    final shares = _RecordingSharesClient();
    await pump(
      tester,
      sharingEnabled: true,
      currentValue: true,
      shares: shares,
    );

    expect(find.text('Email me when a file is shared with me'), findsOneWidget);
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
      isTrue,
    );
    expect(find.text('Sharing emails are on.'), findsOneWidget);
  });

  testWidgets('renders the current disabled value from the user row', (
    tester,
  ) async {
    final shares = _RecordingSharesClient();
    await pump(
      tester,
      sharingEnabled: true,
      currentValue: false,
      shares: shares,
    );

    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
      isFalse,
    );
    expect(find.text('Sharing emails are off.'), findsOneWidget);
  });

  testWidgets('toggling off persists the new value via patchMe', (
    tester,
  ) async {
    final shares = _RecordingSharesClient();
    await pump(
      tester,
      sharingEnabled: true,
      currentValue: true,
      shares: shares,
    );

    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();

    expect(shares.lastPatched, isFalse);
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
      isFalse,
    );
  });

  testWidgets('a failed patch reverts the optimistic flip', (tester) async {
    final shares = _RecordingSharesClient()..throwOnPatch = true;
    await pump(
      tester,
      sharingEnabled: true,
      currentValue: true,
      shares: shares,
    );

    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();

    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
      isTrue,
    );
  });
}
