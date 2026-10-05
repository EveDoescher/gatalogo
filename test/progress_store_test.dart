import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/services/product_api_service.dart';
import 'package:catlogue/services/progress_service.dart';

class Account extends SessionStore {
  String owner = 'first';
  @override
  bool get isSignedIn => true;
  @override
  AuthSession get session => AuthSession(
    userId: owner,
    email: 'test@local',
    accessToken: 'token',
    refreshToken: 'token',
  );
}

class Server extends ProductApiService {
  Server(super.session);
  Future<Map<String, dynamic>> Function() load = () async => {
    'rule_version': 2,
    'xp': 20,
    'achievements': [],
  };
  @override
  Future<Map<String, dynamic>> get(String path) => load();
  @override
  Future<List<Map<String, dynamic>>> list(String path) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'account switch discards a delayed result from the previous account',
    () async {
      final account = Account();
      final server = Server(account);
      final progress = ProgressService(account, api: server);
      final response = Completer<Map<String, dynamic>>();
      server.load = () => response.future;
      final first = progress.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      account.owner = 'second';
      progress.reset();
      server.load = () async => {'rule_version': 2, 'xp': 77};
      await progress.refresh();
      response.complete({'rule_version': 2, 'xp': 999});
      await first;
      expect(progress.summary['xp'], 77);
      expect(progress.offline, false);
      progress.dispose();
      account.dispose();
    },
  );
  test(
    'offline read preserves confirmed progress and reset clears all selectors',
    () async {
      final account = Account();
      final server = Server(account);
      final progress = ProgressService(account, api: server);
      server.load = () async => {
        'rule_version': 2,
        'xp': 500,
        'achievements': [
          {'id': 'first', 'completed': true},
        ],
        'daily_missions': [
          {'id': 'daily_record', 'progress': 1},
        ],
      };
      await progress.refresh();
      server.load = () async => throw Exception('offline');
      await progress.refresh();
      expect(progress.summary['xp'], 500);
      expect(progress.achievements.single['completed'], true);
      expect(progress.offline, true);
      progress.reset();
      expect(progress.summary, isEmpty);
      expect(progress.results, isEmpty);
      expect(progress.dailyMissions, isEmpty);
      progress.dispose();
      account.dispose();
    },
  );
}
