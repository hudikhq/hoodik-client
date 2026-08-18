import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads the source rather than the behaviour, which needs justifying.
///
/// The rule below is the one that decides whether a transfer can survive the
/// app being killed at all, and it broke once already by being quietly true in
/// the wrong place. Exercising it for real means driving `FileDownloader`, a
/// plugin singleton that starts platform work the moment it is touched and has
/// no seam to substitute — the harness for that would be larger than the code
/// it guards, and would itself be the thing most likely to rot.
///
/// So this asserts the shape of the call instead. It is a weaker check than a
/// behavioural one, and it is here because the failure it prevents is silent:
/// transfers simply never resume, and every test still passes.
void main() {
  final source = File(
    'lib/core/services/file_downloader_config.dart',
  ).readAsStringSync();

  String bodyOf(String signature) {
    final start = source.indexOf(signature);
    expect(start, isNot(-1), reason: '$signature has been renamed or removed');

    var depth = 0;
    var seenOpen = false;
    for (var i = start; i < source.length; i++) {
      if (source[i] == '{') {
        depth++;
        seenOpen = true;
      } else if (source[i] == '}') {
        depth--;
        if (seenOpen && depth == 0) return source.substring(start, i + 1);
      }
    }
    fail('could not find the end of $signature');
  }

  // The cleanup cancels every task in every group. Calling it from the
  // configure path means it runs the first time anything touches the
  // downloader, which on a cold start is before the app has adopted anything —
  // so the transfers the OS carried through a kill are destroyed on the next
  // launch, and a large download can never finish. It belongs on sign-out.
  test('configuring the downloader does not cancel what the OS is carrying', () {
    final body = bodyOf('Future<void> _doConfigure() async {');

    expect(
      body,
      isNot(contains('cleanUpFileDownloader')),
      reason:
          'cleanUpFileDownloader cancels every task in every group. From '
          '_doConfigure it runs on every cold start, which makes surviving an '
          'app kill impossible. Call it from sign-out instead.',
    );
    expect(body, isNot(contains('cancelAll')));
  });

  // Only tasks enqueued while tracking is on are recorded, so this has to
  // happen during configuration and before anything is queued. Without it the
  // plugin's database stays empty, adoptTransfersForAccount adopts nothing,
  // and rescheduleKilledTasks is a no-op — the whole reconcile goes quiet
  // rather than failing.
  test('configuring the downloader turns task tracking on', () {
    expect(
      bodyOf('Future<void> _doConfigure() async {'),
      contains('trackTasks'),
    );
  });

  // Every group the app enqueues into has to be listed, or cleanup, adoption
  // and the notification wiring all skip it silently.
  test('every task group the app uses is managed', () {
    final groups = RegExp(r"static const String group = '([^']+)'")
        .allMatches(
          Directory('lib/core/services')
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .map((f) => f.readAsStringSync())
              .join('\n'),
        )
        .map((m) => m.group(1)!)
        .toSet();

    expect(groups, isNotEmpty, reason: 'no service declares a group any more');
    for (final group in groups) {
      expect(
        source,
        contains("'$group'"),
        reason: '$group is enqueued into but not in _managedGroups',
      );
    }
  });
}
