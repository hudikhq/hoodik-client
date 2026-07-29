import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/utils/account_context.dart';

void main() {
  tearDown(AccountContext.clear);

  test('defaults to null before any account is active', () {
    expect(AccountContext.current, isNull);
  });

  test('set with both email and server builds the label', () {
    AccountContext.set(
      email: 'owner@example.test',
      serverHost: 'files.example.test',
    );
    expect(AccountContext.current, 'owner@example.test / files.example.test');
  });

  test('set with null email clears the label', () {
    AccountContext.set(email: 'a@b.c', serverHost: 'host');
    AccountContext.set(email: null, serverHost: 'host');
    expect(AccountContext.current, isNull);
  });

  test('set with empty email clears the label', () {
    AccountContext.set(email: 'a@b.c', serverHost: 'host');
    AccountContext.set(email: '', serverHost: 'host');
    expect(AccountContext.current, isNull);
  });

  test('set with null serverHost clears the label', () {
    AccountContext.set(email: 'a@b.c', serverHost: 'host');
    AccountContext.set(email: 'a@b.c', serverHost: null);
    expect(AccountContext.current, isNull);
  });

  test('clear() resets the label regardless of prior state', () {
    AccountContext.set(email: 'a@b.c', serverHost: 'host');
    AccountContext.clear();
    expect(AccountContext.current, isNull);
  });
}
