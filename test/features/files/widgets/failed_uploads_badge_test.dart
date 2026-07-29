import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/files/widgets/failed_uploads_badge.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

Future<void> _pumpBadge(
  WidgetTester tester, {
  required int count,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        permanentlyFailedCountProvider.overrideWith((_) async => count),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(actions: [FailedUploadsBadge(onTap: onTap)]),
        ),
      ),
    ),
  );
  // Let the FutureProvider resolve.
  await tester.pumpAndSettle();
}

void main() {
  group('FailedUploadsBadge', () {
    testWidgets('renders nothing when count is zero', (tester) async {
      await _pumpBadge(tester, count: 0);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('renders a count label when count is positive', (tester) async {
      await _pumpBadge(tester, count: 3);
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('caps label at 99+ above the threshold', (tester) async {
      await _pumpBadge(tester, count: 128);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('tap invokes the provided callback', (tester) async {
      var tapped = 0;
      await _pumpBadge(tester, count: 2, onTap: () => tapped++);
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets(
      'tap without callback signals the transfer overlay request provider',
      (tester) async {
        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              permanentlyFailedCountProvider.overrideWith((_) async => 1),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(appBar: _BadgeHost()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(container.read(transferOverlayRequestProvider), isNull);

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        final request = container.read(transferOverlayRequestProvider);
        expect(request, isNotNull);
        expect(request!.scrollToFailed, isTrue);
      },
    );
  });
}

class _BadgeHost extends StatelessWidget implements PreferredSizeWidget {
  const _BadgeHost();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(actions: const [FailedUploadsBadge()]);
  }
}
