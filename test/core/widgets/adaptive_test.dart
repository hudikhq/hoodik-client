import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/widgets/adaptive.dart';

/// Whether this test is running on an Apple platform (iOS/macOS).
final _apple = Platform.isIOS || Platform.isMacOS;

void main() {
  group('AdaptiveButton', () {
    testWidgets('renders correct button for platform', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveButton(onPressed: () {}, child: const Text('Submit')),
          ),
        ),
      );

      expect(find.text('Submit'), findsOneWidget);

      if (_apple) {
        expect(find.byType(CupertinoButton), findsOneWidget);
      } else {
        expect(find.byType(ElevatedButton), findsOneWidget);
      }
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveButton(
              onPressed: () => pressed = true,
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      expect(pressed, true);
    });
  });

  group('AdaptiveTextButton', () {
    testWidgets('renders correct button for platform', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveTextButton(
              onPressed: () {},
              child: const Text('Cancel'),
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);

      if (_apple) {
        expect(find.byType(CupertinoButton), findsOneWidget);
      } else {
        expect(find.byType(TextButton), findsOneWidget);
      }
    });
  });

  group('AdaptiveTextField', () {
    testWidgets('renders correct field for platform', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveTextField(label: 'Email', placeholder: 'Enter email'),
          ),
        ),
      );

      if (_apple) {
        expect(find.byType(CupertinoTextField), findsOneWidget);
      } else {
        expect(find.byType(TextField), findsOneWidget);
      }

      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('respects controller text', (tester) async {
      final controller = TextEditingController(text: 'hello');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdaptiveTextField(controller: controller)),
        ),
      );

      expect(find.text('hello'), findsOneWidget);
      controller.dispose();
    });
  });

  group('AdaptiveListSection', () {
    testWidgets('renders header and children', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdaptiveListSection(
                header: 'MY SECTION',
                children: [
                  AdaptiveListTile(title: const Text('Item 1')),
                  AdaptiveListTile(title: const Text('Item 2')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('MY SECTION'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });
  });

  group('AdaptiveListTile', () {
    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  AdaptiveListTile(
                    title: const Text('User Name'),
                    subtitle: const Text('user@test.com'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('User Name'), findsOneWidget);
      expect(find.text('user@test.com'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  AdaptiveListTile(
                    title: const Text('Tappable'),
                    onTap: () => tapped = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable'));
      expect(tapped, true);
    });
  });

  group('AdaptiveLoadingIndicator', () {
    testWidgets('renders loading indicator for platform', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdaptiveLoadingIndicator())),
      );

      if (_apple) {
        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      } else {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      }
    });
  });

  group('ErrorBanner', () {
    testWidgets('displays error message and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorBanner(message: 'Something went wrong')),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);

      if (_apple) {
        expect(
          find.byIcon(CupertinoIcons.exclamationmark_circle),
          findsOneWidget,
        );
      } else {
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      }
    });
  });

  group('adaptiveIcon', () {
    test('returns correct icon for platform', () {
      final icon = adaptiveIcon(
        material: Icons.settings,
        cupertino: CupertinoIcons.gear,
      );

      if (_apple) {
        expect(icon, CupertinoIcons.gear);
      } else {
        expect(icon, Icons.settings);
      }
    });
  });
}
