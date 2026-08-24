import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/features/files/widgets/file_dialogs.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('n >= 2 export shows the body; cancel starts no download', (
    tester,
  ) async {
    var confirmed = true;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              confirmed = await confirmBulkExport(
                context: context,
                fileCount: 3,
                folderCount: 1,
                isLarge: true,
              );
            },
            child: const Text('go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Export 3 files?'), findsOneWidget);
    expect(
      find.textContaining('Each file will be downloaded and decrypted first'),
      findsOneWidget,
    );
    expect(find.textContaining('1 folder will be skipped.'), findsOneWidget);
    expect(
      find.textContaining(
        'This is a large export and may take several minutes.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);
  });
}
