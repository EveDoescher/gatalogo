import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../stores/session_store.dart';

class ProductApiException implements Exception {
  const ProductApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ProductApiService {
  ProductApiService(this.session);
  final SessionStore session;
  Future<http.Response> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool retry = true,
  ]) async {
    final token = await session.accessToken();
    if (token == null) {
      throw const ProductApiException('Entre na sua conta para continuar.');
    }
    try {
      final request = http.Request(
        method,
        Uri.parse('${ApiConfig.baseUrl}$path'),
      )..headers['Authorization'] = 'Bearer $token';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 25)),
      ).timeout(const Duration(seconds: 25));
      if (response.statusCode == 401 &&
          retry &&
          await session.accessToken(refresh: true) != null) {
        return await this.request(method, path, body, false);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Não foi possível concluir. Tente novamente.';
        try {
          final detail = (jsonDecode(response.body) as Map)['detail'];
          if (detail is String) message = detail;
        } catch (_) {}
        throw ProductApiException(message);
      }
      return response;
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

  Future<Uint8List> photo(String path) async =>
      (await request('GET', path)).bodyBytes;
}
