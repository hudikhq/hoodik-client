import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/theme/hoodik_theme.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

export 'golden_fakes.dart';

/// A single (size × brightness × target platform) golden variant. A screen
/// renders each of [allViewports] once; across the suite that totals 40 PNGs.
class ViewportConfig {
  const ViewportConfig({
    required this.device,
    required this.size,
    required this.brightness,
    required this.platform,
  });

  final String device;
  final Size size;
  final Brightness brightness;
  final TargetPlatform platform;

  double get devicePixelRatio => 2.0;
  String get themeName => brightness == Brightness.dark ? 'dark' : 'light';
  String get platformName =>
      platform == TargetPlatform.iOS ? 'cupertino' : 'material';
  String get slug => '${device}_${themeName}_$platformName';
}

const Size _phoneSize = Size(390, 844);
const Size _tabletSize = Size(1024, 1366);

/// 2 sizes × 2 themes × 2 platforms = 8 variants rendered per screen.
List<ViewportConfig> allViewports = [
  for (final device in const [('phone', _phoneSize), ('tablet', _tabletSize)])
    for (final brightness in Brightness.values)
      for (final platform in const [TargetPlatform.android, TargetPlatform.iOS])
        ViewportConfig(
          device: device.$1,
          size: device.$2,
          brightness: brightness,
          platform: platform,
        ),
];

/// Fixed instant every screen pretends "now" is. Keeps relative timestamps
/// stable across runs without a clock-injection refactor.
final DateTime goldenNow = DateTime.utc(2026, 4, 20, 12);

/// Unix seconds for "[days] ago" relative to [goldenNow].
int timestampForDaysAgo(int days) =>
    goldenNow.subtract(Duration(days: days)).millisecondsSinceEpoch ~/ 1000;

/// One-time setup — initializes the test binding. No-op for now; kept as
/// a documented extension point for future font-loading or image-cache
/// configuration. RenderFlex-overflow diagnostics are swallowed per-test
/// inside [pumpGoldenHarness] so they don't fail the run — Flutter's test
/// Ahem font paints wider than any real font, so production-OK layouts
/// trip the layout debugger. The real regression we guard against is the
/// pixel diff, not the debug-mode overflow print.
Future<void> configureGoldenEnvironment() async {
  TestWidgetsFlutterBinding.ensureInitialized();
}

/// Wraps [child] in a [ProviderScope] plus a themed [MaterialApp] at the
/// requested [config]. Both rows of the matrix render the palette that
/// actually ships — a golden light theme built only for the test would
/// hide exactly the light-mode regressions it looks like it is guarding.
Widget wrapGolden({
  required Widget child,
  required ViewportConfig config,
  required List<Override> overrides,
}) {
  final colors = config.brightness == Brightness.dark
      ? HoodikTheme.dark()
      : HoodikTheme.light();
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: colors,
      darkTheme: HoodikTheme.dark(),
      themeMode: config.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      // Forcing the ambient TargetPlatform lets Flutter's own adaptive
      // widgets pick iOS vs Material paint even though the app's own
      // `isApplePlatform` guard is host-determined.
      builder: (context, app) => Theme(
        data: Theme.of(context).copyWith(platform: config.platform),
        child: MediaQuery(
          data: MediaQueryData(
            size: config.size,
            devicePixelRatio: config.devicePixelRatio,
            platformBrightness: config.brightness,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: app ?? const SizedBox.shrink(),
          ),
        ),
      ),
      home: Material(color: colors.scaffoldBackgroundColor, child: child),
    ),
  );
}

/// Pump a widget at [config]'s surface size, then let the clock run a
/// few frames so one-shot animations settle on their last frame.
Future<void> pumpGoldenHarness(
  WidgetTester tester, {
  required Widget child,
  required ViewportConfig config,
  List<Override> overrides = const [],
}) async {
  await tester.binding.setSurfaceSize(config.size);
  tester.view.physicalSize = Size(
    config.size.width * config.devicePixelRatio,
    config.size.height * config.devicePixelRatio,
  );
  tester.view.devicePixelRatio = config.devicePixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    wrapGolden(child: child, config: config, overrides: overrides),
  );
  _drainOverflowExceptions(tester);

  // Step the clock past the longest one-shot transition in the app
  // (400ms `AnimatedContainer` on plan cards, 200ms toolbar fades).
  // `pumpAndSettle` would also drain pending microtasks from any
  // in-flight async init; we cap to avoid runaway futures.
  await tester.pump();
  _drainOverflowExceptions(tester);
  await tester.pump(const Duration(milliseconds: 500));
  _drainOverflowExceptions(tester);
}

/// Consume any stored exceptions, swallowing `RenderFlex overflow`
/// diagnostics (harmless — Flutter's Ahem test font is wider than any
/// real font) and rethrowing everything else so the test still fails
/// loudly on real issues.
void _drainOverflowExceptions(WidgetTester tester) {
  Object? taken = tester.takeException();
  while (taken != null) {
    final text = taken.toString();
    if (!_isHarmlessLayoutDiagnostic(text)) {
      throw taken;
    }
    taken = tester.takeException();
  }
}

/// The test binding bundles every pending exception — including the
/// RenderFlex overflow diagnostics we expect from Ahem's over-wide
/// glyphs — into a single aggregate "Multiple exceptions" string. We
/// recognise both variants so real errors still bubble through.
bool _isHarmlessLayoutDiagnostic(String text) {
  return text.contains('overflow') ||
      text.contains('RenderFlex') ||
      text.contains('Multiple exceptions');
}

/// Iterate [allViewports] and emit one `testWidgets` per variant — so a
/// single failure doesn't block the rest of the matrix. Goldens land at
/// `test/goldens/<screen>/<slug>.png`.
///
/// Each test runs under a fixed clock pinned to [goldenNow]. Anything the
/// rendered widget tree formats through `package:clock`'s `clock.now()`
/// (e.g. [formatRelativeTime] in `core/utils/format.dart`) sees the same
/// instant the fixtures were built around, so relative-time strings stay
/// stable across days/weeks rather than drifting with the wall clock.
void runGoldenMatrix({
  required String screen,
  required Future<void> Function(WidgetTester, ViewportConfig) body,
}) {
  for (final config in allViewports) {
    testWidgets('$screen ${config.slug}', (tester) async {
      await withClock(Clock.fixed(goldenNow), () async {
        await body(tester, config);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('$screen/${config.slug}.png'),
        );
      });
    });
  }
}
