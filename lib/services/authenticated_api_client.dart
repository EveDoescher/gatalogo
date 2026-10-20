import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../stores/session_store.dart';

class AuthenticatedApiClient {
  const AuthenticatedApiClient(this.session, [this._client]);

  final SessionStore session;
  final http.Client? _client;

  Future<http.Response> request(
    String method,
    String path,
    Map<String, dynamic>? body, {
    required Set<int> accepted,
    required Exception Function(String) error,
    required String signInMessage,
    required String connectionMessage,
    bool retried = false,
    Exception Function(http.Response)? responseError,
  }) async {
    final token = await session.accessToken();
    if (token == null) throw error(signInMessage);

    final request = http.Request(method, Uri.parse('${ApiConfig.baseUrl}$path'))
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    late final http.Response response;
    try {
      response = await http.Response.fromStream(
        await (_client?.send(request) ?? request.send()).timeout(
          const Duration(seconds: 25),
        ),
      ).timeout(const Duration(seconds: 25));
    } catch (_) {
      throw error(connectionMessage);
    }

    if (response.statusCode == 401 &&
        !retried &&
        await session.accessToken(refresh: true) != null) {
      return this.request(
        method,
        path,
        body,
        accepted: accepted,
        error: error,
        signInMessage: signInMessage,
        connectionMessage: connectionMessage,
        retried: true,
        responseError: responseError,
      );
    }
    if (!accepted.contains(response.statusCode)) {
      throw responseError?.call(response) ?? error(_errorMessage(response));
    }
    return response;
  }

  String _errorMessage(http.Response response) {
    try {
      final detail = (jsonDecode(response.body) as Map)['detail'];
      if (detail != null) return detail.toString();
    } catch (_) {
      // A resposta pode não conter JSON em falhas de infraestrutura.
    }
    return 'Não foi possível concluir esta operação.';
  }
}
