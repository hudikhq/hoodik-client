import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart' show ShareRole;
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/widgets/adaptive.dart';
import 'package:hoodik_app/features/shares/providers/audit_log_notifier.dart';
import 'package:hoodik_app/features/shares/providers/groups_notifier.dart';
import 'package:hoodik_app/features/shares/screens/share_hub_screen.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

/// Public-links fetch returns nothing, so [LinksBody] settles on its empty
/// state and the for-loop never touches [FileCrypto] — a bare fake suffices.
/// Counts calls so a re-fetch from the refresh action can be asserted.
class _EmptyLinksClient extends Fake implements LinksClient {
  int listCalls = 0;

  @override
  Future<List<dynamic>> list({bool withExpired = false}) async {
    listCalls += 1;
    return const [];
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._links);
  final LinksClient _links;
  @override
  LinksClient get links => _links;
}

class _FakeFileCrypto extends Fake implements FileCrypto {}

class _EmptyGroupsNotifier extends GroupsNotifier {
  @override
  Future<GroupsResponse> build() async =>
      GroupsResponse(owned: const [], memberOf: const []);
}

class _EmptyAuditNotifier extends AuditLogNotifier {
  @override
  Future<AuditLogState> build() async =>
      const AuditLogState(rows: [], total: 0);
}

Capabilities _caps({
  bool sharingEnabled = true,
  bool auditLog = false,
  bool shareGroups = false,
}) => Capabilities(
  sharingEnabled: sharingEnabled,
  roles: const [ShareRole.reader, ShareRole.editor, ShareRole.coOwner],
  editableFolders: true,
  shareGroups: shareGroups,
  auditLog: auditLog,
  fork: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_EmptyLinksClient> pumpHub(
    WidgetTester tester,
    Capabilities caps,
  ) async {
    final links = _EmptyLinksClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shareCapabilitiesProvider.overrideWith((ref) async => caps),
          apiClientProvider.overrideWithValue(_FakeApiClient(links)),
          fileCryptoProvider.overrideWithValue(_FakeFileCrypto()),
          groupsNotifierProvider.overrideWith(_EmptyGroupsNotifier.new),
          auditLogNotifierProvider.overrideWith(_EmptyAuditNotifier.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ShareHubScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return links;
  }

  // The hub's switcher is a segmented control on Apple platforms and a
  // Material TabBar elsewhere — resolve the host's variant.
  final switcherType = isApplePlatform
      ? CupertinoSlidingSegmentedControl<int>
      : TabBar;

  Finder tab(String label) => find.descendant(
    of: find.byType(switcherType),
    matching: find.text(label),
  );

  testWidgets('the Public links tab is always present', (tester) async {
    await pumpHub(
      tester,
      _caps(sharingEnabled: true, auditLog: true, shareGroups: true),
    );
    expect(tab('Public links'), findsOneWidget);
  });

  testWidgets('the Activity tab appears only when the audit cap is set', (
    tester,
  ) async {
    await pumpHub(tester, _caps(auditLog: true, shareGroups: false));
    expect(tab('Activity'), findsOneWidget);
    expect(tab('Groups'), findsNothing);
  });

  testWidgets('the Groups tab appears only when the share-groups cap is set', (
    tester,
  ) async {
    await pumpHub(tester, _caps(auditLog: false, shareGroups: true));
    expect(tab('Groups'), findsOneWidget);
    expect(tab('Activity'), findsNothing);
  });

  testWidgets('sharing disabled hides Activity and Groups even when their '
      'sub-caps are set', (tester) async {
    await pumpHub(
      tester,
      _caps(sharingEnabled: false, auditLog: true, shareGroups: true),
    );
    expect(find.byType(switcherType), findsNothing);
    expect(find.text('No shared links'), findsOneWidget);
  });

  testWidgets('with no extra caps only Public links shows and there is no '
      'TabBar', (tester) async {
    await pumpHub(tester, _caps(auditLog: false, shareGroups: false));

    expect(find.byType(switcherType), findsNothing);
    // The lone Public-links body is rendered directly.
    expect(find.text('No shared links'), findsOneWidget);
    // The hub header is always the plain "Share" title.
    expect(find.widgetWithText(AppBar, 'Share'), findsOneWidget);
  });

  testWidgets('switching to a gated tab renders that body', (tester) async {
    await pumpHub(tester, _caps(auditLog: true, shareGroups: true));

    // Public links is the initial tab.
    expect(find.text('No shared links'), findsOneWidget);

    await tester.tap(tab('Groups'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('owned-empty')), findsOneWidget);
    expect(find.text('No shared links'), findsNothing);

    await tester.tap(tab('Activity'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('audit-empty')), findsOneWidget);
  });

  testWidgets('the Groups tab exposes a New group action', (tester) async {
    await pumpHub(tester, _caps(shareGroups: true));
    await tester.tap(tab('Groups'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('New group'), findsOneWidget);
  });

  testWidgets('the Activity tab exposes a Refresh action', (tester) async {
    await pumpHub(tester, _caps(auditLog: true));
    await tester.tap(tab('Activity'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Refresh'), findsOneWidget);
  });

  testWidgets('the Public links tab exposes a Refresh action that re-fetches', (
    tester,
  ) async {
    final links = await pumpHub(tester, _caps());

    expect(find.byTooltip('Refresh'), findsOneWidget);
    final beforeTap = links.listCalls;

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(
      links.listCalls,
      beforeTap + 1,
      reason: 'the refresh action re-fetches GET /api/links',
    );
  });

  testWidgets('the empty Public links state is pull-to-refreshable', (
    tester,
  ) async {
    await pumpHub(tester, _caps());
    // A RefreshIndicator over the empty state so a link created elsewhere can
    // be pulled in before the first link exists.
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('No shared links'), findsOneWidget);
  });
}
