import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/services/auth_api_service.dart';
import 'package:catlogue/services/catalog_sync_service.dart';
import 'package:catlogue/stores/notification_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../tool/campaign_resilience_test.dart' as sync_fixture;
import 'session_store_test.dart' as auth_fixture;

class _RetryApi extends auth_fixture.Api {
  Completer<AuthSession> reply = Completer<AuthSession>();

  @override
  Future<AuthSession> refresh({
    required String refreshToken,
    required String deviceId,
  }) {
    refreshes++;
    return reply.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final count in [2, 8, 25]) {
    test('RES07 sync $count triggers recover after failure', () async {
      final account = sync_fixture.Account();
      addTearDown(account.dispose);
      final sync = CatalogSyncService(
        account,
        database: sync_fixture.Storage(),
      );
      var reply = Completer<http.Response>();
      var calls = 0;
      final client = MockClient((_) {
        calls++;
        return reply.future;
      });
      await http.runWithClient(() async {
        final failed = List.generate(count, (_) => sync.sync());
        await Future<void>.delayed(Duration.zero);
        expect(calls, 1);
        reply.completeError(const SocketException('controlled offline'));
        expect(await Future.wait(failed), everyElement(false));
        reply = Completer<http.Response>();
        final retry = List.generate(count, (_) => sync.sync());
        await Future<void>.delayed(Duration.zero);
        expect(calls, 2);
        reply.complete(http.Response('{"changes":[],"next_cursor":0}', 200));
        expect(await Future.wait(retry), everyElement(true));
        expect(calls, 2);
      }, () => client);
    });

    test('RES07 inbox $count refreshes recover after failure', () async {
      var calls = 0;
      var reply = Completer<List<Map<String, dynamic>>>();
      final store = NotificationStore(
        loadItems: () {
          calls++;
          return reply.future;
        },
        saveRead: (_) async {},
      );
      addTearDown(store.dispose);
      final failures = Future.wait(
        List.generate(count, (_) async {
          try {
            await store.refresh();
            return false;
          } on StateError {
            return true;
          }
        }),
      );
      expect(calls, 1);
      reply.completeError(StateError('controlled offline'));
      expect(await failures, everyElement(true));
      expect(store.items, isEmpty);
      reply = Completer<List<Map<String, dynamic>>>();
      final retry = List.generate(count, (_) => store.refresh());
      expect(calls, 2);
      reply.complete([
        {'id': 'one', 'read_at': null},
      ]);
      await Future.wait(retry);
      expect(calls, 2);
      expect(store.items.single['id'], 'one');
      expect(store.unreadCount, 1);
    });

    test(
      'RES07 auth $count renewals recover after transient failure',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'auth_access_token': auth_fixture.token(3600),
          'auth_refresh_token': 'synthetic-refresh',
          'auth_local_profile': jsonEncode({
            'user_id': 'player',
            'email': 'player@test.invalid',
          }),
        });
        final api = _RetryApi();
        final store = auth_fixture.Store(api);
        addTearDown(store.dispose);
        await store.initialize();
        final failed = List.generate(
          count,
          (_) => store.accessToken(refresh: true),
        );
        await Future<void>.delayed(Duration.zero);
        expect(api.refreshes, 1);
        api.reply.completeError(
          const AuthApiException('controlled unavailable', statusCode: 503),
        );
        expect(await Future.wait(failed), everyElement(isNull));
        expect(store.session?.userId, 'player');
        api.reply = Completer<AuthSession>();
        final retry = List.generate(
          count,
          (_) => store.accessToken(refresh: true),
        );
        await Future<void>.delayed(Duration.zero);
        expect(api.refreshes, 2);
        final access = auth_fixture.token(7200);
        api.reply.complete(
          AuthSession(
            userId: 'player',
            email: 'player@test.invalid',
            accessToken: access,
            refreshToken: 'rotated-synthetic',
          ),
        );
        expect(await Future.wait(retry), everyElement(access));
        expect(api.refreshes, 2);
        final saved = jsonDecode(
          (await const FlutterSecureStorage().read(key: 'auth_session_v2'))!,
        );
        expect(saved['refresh_token'], 'rotated-synthetic');
      },
    );
  }
}
