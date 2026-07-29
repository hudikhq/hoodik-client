import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/preview/providers/preview_providers.dart';
import 'package:hoodik_app/features/preview/screens/preview_screen.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

/// Records calls to the `flutter/platform` channel that the
/// [SystemChrome.setEnabledSystemUIMode] implementation makes. Matches the
/// two method names Flutter emits internally — one for non-manual modes and
/// one for `SystemUiMode.manual` (which uses `setEnabledSystemUIOverlays`).
class _ChromeRecorder {
  final List<_Call> calls = [];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
            calls.add(
              _Call(method: call.method, mode: call.arguments as String?),
            );
          } else if (call.method == 'SystemChrome.setEnabledSystemUIOverlays') {
            calls.add(
              _Call(
                method: call.method,
                overlays: (call.arguments as List?)?.cast<String>(),
              ),
            );
          }
          return null;
        });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  }
}

class _Call {
  _Call({required this.method, this.mode, this.overlays});

  final String method;
  final String? mode;
  final List<String>? overlays;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreviewScreen system UI restoration', () {
    late _ChromeRecorder recorder;

    setUp(() {
      recorder = _ChromeRecorder()..install();
    });

    tearDown(() {
      recorder.uninstall();
    });

    testWidgets('exit restores manual mode with all overlays', (tester) async {
      // Empty context short-circuits the build to the "no previewable files"
      // scaffold — initState still runs (setting edgeToEdge) and dispose
      // still runs (restoring the default), which is what we need to assert.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            previewContextProvider.overrideWith(
              (ref) => const PreviewContext(files: [], names: {}, keys: {}),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PreviewScreen(fileId: 'anything'),
          ),
        ),
      );
      // pumpAndSettle would hang on the KeyboardListener's focus request.
      await tester.pump();

      // Tear the widget down to trigger dispose.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();

      final enter = recorder.calls.firstWhere(
        (c) => c.method == 'SystemChrome.setEnabledSystemUIMode',
        orElse: () => throw StateError(
          'Expected an enter call (edgeToEdge) from initState',
        ),
      );
      expect(enter.mode, 'SystemUiMode.edgeToEdge');

      final exit = recorder.calls.lastWhere(
        (c) => c.method == 'SystemChrome.setEnabledSystemUIOverlays',
        orElse: () => throw StateError(
          'Expected an exit call (setEnabledSystemUIOverlays) from dispose '
          'restoring manual mode with overlays — currently the screen re-sets '
          'edgeToEdge on dispose, leaking the immersive mode to the next screen.',
        ),
      );
      expect(
        exit.overlays,
        containsAll(<String>['SystemUiOverlay.top', 'SystemUiOverlay.bottom']),
      );
    });
  });
}
