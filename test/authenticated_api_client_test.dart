import 'dart:convert';

import 'package:catlogue/services/authenticated_api_client.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Session extends SessionStore {
  String? token = 'expired';
  int refreshCount = 0;

  @override
  Future<String?> accessToken({bool refresh = false}) async {
    if (refresh) {
      refreshCount++;
      token = 'current';
    }
    return token;
  }
}

class _RequestFailure implements Exception {
  const _RequestFailure(this.message);
  final String message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'retries once with a refreshed token and retains the JSON body',
    () async {
      final session = _Session();
      addTearDown(session.dispose);
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('', requests.length == 1 ? 401 : 201);
      });
      addTearDown(client.close);

      final response = await AuthenticatedApiClient(session, client).request(
        'POST',
        '/social/invites',
        {'username': 'amiga'},
        accepted: {201},
        error: _RequestFailure.new,
        signInMessage: 'login',
        connectionMessage: 'offline',
      );

      expect(response.statusCode, 201);
      expect(session.refreshCount, 1);
      expect(requests.map((request) => request.headers['authorization']), [
        'Bearer expired',
        'Bearer current',
      ]);
      expect(requests.map((request) => jsonDecode(request.body)), [
        {'username': 'amiga'},
        {'username': 'amiga'},
      ]);
    },
  );

  test('returns API details through the caller-specific exception', () async {
    final session = _Session();
    addTearDown(session.dispose);
    final client = MockClient(
      (_) async => http.Response('{"detail":"Inválido"}', 422),
    );
    addTearDown(client.close);

    expect(
      () => AuthenticatedApiClient(session, client).request(
        'POST',
        '/social/invites',
        const {},
        accepted: {201},
        error: _RequestFailure.new,
        signInMessage: 'login',
        connectionMessage: 'offline',
      ),
      throwsA(
        isA<_RequestFailure>().having(
          (error) => error.message,
          'message',
          'Inválido',
        ),
      ),
    );
  });
}
