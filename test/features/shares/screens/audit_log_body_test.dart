import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/share_event_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/widgets/adaptive.dart';
import 'package:hoodik_app/features/shares/providers/audit_log_notifier.dart';
import 'package:hoodik_app/features/shares/screens/audit_log_body.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

AppShareEvent _event({
  required String id,
  AuditEventAction action = AuditEventAction.grant,
  String? senderId = 'u-alice',
  String? recipientId = 'u-bob',
}) {
  return AppShareEvent(
    id: id,
    senderId: senderId,
    recipientId: recipientId,
    fileId: 'f-00000001-aaaa',
    action: action,
    shareRoleBefore: null,
    shareRoleAfter: ShareRole.editor,
    createdAt: 1700000000,
    prevEventHash: null,
    thisEventHash: 'hash',
    senderSignature: senderId == null ? null : 'sig',
    encryptedName: null,
    cipher: null,
    encryptedKey: null,
  );
}

AuditDisplayRow _row({
  required String id,
  required AuditRowBadge badge,
  ChainRowStatus chainStatus = ChainRowStatus.pageBoundary,
  AuditEventAction action = AuditEventAction.grant,
  String fileLabel = 'budget.xlsx',
  String? senderId = 'u-alice',
}) {
  return AuditDisplayRow(
    event: _event(id: id, action: action, senderId: senderId),
    senderEmail: senderId == null ? 'system' : 'alice@example.test',
    recipientEmail: 'bob@example.test',
    fileLabel: fileLabel,
    badge: badge,
    chainStatus: chainStatus,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpBody(WidgetTester tester, AuditLogState state) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          auditLogNotifierProvider.overrideWith(() => _StubNotifier(state)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AuditLogBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a row sentence and a verified badge', (tester) async {
    await pumpBody(
      tester,
      AuditLogState(
        rows: [_row(id: 'evt-1', badge: AuditRowBadge.verified)],
        total: 1,
      ),
    );

    expect(
      find.text(
        'alice@example.test shared budget.xlsx with '
        'bob@example.test as Editor',
      ),
      findsOneWidget,
    );
    expect(find.text('Verified'), findsWidgets);
  });

  testWidgets('a tampered row shows the mismatch badge and banner', (
    tester,
  ) async {
    await pumpBody(
      tester,
      AuditLogState(
        rows: [
          _row(
            id: 'evt-1',
            badge: AuditRowBadge.tampered,
            chainStatus: ChainRowStatus.selfHashMismatch,
          ),
        ],
        total: 1,
      ),
    );

    expect(find.text('Mismatch'), findsWidgets);
    expect(
      find.text('Row content does not match its stored hash.'),
      findsOneWidget,
    );
  });

  testWidgets('a system row shows the system badge', (tester) async {
    await pumpBody(
      tester,
      AuditLogState(
        rows: [
          _row(
            id: 'evt-1',
            badge: AuditRowBadge.system,
            action: AuditEventAction.sharedFolderEvict,
            senderId: null,
          ),
        ],
        total: 1,
      ),
    );

    expect(find.text('System'), findsWidgets);
    expect(
      find.textContaining('lost access to budget.xlsx (cascade)'),
      findsOneWidget,
    );
  });

  testWidgets('shows the empty state when there are no events', (tester) async {
    await pumpBody(tester, const AuditLogState(rows: [], total: 0));
    expect(find.byKey(const ValueKey('audit-empty')), findsOneWidget);
  });

  Future<void> pumpError(WidgetTester tester, Object error) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          auditLogNotifierProvider.overrideWith(() => _ErrorNotifier(error)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AuditLogBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a non-connectivity error shows the neutral message + retry', (
    tester,
  ) async {
    await pumpError(tester, StateError('page failed to parse'));

    expect(find.text("Couldn't load your sharing activity."), findsOneWidget);
    expect(find.textContaining('try again once you are'), findsNothing);
    // Query the platform-agnostic AdaptiveButton so this passes on both the
    // macOS (Cupertino) and Android (Material) test hosts.
    expect(find.widgetWithText(AdaptiveButton, 'Retry'), findsOneWidget);
  });

  testWidgets('a connectivity error shows the offline message', (tester) async {
    await pumpError(
      tester,
      DioException(
        requestOptions: RequestOptions(path: '/api/shares/events'),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(find.textContaining('try again once you are'), findsOneWidget);
    expect(find.text("Couldn't load your sharing activity."), findsNothing);
    expect(find.widgetWithText(AdaptiveButton, 'Retry'), findsOneWidget);
  });

  testWidgets('tapping Retry invokes the notifier refresh', (tester) async {
    final notifier = _ErrorNotifier(StateError('boom'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [auditLogNotifierProvider.overrideWith(() => notifier)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AuditLogBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AdaptiveButton, 'Retry'));
    await tester.pump();

    expect(notifier.refreshCalls, 1);
  });

  testWidgets('notes when the page is capped below the total', (tester) async {
    await pumpBody(
      tester,
      AuditLogState(
        rows: [_row(id: 'evt-1', badge: AuditRowBadge.verified)],
        total: 250,
      ),
    );
    expect(
      find.textContaining('Showing the 1 most recent of 250 events.'),
      findsOneWidget,
    );
  });
}

/// Serves a fixed [AuditLogState] so the widget tests exercise the body's
/// rendering without the crypto verify pass (covered by the notifier test).
class _StubNotifier extends AuditLogNotifier {
  _StubNotifier(this._state);
  final AuditLogState _state;
  @override
  Future<AuditLogState> build() async => _state;
}

/// Fails its initial load with a fixed error so the body renders its error
/// branch, and counts [refresh] calls so the Retry wiring can be asserted.
class _ErrorNotifier extends AuditLogNotifier {
  _ErrorNotifier(this._error);
  final Object _error;
  int refreshCalls = 0;

  @override
  Future<AuditLogState> build() async => throw _error;

  @override
  Future<void> refresh() async => refreshCalls++;
}
