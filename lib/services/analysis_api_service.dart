import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/cat_analysis.dart';

class AnalysisRejectedException implements Exception {
  final String code;
  final String message;

  const AnalysisRejectedException({required this.code, required this.message});

  @override
  String toString() => message;
}

class AnalysisApiException implements Exception {
  const AnalysisApiException(this.message, {this.retryable = false});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

class AnalysisConnectionException implements Exception {
  const AnalysisConnectionException();

  @override
  String toString() {
    return 'Não foi possível conectar ao serviço de análise.';
  }
}

class AnalysisApiService {
  AnalysisApiService({this.accessToken, this.refreshAccessToken});

  final Future<String?> Function()? accessToken;
  final Future<String?> Function()? refreshAccessToken;

  Future<CatAnalysis> analyze({
    required String catId,
    required String imagePath,
  }) async {
    try {
      final token = await accessToken?.call();
      if (token == null) {
        throw const AnalysisApiException(
          'Entre em uma conta para enviar esta análise.',
        );
      }
      var response = await _send(
        catId: catId,
        imagePath: imagePath,
        token: token,
      );
      if (response.statusCode == 401) {
        final refreshedToken = await refreshAccessToken?.call();
        if (refreshedToken != null) {
          response = await _send(
            catId: catId,
            imagePath: imagePath,
            token: refreshedToken,
          );
        }
      }

      final Map<String, dynamic> body = response.body.isEmpty
          ? {}
          : Map<String, dynamic>.from(jsonDecode(response.body) as Map);

      if (response.statusCode == 200) {
        return CatAnalysis.fromApiJson(body);
      }

      if (response.statusCode == 400 || response.statusCode == 422) {
        final detail = body['detail'];

        if (detail is Map) {
          final detailMap = Map<String, dynamic>.from(detail);

          throw AnalysisRejectedException(
            code: detailMap['code']?.toString() ?? 'INVALID_IMAGE',
            message:
                detailMap['message']?.toString() ??
                'A imagem não pôde ser utilizada.',
          );
        }
      }

      if (response.statusCode == 503) {
        throw const AnalysisApiException(
          'O serviço de análise está indisponível no momento.',
          retryable: true,
        );
      }

      if (response.statusCode == 401) {
        throw const AnalysisApiException(
          'Sua sessão expirou. Entre novamente para continuar.',
          retryable: true,
        );
      }

      if (response.statusCode >= 500) {
        throw AnalysisApiException(
          'O serviço de análise está temporariamente indisponível '
          '(HTTP ${response.statusCode}).',
          retryable: true,
        );
      }

      throw AnalysisApiException(
        'Erro no serviço de análise '
        '(HTTP ${response.statusCode}).',
      );
    } on AnalysisRejectedException {
      rethrow;
    } on AnalysisApiException {
      rethrow;
    } on SocketException {
      throw const AnalysisConnectionException();
    } on FormatException {
      throw const AnalysisApiException(
        'O servidor retornou uma resposta inválida.',
      );
    } on http.ClientException {
      throw const AnalysisConnectionException();
    }
  }

  Future<http.Response> _send({
    required String catId,
    required String imagePath,
    required String token,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/analyze'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['cat_id'] = catId;
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    return http.Response.fromStream(await request.send());
  }
}
