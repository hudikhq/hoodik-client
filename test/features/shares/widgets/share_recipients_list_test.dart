import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart' show ShareRole;
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/files/controllers/files_share_controller.dart';
import 'package:hoodik_app/features/files/providers/files_notifier.dart';
import 'package:hoodik_app/features/files/providers/files_state.dart';
import 'package:hoodik_app/features/shares/widgets/share_recipients_list.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

/// Serves a roster that shrinks once a revoke lands. [rosterAfterRevoke] is
/// returned by every [listRecipients] call after [revokeRecipient] succeeds,
/// modelling the server dropping the just-revoked recipient.
class _FakeShareController extends Fake implements FilesShareController {
  _FakeShareController({
    required this.initialRoster,
    required this.rosterAfterRevoke,
  });

  final List<AppShare> initialRoster;
  final List<AppShare> rosterAfterRevoke;
  bool _revoked = false;

  @override
  Future<List<AppShare>> listRecipients(String fileId) async =>
      _revoked ? rosterAfterRevoke : initialRoster;

  @override
  Future<ShareOutcome> revokeRecipient({
    required String fileId,
    required String userId,
    required ShareRole currentRole,
  }) async {
    _revoked = true;
    return const ShareOutcome.success();
  }
}

class _RecordingFilesNotifier extends FilesNotifier {
  final List<String> sharedInNone = [];

  @override
  FilesState build(String? arg) => const FilesState(loading: false);

  @override
  void markFileSharedInNone(String fileId) => sharedInNone.add(fileId);
}

AppShare _recipient(String id) => AppShare(
  fileId: 'f1',
  recipientId: id,
  recipientEmail: '$id@example.com',
  recipientPubkeyFingerprint: 'fp-$id',
  shareRole: ShareRole.reader,
  createdAt: 1,
);

void main() {
  Future<_RecordingFilesNotifier> pumpAndRevoke(
    WidgetTester tester, {
    required List<AppShare> initialRoster,
    required List<AppShare> rosterAfterRevoke,
  }) async {
    final notifier = _RecordingFilesNotifier();
    final controller = _FakeShareController(
      initialRoster: initialRoster,
      rosterAfterRevoke: rosterAfterRevoke,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesNotifierProvider.overrideWith(() => notifier),
          shareCryptoProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ShareRecipientsList(
              controller: controller,
              fileId: 'f1',
              dirId: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Revoke').first);
    await tester.pumpAndSettle();
    // Confirm in the adaptive alert.
    await tester.tap(find.text('Revoke').last);
    await tester.pumpAndSettle();

    return notifier;
  }

  testWidgets('revoking the last recipient clears the owner shared-out badge', (
    tester,
  ) async {
    final notifier = await pumpAndRevoke(
      tester,
      initialRoster: [_recipient('alice')],
      rosterAfterRevoke: const [],
    );

    expect(notifier.sharedInNone, ['f1']);
  });

  testWidgets('revoking when other recipients remain leaves the badge alone', (
    tester,
  ) async {
    final notifier = await pumpAndRevoke(
      tester,
      initialRoster: [_recipient('alice'), _recipient('bob')],
      rosterAfterRevoke: [_recipient('bob')],
    );

    expect(notifier.sharedInNone, isEmpty);
  });

  testWidgets('clears the badge on the last revoke even when the re-fetch still '
      'returns the removed recipient (read-after-write lag)', (tester) async {
    // The server hasn't caught up: the post-revoke roster still lists the
    // recipient just revoked. The badge must still clear, because the decision
    // is made from the roster shown at revoke time, not the stale re-fetch.
    final notifier = await pumpAndRevoke(
      tester,
      initialRoster: [_recipient('alice')],
      rosterAfterRevoke: [_recipient('alice')],
    );

    expect(notifier.sharedInNone, ['f1']);
  });
}
