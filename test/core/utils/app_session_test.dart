import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/utils/app_session.dart';

void main() {
  setUp(AppSession.resetForTests);
  tearDown(AppSession.resetForTests);

  test('startedAt defaults to the epoch before start() is called', () {
    expect(AppSession.startedAt.millisecondsSinceEpoch, 0);
  });

  test('start() stamps the session with the current instant', () {
    final before = DateTime.now();
    AppSession.start();
    final after = DateTime.now();

    final started = AppSession.startedAt;
    expect(started.isAtSameMomentAs(before) || started.isAfter(before), isTrue);
    expect(started.isAtSameMomentAs(after) || started.isBefore(after), isTrue);
  });

  test('start() is idempotent — a second call does not move the boundary', () {
    AppSession.start();
    final first = AppSession.startedAt;
    AppSession.start();
    expect(AppSession.startedAt, first);
  });

  test('setForTests bypasses the idempotence guard', () {
    AppSession.start();
    final override = DateTime(2020, 1, 1, 12);
    AppSession.setForTests(override);
    expect(AppSession.startedAt, override);
  });
}
