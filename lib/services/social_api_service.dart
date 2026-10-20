import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../stores/session_store.dart';
import 'authenticated_api_client.dart';

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

  Future<void> acceptInvite(String id) => decideInvite(id, true);
  Future<void> rejectInvite(String id) => decideInvite(id, false);

  Future<void> removeFriend(String id) async {
    await _request('DELETE', '/social/friends/$id', null, accepted: {204});
  }

  Future<void> cancelInvite(String id) async {
    await _request('DELETE', '/social/invites/$id', null, accepted: {204});
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) =>
      _list('/social/users/search?q=${Uri.encodeComponent(query)}');

  Future<List<Map<String, dynamic>>> getSuggestions({bool nearby = false}) =>
      _list('/social/suggestions?nearby=$nearby');

  Future<Map<String, dynamic>> getPublicProfile(String username) async {
    final response = await _request(
      'GET',
      '/social/profiles/${Uri.encodeComponent(username.toLowerCase())}',
      null,
      accepted: {200},
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Map<String, dynamic>>> getWeeklyLeaderboard({
    String criterion = 'cats',
    String period = 'weekly',
  }) => _list('/social/leaderboard/weekly?criterion=$criterion&period=$period');

  Future<void> registerDeviceToken(String token) async {
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
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
  Future<List<Map<String, dynamic>>> feed({
    int limit = 20,
    String? cursor,
    String? cursorId,
    String mode = 'all',
  }) {
    final params = <String>[
      'limit=$limit',
      'mode=$mode',
      if (cursor != null && cursor.isNotEmpty)
        'cursor=${Uri.encodeComponent(cursor)}',
    ];
    return _list('/social/feed?${params.join('&')}');
  }

  Future<List<Map<String, dynamic>>> conversations() =>
      _list('/social/conversations');

  Future<Map<String, dynamic>> conversationDetails(
    String conversationId,
  ) async {
    final response = await _request(
      'GET',
      '/social/conversations/$conversationId',
      null,
      accepted: {200},
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Map<String, dynamic>>> messages(String conversationId) =>
      _list('/social/conversations/$conversationId/messages');

  Future<Map<String, dynamic>> sendMessage(
    String conversationId, {
    String body = '',
    String type = 'text',
    String? mediaUrl,
    double? locationLat,
    double? locationLng,
    String? locationTitle,
    Map<String, dynamic>? catData,
    String? replyToId,
  }) async {
    final payload = <String, dynamic>{
      'body': body,
      'type': type,
      'media_url': ?mediaUrl,
      'location_lat': ?locationLat,
      'location_lng': ?locationLng,
      'location_title': ?locationTitle,
      'cat_data': ?catData,
      'reply_to_id': ?replyToId,
    };
    final response = await _request(
      'POST',
      '/social/conversations/$conversationId/messages',
      payload,
      accepted: {201},
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<String?> uploadChatPhoto(
    String conversationId,
    List<int> imageBytes,
    String filename,
  ) async {
    final token = await _sessionStore.accessToken();
    if (token == null) return null;
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/social/conversations/$conversationId/photo',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: filename),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map;
      return decoded['media_url'] as String?;
    }
    return null;
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _request(
        'POST',
        '/social/conversations/$conversationId/read',
        {},
        accepted: {200},
      );
    } catch (_) {
      // Ignora falhas de rede em leituras pontuais
    }
  }

  Future<Map<String, dynamic>> toggleMessageReaction(
    String conversationId,
    String messageId,
    String reaction,
  ) async {
    final response = await _request(
      'POST',
      '/social/conversations/$conversationId/messages/$messageId/reactions',
      {'reaction': reaction},
      accepted: {200},
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> editMessage(
    String conversationId,
    String messageId,
    String newBody,
  ) async {
    final response = await _request(
      'PUT',
      '/social/conversations/$conversationId/messages/$messageId',
      {'body': newBody},
      accepted: {200},
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _request(
      'DELETE',
      '/social/conversations/$conversationId/messages/$messageId',
      null,
      accepted: {200, 204},
    );
  }

  Future<Map<String, dynamic>> getUserPresence(String userId) async {
    final response = await _request(
      'GET',
      '/social/users/$userId/presence',
      null,
      accepted: {200},
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<String?> uploadPostPhoto(List<int> imageBytes, String filename) async {
    final token = await _sessionStore.accessToken();
    if (token == null) return null;
    final uri = Uri.parse('${ApiConfig.baseUrl}/social/posts/photo');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: filename),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map;
      return decoded['photo_url'] as String?;
    }
    return null;
  }

  Future<Map<String, dynamic>> createPost({
    required String catName,
    String? requestId,
    String note = '',
    String? locationName,
    String? photoBase64,
    String? photoUrl,
    bool isPublic = true,
  }) async {
    final response = await _request(
      'POST',
      '/social/posts',
      {
        'cat_name': catName,
        'request_id': ?requestId,
        'note': note,
        'location_name': ?locationName,
        'photo_base64': ?photoBase64,
        'photo_url': ?photoUrl,
        'is_public': isPublic,
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

  Future<List<Map<String, dynamic>>> addComment(
    String itemId,
    String text,
  ) async {
    final response = await _request(
      'POST',
      '/social/feed/$itemId/comments',
      {'text': text},
      accepted: {200},
    );
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> updateAccount({
    String? username,
    String? bio,
  }) async {
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
      ..files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: filename),
      );
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
  }) async {
    return AuthenticatedApiClient(_sessionStore).request(
      method,
      path,
      body,
      accepted: accepted,
      error: SocialApiException.new,
      signInMessage: 'Entre na sua conta para usar amigos.',
      connectionMessage: 'Não foi possível acessar amigos agora.',
    );
  }
}
