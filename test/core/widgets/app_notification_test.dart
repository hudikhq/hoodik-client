import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/widgets/app_notification.dart';

void main() {
  tearDown(() => AppNotification.dismiss());

  Widget buildApp({required Widget child}) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('AppNotification.show', () {
    testWidgets('displays message text', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  AppNotification.show(context, message: 'Hello world'),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('shows check_circle icon for success type', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppNotification.show(
                context,
                message: 'Done',
                type: NotificationType.success,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows error_outline icon for error type', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppNotification.show(
                context,
                message: 'Oops',
                type: NotificationType.error,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows info_outline icon for info type', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppNotification.show(
                context,
                message: 'FYI',
                type: NotificationType.info,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('auto-dismisses after duration', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppNotification.show(
                context,
                message: 'Bye soon',
                duration: const Duration(seconds: 1),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('Bye soon'), findsOneWidget);

      // Advance past the auto-hide duration + animation.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Bye soon'), findsNothing);
    });

    testWidgets('second show replaces the first', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () =>
                      AppNotification.show(context, message: 'First'),
                  child: const Text('First'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      AppNotification.show(context, message: 'Second'),
                  child: const Text('Second'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsWidgets);

      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();

      // First notification should be gone, second visible.
      expect(
        find.text('First'),
        findsOneWidget, // only the button text remains
      );
      expect(
        find.text('Second'),
        findsWidgets, // button + notification
      );
    });

    testWidgets('tap dismisses early', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppNotification.show(
                context,
                message: 'Tap me away',
                duration: const Duration(seconds: 10),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('Tap me away'), findsOneWidget);

      // Tap the notification itself to dismiss.
      await tester.tap(find.text('Tap me away'));
      await tester.pumpAndSettle();

      expect(find.text('Tap me away'), findsNothing);
    });
  });
}
