import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/theme/hoodik_theme.dart';
import 'package:hoodik_app/features/auth/widgets/cloud_nudge.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records launch calls instead of hitting the real platform channel.
class _RecordingUrlLauncher extends UrlLauncherPlatform {
  final List<String> launched = [];
  LaunchOptions? lastOptions;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    lastOptions = options;
    return true;
  }
}

void main() {
  Future<void> pumpNudge(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HoodikTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CloudNudge()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the server chooser card', (tester) async {
    await pumpNudge(tester);

    expect(find.text('Need a server?'), findsOneWidget);
    expect(
      find.text('Self-host for free, or get a managed instance.'),
      findsOneWidget,
    );
    expect(find.text('Learn more'), findsOneWidget);
  });

  testWidgets('tapping Learn more opens the chooser page externally', (
    tester,
  ) async {
    final launcher = _RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;

    await pumpNudge(tester);
    await tester.tap(find.text('Learn more'));

    expect(launcher.launched, ['https://hoodik.io/server?ref=app']);
    expect(launcher.lastOptions?.mode, PreferredLaunchMode.externalApplication);
  });

  test('links to the server chooser page with the app referrer tag', () {
    expect(
      CloudNudge.serverGuideUri.toString(),
      'https://hoodik.io/server?ref=app',
    );
  });
}
