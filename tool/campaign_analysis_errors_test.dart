// Production analysis/auth clients against the campaign's disposable loopback API.
import 'dart:convert';
import 'dart:io';

import 'package:catlogue/config/api_config.dart';
import 'package:catlogue/services/analysis_api_service.dart';
import 'package:catlogue/services/auth_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final options = jsonDecode(
    Platform.environment['QUALITY_ANALYSIS_ERRORS_CONFIG']!,
  ) as Map<String, dynamic>;
  final rows = <Map<String, Object?>>[];
  final variants = [
    'rejected',
    'unavailable-json',
    'unavailable-html',
    'refresh-success',
    'refresh-failed',
    'repeated-401',
    'signed-out',
  ];
  tearDownAll(() {
    File(options['result'] as String).writeAsStringSync(jsonEncode(rows));
  });
  for (final variant in variants) {
    test(
      'LAT03 $variant bounded attempts and preserved error contract',
      () async {
        for (var repetition = -1; repetition < 5; repetition++) {
          final prepared = await http.post(
            Uri.parse('${ApiConfig.baseUrl}/__quality__/analysis-case'),
            headers: {
              'X-Quality-Secret': options['secret'] as String,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'variant': variant, 'measured': repetition >= 0}),
          );
          expect(prepared.statusCode, 200);
          final config = jsonDecode(prepared.body) as Map<String, dynamic>;
          var refreshes = 0;
          String? token = variant == 'signed-out'
              ? null
              : config['access_token'] as String;
          final service = AnalysisApiService(
            accessToken: () async => token,
            refreshAccessToken: () async {
              refreshes++;
              try {
                final renewed = await AuthApiService().refresh(
                  refreshToken: variant == 'refresh-failed'
                      ? 'controlled-invalid-refresh'
                      : config['refresh_token'] as String,
                  deviceId: 'analysis-errors-fixture',
                );
                return token = renewed.accessToken;
              } on AuthApiException {
                return null;
              }
            },
          );
          final watch = Stopwatch()..start();
          var kind = 'success';
          String? message;
          String? code;
          bool? retryable;
          try {
            final result = await service.analyze(
              catId: config['client_id'] as String,
              imagePath: options['photo'] as String,
            );
            expect(variant, 'refresh-success');
            expect(result.catId, config['client_id']);
          } on AnalysisRejectedException catch (error) {
            kind = 'rejected';
            code = error.code;
            message = error.message;
            expect(variant, 'rejected');
            expect(code, 'NOT_A_CAT');
            expect(message, 'Nenhum gato foi identificado na imagem.');
          } on AnalysisApiException catch (error) {
            kind = 'api-error';
            retryable = error.retryable;
            message = error.message;
            if (variant.startsWith('unavailable')) {
              expect(retryable, isTrue);
              expect(
                message,
                'O serviço de análise está indisponível no momento.',
              );
            } else if (variant == 'signed-out') {
              expect(retryable, isFalse);
              expect(message, 'Entre em uma conta para enviar esta análise.');
            } else {
              expect(['refresh-failed', 'repeated-401'], contains(variant));
              expect(retryable, isTrue);
              expect(
                message,
                'Sua sessão expirou. Entre novamente para continuar.',
              );
            }
          }
          watch.stop();
          expect(
            kind,
            variant == 'refresh-success'
                ? 'success'
                : variant == 'rejected'
                ? 'rejected'
                : 'api-error',
          );
          expect(
            refreshes,
            variant.startsWith('refresh-') || variant == 'repeated-401' ? 1 : 0,
          );
          rows.add({
            'variant': variant,
            'measured': repetition >= 0,
            'elapsed_us': watch.elapsedMicroseconds,
            'result': kind,
            'message': message,
            'code': code,
            'retryable': retryable,
            'refreshes': refreshes,
          });
        }
      },
    );
  }
}
