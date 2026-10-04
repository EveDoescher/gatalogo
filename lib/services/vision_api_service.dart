import 'dart:convert';

import 'package:http/http.dart' as http;

import '../stores/session_store.dart';
import 'authenticated_api_client.dart';

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
    String? clientEventId,
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
        'client_event_id': ?clientEventId,
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
  }) async {
    return AuthenticatedApiClient(_sessionStore).request(
      method,
      path,
      body,
      accepted: accepted,
      error: VisionApiException.new,
      signInMessage: 'Entre na sua conta para usar alertas de desaparecimento.',
      connectionMessage: 'Não foi possível acessar os alertas agora.',
    );
  }
}
