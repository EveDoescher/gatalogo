import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../stores/session_store.dart';

class VisionApiException implements Exception {
  const VisionApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class VisionApiService {
  VisionApiService(this._sessionStore);
  final SessionStore _sessionStore;

  Future<void> createMissingReport({
    required String catId,
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    await _request(
      'POST',
      '/vision/missing-reports',
      {
        'cat_client_id': catId,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
      },
      accepted: {201},
    );
  }

  Future<void> createSighting({
    required String catId,
    required double latitude,
    required double longitude,
    String? note,
    DateTime? observedAt,
  }) async {
    await _request(
      'POST',
      '/vision/sightings',
      {
        'cat_client_id': catId,
        'latitude': latitude,
        'longitude': longitude,
        'note': ?note,
        if (observedAt != null)
          'observed_at': observedAt.toUtc().toIso8601String(),
      },
      accepted: {201},
    );
  }

  Future<List<Map<String, dynamic>>> matches() async {
    final response = await _request(
      'GET',
      '/vision/matches',
      null,
      accepted: {200},
    );
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> decideMatch(String id, bool confirmed) async {
    await _request(
      'POST',
      '/vision/matches/$id/${confirmed ? 'confirm' : 'dismiss'}',
      const {},
      accepted: {200},
    );
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final response = await _request(
      'GET',
      '/vision/notifications',
      null,
      accepted: {200},
    );
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<http.Response> _request(
    String method,
    String path,
    Map<String, dynamic>? body, {
    required Set<int> accepted,
    bool retried = false,
  }) async {
    final token = await _sessionStore.accessToken();
    if (token == null) {
      throw const VisionApiException(
        'Entre na sua conta para usar alertas de desaparecimento.',
      );
    }
    final request = http.Request(method, Uri.parse('${ApiConfig.baseUrl}$path'))
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);
    try {
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 25)),
      ).timeout(const Duration(seconds: 25));
      if (response.statusCode == 401 && !retried) {
        final refreshed = await _sessionStore.accessToken(refresh: true);
        if (refreshed != null) {
          return await _request(
            method,
            path,
            body,
            accepted: accepted,
            retried: true,
          );
        }
      }
      if (!accepted.contains(response.statusCode)) {
        throw VisionApiException(_message(response));
      }
      return response;
    } on VisionApiException {
      rethrow;
    } catch (_) {
      throw const VisionApiException(
        'Não foi possível acessar os alertas agora.',
      );
    }
  }

  String _message(http.Response response) {
    try {
      final map = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      return map['detail']?.toString() ??
          'Não foi possível concluir esta operação.';
    } catch (_) {
      return 'Não foi possível concluir esta operação.';
    }
  }
}
