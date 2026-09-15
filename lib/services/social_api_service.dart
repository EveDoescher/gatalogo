import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../stores/session_store.dart';

class SocialApiException implements Exception {
  const SocialApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SocialApiService {
  SocialApiService(this._sessionStore);
  final SessionStore _sessionStore;

  Future<void> chooseUsername(String username) async {
    await _request(
      'PUT',
      '/auth/username',
      {'username': username.toLowerCase()},
      accepted: {200},
    );
  }

  Future<void> invite(String username) async {
    await _request(
      'POST',
      '/social/invites',
      {'username': username.toLowerCase()},
      accepted: {201},
    );
  }

  Future<void> decideInvite(String id, bool accepted) async {
    await _request(
      'POST',
      '/social/invites/$id/${accepted ? 'accept' : 'reject'}',
      const {},
      accepted: {200},
    );
  }

  Future<void> removeFriend(String id) async {
    await _request('DELETE', '/social/friends/$id', null, accepted: {204});
  }

  Future<void> registerDeviceToken(String token) async {
    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    await _request(
      'PUT',
      '/social/device-token',
      {
        'token': token,
        'platform': platform,
        'preferences': {
          'sighting_notifications': true,
          'social_notifications': true,
        },
      },
      accepted: {204},
    );
  }

  Future<List<Map<String, dynamic>>> invites() => _list('/social/invites');
  Future<List<Map<String, dynamic>>> friends() => _list('/social/friends');
  Future<List<Map<String, dynamic>>> feed() => _list('/social/feed');
  Future<List<Map<String, dynamic>>> messages(String conversationId) =>
      _list('/social/conversations/$conversationId/messages');

  Future<void> sendMessage(String conversationId, String body) async {
    await _request(
      'POST',
      '/social/conversations/$conversationId/messages',
      {'body': body},
      accepted: {201},
    );
  }

  Future<Map<String, dynamic>> createPost({
    required String catName,
    String note = '',
    String? locationName,
    String? photoBase64,
  }) async {
    final response = await _request(
      'POST',
      '/social/posts',
      {
        'cat_name': catName,
        'note': note,
        'location_name': locationName,
        'photo_base64': photoBase64,
      },
      accepted: {201},
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> toggleLike(String itemId) async {
    final response = await _request(
      'POST',
      '/social/feed/$itemId/like',
      {},
      accepted: {200},
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Map<String, dynamic>>> addComment(String itemId, String text) async {
    final response = await _request(
      'POST',
      '/social/feed/$itemId/comments',
      {'text': text},
      accepted: {200},
    );
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Map<String, dynamic>> updateAccount({String? username, String? bio}) async {
    final response = await _request(
      'PUT',
      '/app/account',
      {
        ...?username == null ? null : {'username': username},
        ...?bio == null ? null : {'bio': bio},
      },
      accepted: {200},
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<String?> uploadAvatar(List<int> imageBytes, String filename) async {
    final token = await _sessionStore.accessToken();
    if (token == null) return null;
    final uri = Uri.parse('${ApiConfig.baseUrl}/app/account/avatar');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: filename));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map;
      return decoded['avatar_url'] as String?;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _list(String path) async {
    final response = await _request('GET', path, null, accepted: {200});
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
      throw const SocialApiException('Entre na sua conta para usar amigos.');
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
        throw SocialApiException(_message(response));
      }
      return response;
    } on SocialApiException {
      rethrow;
    } catch (_) {
      throw const SocialApiException('Não foi possível acessar amigos agora.');
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
