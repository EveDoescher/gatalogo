import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/services/auth_api_service.dart';
import 'package:catlogue/models/auth_session.dart';

String token(int seconds) =>
    'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + seconds})))}.test';

class Api extends AuthApiService {
  int refreshes = 0;
  final pending = Completer<AuthSession>();
  @override
  Future<AuthSession> refresh({
    required String refreshToken,
    required String deviceId,
  }) {
    refreshes++;
    return pending.future;
  }

  @override
  Future<({String userId, String email})> me(String accessToken) =>
      throw StateError('Cached startup must not request profile');
}

class Store extends SessionStore {
  Store(Api api) : super(api: api);
  // Avoid websocket/push I/O; exercise the real credential state and storage.
  @override
  bool get isSignedIn => false;
  @override
  Future<String> deviceId() async => 'device-a';
  @override
  Future<void> syncAccountDetails() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  void seed(String access) => FlutterSecureStorage.setMockInitialValues({
    'auth_access_token': access,
    'auth_refresh_token': 'original-refresh',
    'auth_local_profile': jsonEncode({
      'user_id': 'player',
      'email': 'player@test.invalid',
    }),
  });
  test(
    'cached startup migrates one credential bundle without a profile request',
    () async {
      final access = token(3600);
      seed(access);
      final api = Api();
      final store = Store(api);
      addTearDown(store.dispose);
      await store.initialize();
      expect(store.isReady, true);
      expect(store.session!.accessToken, access);
      expect(api.refreshes, 0);
      final saved = jsonDecode(
        (await const FlutterSecureStorage().read(key: 'auth_session_v2'))!,
      );
      expect(saved['refresh_token'], 'original-refresh');
      expect(
        await const FlutterSecureStorage().read(key: 'auth_refresh_token'),
        isNull,
      );
    },
  );
  test(
    'parallel requests share renewal and rotation does not rebuild account',
    () async {
      seed(token(3600));
      final api = Api();
      final store = Store(api);
      addTearDown(store.dispose);
      await store.initialize();
      var changes = 0;
      store.addListener(() => changes++);
      final first = store.accessToken(refresh: true);
      final second = store.accessToken(refresh: true);
      await Future<void>.delayed(Duration.zero);
      expect(api.refreshes, 1);
      final access = token(3600);
      api.pending.complete(
        AuthSession(
          userId: 'player',
          email: 'player@test.invalid',
          accessToken: access,
          refreshToken: 'rotated',
        ),
      );
      expect(await Future.wait([first, second]), [access, access]);
      expect(changes, 0);
      final saved = jsonDecode(
        (await const FlutterSecureStorage().read(key: 'auth_session_v2'))!,
      );
      expect(saved['refresh_token'], 'rotated');
      expect(saved['access_token'], access);
    },
  );
  test(
    'temporary renewal failure retains account; rejection clears credentials',
    () async {
      for (final status in [503, 401]) {
        seed(token(3600));
        final api = Api();
        final store = Store(api);
        await store.initialize();
        final pending = store.accessToken(refresh: true);
        api.pending.completeError(
          AuthApiException('failure', statusCode: status),
        );
        expect(await pending, isNull);
        expect(store.session == null, status == 401);
        expect(
          await const FlutterSecureStorage().read(key: 'auth_session_v2') ==
              null,
          status == 401,
        );
        store.dispose();
      }
    },
  );
  test('a delayed renewal cannot restore a logged out account', () async {
    seed(token(3600));
    final api = Api();
    final store = Store(api);
    addTearDown(store.dispose);
    await store.initialize();
    final pending = store.accessToken(refresh: true);
    await Future<void>.delayed(Duration.zero);
    await store.clearLocalSession();
    api.pending.complete(
      AuthSession(
        userId: 'player',
        email: 'player@test.invalid',
        accessToken: token(3600),
        refreshToken: 'late',
      ),
    );
    expect(await pending, isNull);
    expect(store.session, isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'auth_session_v2'),
      isNull,
    );
  });
}
