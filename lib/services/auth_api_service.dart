import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/auth_session.dart';

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class AuthApiService {
  Future<void> resendVerification(String email) async {
    await _post('/auth/verify-email/resend', {'email': email}, accepted: {202});
  }

  Future<String> verifyResetCode(String email, String code) async {
    final response = await _post(
      '/auth/password-reset/verify',
      {'email': email, 'code': code},
      accepted: {200},
    );
    return _decode(response)['reset_token'] as String;
  }

  Future<void> completeReset(String token, String password) async {
    await _post(
      '/auth/password-reset/complete',
      {'reset_token': token, 'password': password},
      accepted: {204},
    );
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _post(
      '/auth/register',
      {'email': email, 'password': password},
      accepted: {202},
    );
  }

  Future<AuthSession> verifyEmail({
    required String email,
    required String code,
    required String deviceId,
  }) {
    return _tokens('/auth/verify-email', {
      'email': email,
      'code': code,
      'device_id': deviceId,
    });
  }

  Future<AuthSession> login({
    required String email,
    required String password,
    required String deviceId,
  }) {
    return _tokens('/auth/login', {
      'email': email,
      'password': password,
      'device_id': deviceId,
    });
  }

  Future<AuthSession> loginWithGoogle({
    required String idToken,
    required String deviceId,
  }) {
    return _tokens('/auth/google', {
      'id_token': idToken,
      'device_id': deviceId,
    });
  }

  Future<AuthSession> refresh({
    required String refreshToken,
    required String deviceId,
  }) {
    return _tokens('/auth/refresh', {
      'refresh_token': refreshToken,
      'device_id': deviceId,
    });
  }

  Future<void> requestPasswordReset(String email) async {
    await _post(
      '/auth/password-reset/request',
      {'email': email},
      accepted: {202},
    );
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String password,
  }) async {
    await _post(
      '/auth/password-reset/confirm',
      {'email': email, 'code': code, 'password': password},
      accepted: {204},
    );
  }

  Future<void> logout(String accessToken) async {
    await _post(
      '/auth/logout',
      const {},
      accessToken: accessToken,
      accepted: {204},
    );
  }

  Future<void> deactivate(String accessToken) async {
    await _post(
      '/auth/deactivate',
      const {},
      accessToken: accessToken,
      accepted: {204},
    );
  }

  Future<({String userId, String email})> me(String accessToken) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/auth/me'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) throw _exception(response);
      final body = _decode(response);
      return (userId: body['id'] as String, email: body['email'] as String);
    } on AuthApiException {
      rethrow;
    } catch (_) {
      throw const AuthApiException(
        'Não foi possível verificar sua sessão agora.',
      );
    }
  }

  Future<AuthSession> _tokens(String path, Map<String, dynamic> body) async {
    final response = await _post(path, body, accepted: {200});
    final decoded = _decode(response);
    return AuthSession(
      userId: decoded['user_id'] as String,
      email: decoded['email'] as String,
      accessToken: decoded['access_token'] as String,
      refreshToken: decoded['refresh_token'] as String,
    );
  }

  Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    required Set<int> accepted,
    String? accessToken,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {
              'Content-Type': 'application/json',
              if (accessToken != null) 'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
      if (!accepted.contains(response.statusCode)) throw _exception(response);
      return response;
    } on AuthApiException {
      rethrow;
    } catch (_) {
      throw const AuthApiException('Não foi possível acessar sua conta agora.');
    }
  }

  AuthApiException _exception(http.Response response) {
    try {
      final body = _decode(response);
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) {
        return AuthApiException(detail, statusCode: response.statusCode);
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) {
          final message = first['msg']?.toString();
          if (message != null && message.isNotEmpty) {
            return AuthApiException(_validationMessage(message));
          }
        }
      }
    } catch (_) {}
    return AuthApiException(
      'Não foi possível concluir esta operação.',
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _decode(http.Response response) =>
      Map<String, dynamic>.from(jsonDecode(response.body) as Map);

  String _validationMessage(String message) {
    if (message.contains('at least 12 characters')) {
      return 'A senha precisa ter pelo menos 12 caracteres.';
    }
    if (message.contains('valid email')) {
      return 'Informe um e-mail válido.';
    }
    if (message.contains('pattern')) {
      return 'Confira o código informado.';
    }
    return 'Há um campo inválido. Confira os dados e tente novamente.';
  }
}
