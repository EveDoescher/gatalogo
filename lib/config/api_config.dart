import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? '' : 'http://192.168.1.4:8000',
  );

  static const _explicitUrl = bool.hasEnvironment('API_BASE_URL');

  static void validate({
    bool release = kReleaseMode,
    String url = baseUrl,
    bool explicitlyConfigured = _explicitUrl,
  }) {
    if (release && !explicitlyConfigured) {
      throw StateError(
        'Builds de release exigem --dart-define=API_BASE_URL=<endereço da API>.',
      );
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError(
        'API_BASE_URL deve ser uma URL HTTP(S) absoluta sem credenciais, query ou fragmento.',
      );
    }
  }

  static String get wsUrl {
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(scheme: wsScheme, path: '/ws').toString();
  }
}
