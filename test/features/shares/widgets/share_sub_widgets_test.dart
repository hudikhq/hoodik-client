import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/features/shares/widgets/share_fingerprint_tile.dart';
import 'package:hoodik_app/features/shares/widgets/share_role_selector.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('ShareFingerprintTile', () {
    testWidgets('first sight renders no acknowledgement checkbox', (
      tester,
    ) async {
      await _pump(
        tester,
        const ShareFingerprintTile(
          email: 'a@b.c',
          formattedFingerprint: 'ABCD-1234',
          status: ShareTrustStatus.firstSight,
        ),
      );
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('First time sharing'), findsOneWidget);
    });

    testWidgets('verified renders the verified banner, no checkbox', (
      tester,
    ) async {
      await _pump(
        tester,
        const ShareFingerprintTile(
          email: 'a@b.c',
          formattedFingerprint: 'ABCD-1234',
          status: ShareTrustStatus.verified,
        ),
      );
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('Verified'), findsOneWidget);
    });

    testWidgets('mismatch shows both fingerprints and an ack checkbox that '
        'reports its toggle', (tester) async {
      bool? reported;
      await _pump(
        tester,
        ShareFingerprintTile(
          email: 'a@b.c',
          formattedFingerprint: 'NEW0-0000',
          status: ShareTrustStatus.mismatch,
          cachedFingerprint: 'OLD0-0000',
          onAcknowledgeChanged: (v) => reported = v,
        ),
      );
      expect(find.textContaining('fingerprint changed'), findsOneWidget);
      // The new fingerprint shows twice: the summary line and the "server
      // returned now" comparison row. The cached one appears only in the row.
      expect(find.text('NEW0-0000'), findsNWidgets(2));
      expect(find.text('OLD0-0000'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      expect(reported, isTrue);
    });
  });

  group('ShareRoleSelector', () {
    testWidgets('offers all three roles by default and reports a selection', (
      tester,
    ) async {
      ShareRole? picked;
      await _pump(
        tester,
        ShareRoleSelector(
          value: ShareRole.reader,
          onChanged: (r) => picked = r,
        ),
      );
      expect(find.text('Reader'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('Co-owner'), findsOneWidget);

      await tester.tap(find.text('Co-owner'));
      expect(picked, ShareRole.coOwner);
    });

    testWidgets('honours the server-advertised role subset', (tester) async {
      await _pump(
        tester,
        ShareRoleSelector(
          value: ShareRole.reader,
          available: const [ShareRole.reader, ShareRole.editor],
          onChanged: (_) {},
        ),
      );
      expect(find.text('Reader'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('Co-owner'), findsNothing);
    });
  });
}
