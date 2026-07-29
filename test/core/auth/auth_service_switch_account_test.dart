import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/auth/auth_service.dart';
import 'package:hoodik_app/core/auth/secure_pin_storage.dart';
import 'package:hoodik_app/core/storage/database.dart';

/// Fake AuthClient that records calls to [getSelf] and can be scripted to
/// throw or return a specific response.
class _FakeAuthClient extends Fake implements AuthClient {
  _FakeAuthClient({this.getSelfError, this.getSelfResponse});

  Object? getSelfError;
  AuthResponse? getSelfResponse;
  int getSelfCalls = 0;

  @override
  Future<AuthResponse> getSelf() async {
    getSelfCalls++;
    if (getSelfError != null) throw getSelfError!;
    return getSelfResponse ?? AuthResponse(user: const {'id': 'u1'});
  }
}

/// Thin ApiClient stub for switchAccount tests.
///
/// Delegates auth-related calls through the [auth] sub-client so the
/// behaviour matches the sub-client coordinator pattern AuthService uses
/// in production.
class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient({
    Object? getSelfError,
    AuthResponse? getSelfResponse,
    this.sessionPresent = true,
  }) : _auth = _FakeAuthClient(
         getSelfError: getSelfError,
         getSelfResponse: getSelfResponse,
       );

  final _FakeAuthClient _auth;
  bool sessionPresent;

  int get getSelfCalls => _auth.getSelfCalls;
  int startTimerCalls = 0;

  @override
  AuthClient get auth => _auth;

  @override
  bool useHeaderAuth = false;

  @override
  void Function()? onSessionExpired;

  @override
  void Function(String jwt, String refresh)? onTokensUpdated;

  @override
  Future<bool> get hasSession async => sessionPresent;

  @override
  void updateSessionExpiry(AuthResponse authResp) {}

  @override
  void startSessionRefreshTimer() => startTimerCalls++;

  @override
  void stopSessionRefreshTimer() {}

  @override
  void setTokens({required String jwt, required String refresh}) {}
}

/// In-memory stub so [AuthService] can call pin-storage methods without
/// hitting the real platform keychain channel.
class _FakePinStorage extends SecurePinStorage {
  _FakePinStorage() : super.forTesting(const FlutterSecureStorage());

  @override
  Future<String?> read(String accountId) async => null;

  @override
  Future<bool> has(String accountId) async => false;
}

void main() {
  late AppDatabase db;
  late _FakePinStorage pinStorage;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    pinStorage = _FakePinStorage();

    await db.insertServer(
      ServersCompanion(
        id: const Value('s1'),
        url: const Value('https://example.com'),
        name: const Value('Test Server'),
      ),
    );
    await db.insertAccount(
      AccountsCompanion(
        id: const Value('a1'),
        serverId: const Value('s1'),
        userId: const Value('u1'),
        email: const Value('a@test.io'),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('AuthService.switchAccount', () {
    test(
      'rethrows and leaves activeClient unchanged when getSelf fails',
      () async {
        final fake = _FakeApiClient(getSelfError: Exception('network down'));
        final service = AuthService(
          db,
          pinStorage,
          clientFactory: ({required String baseUrl, String? accountId}) async =>
              fake,
        );

        expect(service.activeClient, isNull);

        await expectLater(
          service.switchAccount('a1'),
          throwsA(isA<Exception>()),
        );

        // Ensure the silent-proceed path is gone: no client should be wired up
        // and the session refresh timer should never have been started.
        expect(service.activeClient, isNull);
        expect(fake.getSelfCalls, 1);
        expect(fake.startTimerCalls, 0);
      },
    );

    test('happy path sets active client when getSelf succeeds', () async {
      final fake = _FakeApiClient(
        getSelfResponse: AuthResponse(
          user: const {'id': 'u1'},
          session: SessionInfo.fromJson(const {'expires_at': 1700000000}),
        ),
      );
      final service = AuthService(
        db,
        pinStorage,
        clientFactory: ({required String baseUrl, String? accountId}) async =>
            fake,
      );

      final ok = await service.switchAccount('a1');

      expect(ok, isTrue);
      expect(service.activeClient, same(fake));
      expect(service.activeAccount?.id, 'a1');
      expect(fake.startTimerCalls, 1);
    });

    test('returns false when hasSession reports no session', () async {
      final fake = _FakeApiClient(sessionPresent: false);
      final service = AuthService(
        db,
        pinStorage,
        clientFactory: ({required String baseUrl, String? accountId}) async =>
            fake,
      );

      final ok = await service.switchAccount('a1');

      expect(ok, isFalse);
      expect(service.activeClient, isNull);
      expect(fake.getSelfCalls, 0);
    });
  });
}
