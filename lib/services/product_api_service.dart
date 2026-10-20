import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'authenticated_api_client.dart';
import '../stores/session_store.dart';

class ProductApiException implements Exception {
  const ProductApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ProductApiService {
  ProductApiService(this.session, [this._client]);
  final http.Client? _client;
  final SessionStore session;
  Future<http.Response> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool retry = true,
  ]) async {
    try {
      return await AuthenticatedApiClient(session, _client).request(
        method,
        path,
        body,
        accepted: {for (var code = 200; code < 300; code++) code},
        error: ProductApiException.new,
        signInMessage: 'Entre na sua conta para continuar.',
        connectionMessage:
            'Não foi possível conectar. Confira sua conexão e tente novamente.',
        retried: !retry,
        responseError: (response) {
          var message = 'Não foi possível concluir. Tente novamente.';
          try {
            final detail = (jsonDecode(response.body) as Map)['detail'];
            if (detail is String) message = detail;
          } catch (_) {
            // Infrastructure errors may not contain a JSON response.
          }
          return ProductApiException(message, statusCode: response.statusCode);
        },
      );
    } on ProductApiException {
      rethrow;
    } catch (_) {
      throw const ProductApiException(
        'Não foi possível conectar. Confira sua conexão e tente novamente.',
      );
    }
  }

  Future<Map<String, dynamic>> get(String path) async =>
      Map<String, dynamic>.from(
        jsonDecode((await request('GET', path)).body) as Map,
      );
  Future<List<Map<String, dynamic>>> list(String path) async =>
      (jsonDecode((await request('GET', path)).body) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await request('POST', path, body ?? {});
    return response.body.isEmpty
        ? {}
        : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> put(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await request('PUT', path, body ?? {});
    return response.body.isEmpty
        ? {}
        : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Uint8List> photo(String path) async =>
      (await request('GET', path)).bodyBytes;
}
