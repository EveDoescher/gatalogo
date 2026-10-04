import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/services/gamification_service.dart';
import 'package:catlogue/services/product_api_service.dart';
import 'package:catlogue/stores/session_store.dart';

class Account extends SessionStore {
  String owner = 'first';
  @override
  bool get isSignedIn => true;
  @override
  AuthSession get session => AuthSession(
    userId: owner,
    email: 'test@example.org',
    accessToken: 'test',
    refreshToken: 'test',
  );
}

class ProgressApi extends ProductApiService {
  ProgressApi(super.session);
  Future<Map<String, dynamic>> Function() load = () async => {'xp': 20};
  Future<Map<String, dynamic>> Function() action = () async => {
    'xp': 50,
    'earned_xp': 30,
  };
  @override
  Future<Map<String, dynamic>> get(String path) => load();
  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) => action();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'refresh and action are ordered so old XP cannot overwrite a reward',
    () async {
      final session = Account();
      final api = ProgressApi(session);
      final pending = Completer<Map<String, dynamic>>();
      api.load = () => pending.future;
      final service = GamificationService(session, api: api);
      final refresh = service.loadGamification();
      final action = service.recordAction('post');
      pending.complete({'xp': 20});
      await refresh;
      expect((await action).earnedXp, 30);
      expect(service.currentState.xp, 50);
      session.dispose();
    },
  );

  test(
    'network errors preserve confirmed XP without fictitious rewards',
    () async {
      final session = Account();
      final api = ProgressApi(session);
      final service = GamificationService(session, api: api);
      await service.loadGamification();
      api.action = () async => throw Exception('offline');
      final result = await service.recordAction('post');
      expect(result.earnedXp, 0);
      expect(result.state.xp, 20);
      expect(result.levelUp, false);
      session.dispose();
    },
  );

  test(
    'switching accounts rejects an old response and uses a separate cache',
    () async {
      final session = Account();
      final api = ProgressApi(session);
      final pending = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      api.load = () {
        started.complete();
        return pending.future;
      };
      final service = GamificationService(session, api: api);
      final first = service.loadGamification();
      await started.future;
      session.owner = 'second';
      service.reset();
      api.load = () async => {'xp': 80};
      await service.loadGamification();
      pending.complete({'xp': 500});
      await first;
      expect(service.currentState.xp, 80);
      final cache = await const FlutterSecureStorage().read(
        key: 'local_gamification_cache_second',
      );
      expect(jsonDecode(cache!)['xp'], 80);
      session.dispose();
    },
  );
}
