import 'dart:convert';

import 'package:catlogue/services/product_api_service.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Session extends SessionStore {
  String? token = 'expired';
  int refreshes = 0;
  @override
  Future<String?> accessToken({bool refresh = false}) async {
    if (refresh) {
      refreshes++;
      token = 'current';
    }
    return token;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Session session;
  setUp(() => session = _Session());
  tearDown(() => session.dispose());

  test('product retries once and preserves JSON and authorization', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('{}', requests.length == 1 ? 401 : 201);
    });
    addTearDown(client.close);
    await ProductApiService(session, client).post('/app/example', {'value': 1});
    expect(session.refreshes, 1);
    expect(requests.map((r) => r.headers['authorization']), [
      'Bearer expired',
      'Bearer current',
    ]);
    expect(requests.map((r) => jsonDecode(r.body)), [
      {'value': 1},
      {'value': 1},
    ]);
  });

  test('a second unauthorized response retains its status and stops', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{"detail":"Expirou"}', 401);
    });
    addTearDown(client.close);
    await expectLater(
      ProductApiService(session, client).get('/app/example'),
      throwsA(
        isA<ProductApiException>()
            .having((e) => e.statusCode, 'status', 401)
            .having((e) => e.message, 'message', 'Expirou'),
      ),
    );
    expect(calls, 2);
    expect(session.refreshes, 1);
  });

  test('explicit retry false does not refresh', () async {
    final client = MockClient((_) async => http.Response('', 401));
    addTearDown(client.close);
    await expectLater(
      ProductApiService(
        session,
        client,
      ).request('GET', '/app/example', null, false),
      throwsA(
        isA<ProductApiException>().having((e) => e.statusCode, 'status', 401),
      ),
    );
    expect(session.refreshes, 0);
  });

  for (final code in [200, 201, 204, 299]) {
    test('accepts success $code including an empty body', () async {
      final client = MockClient((_) async => http.Response('', code));
      addTearDown(client.close);
      expect(
        await ProductApiService(session, client).post('/app/example'),
        isEmpty,
      );
    });
  }

  for (final body in ['not json', '{"detail":[{"msg":"bad"}]}']) {
    test('preserves fallback and status for $body', () async {
      final client = MockClient((_) async => http.Response(body, 422));
      addTearDown(client.close);
      await expectLater(
        ProductApiService(session, client).get('/app/example'),
        throwsA(
          isA<ProductApiException>()
              .having((e) => e.statusCode, 'status', 422)
              .having(
                (e) => e.message,
                'message',
                'Não foi possível concluir. Tente novamente.',
              ),
        ),
      );
    });
  }

  test('missing session does not send a request', () async {
    session.token = null;
    final client = MockClient((_) async => fail('No request expected'));
    addTearDown(client.close);
    await expectLater(
      ProductApiService(session, client).get('/app/example'),
      throwsA(
        isA<ProductApiException>().having(
          (e) => e.message,
          'message',
          'Entre na sua conta para continuar.',
        ),
      ),
    );
  });

  test('connection failure keeps the product-specific message', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    addTearDown(client.close);
    await expectLater(
      ProductApiService(session, client).get('/app/example'),
      throwsA(
        isA<ProductApiException>().having(
          (e) => e.message,
          'message',
          'Não foi possível conectar. Confira sua conexão e tente novamente.',
        ),
      ),
    );
  });
}
