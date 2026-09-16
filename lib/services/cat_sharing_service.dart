import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../models/cat.dart';
import '../models/cat_analysis.dart';

class CatSharingService {
  const CatSharingService._();

  static String buildShareText({
    required Cat cat,
    CatAnalysis? analysis,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Gatálogo — Descoberta Felina');
    buffer.writeln('${cat.displayName} (Gato #${cat.captureNumber.toString().padLeft(3, '0')})');

    if (analysis != null) {
      buffer.writeln('Padrão: ${analysis.coatType}');
      buffer.writeln('Pelagem: ${analysis.primaryColor}');
      if (analysis.confidence != null) {
        final conf = (analysis.confidence! * 100).round();
        buffer.writeln('Confiança da IA: $conf%');
      }
    }

    if (cat.locationName != null && cat.locationName!.trim().isNotEmpty) {
      buffer.writeln('Local: ${cat.locationName!.trim()}');
    }

    buffer.writeln('Identificado e protegido no Gatálogo.');
    return buffer.toString().trim();
  }

  static Future<bool> shareCat({
    required Cat cat,
    CatAnalysis? analysis,
  }) async {
    final text = buildShareText(cat: cat, analysis: analysis);
    try {
      final file = File(cat.photoPath);
      if (await file.exists()) {
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: text,
            subject: 'Gato ${cat.displayName} no Gatálogo',
          ),
        );
        return result.status == ShareResultStatus.success ||
            result.status == ShareResultStatus.dismissed;
      } else {
        final result = await SharePlus.instance.share(
          ShareParams(
            text: text,
            subject: 'Gato ${cat.displayName} no Gatálogo',
          ),
        );
        return result.status == ShareResultStatus.success ||
            result.status == ShareResultStatus.dismissed;
      }
    } catch (e) {
      debugPrint('Erro ao compartilhar gato: $e');
      return false;
    }
  }

  static String buildMissingPosterText({
    required Cat cat,
    required Map<String, dynamic> report,
    String? locationName,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('ALERTA DE DESAPARECIMENTO — GATÁLOGO');
    buffer.writeln('PROCURA-SE: ${cat.displayName}');
    if (locationName != null && locationName.trim().isNotEmpty) {
      buffer.writeln('Último local visto: $locationName');
    }
    if (cat.collar != null && cat.collar!.trim().isNotEmpty) {
      buffer.writeln('Coleira: ${cat.collar!.trim()}');
    }
    if (cat.distinguishingMarks != null &&
        cat.distinguishingMarks!.trim().isNotEmpty) {
      buffer.writeln('Marcas características: ${cat.distinguishingMarks!.trim()}');
    }
    if (cat.microchip != null && cat.microchip!.trim().isNotEmpty) {
      buffer.writeln('Microchip: ${cat.microchip!.trim()}');
    }
    buffer.writeln('');
    buffer.writeln(
      'Se você viu este gato na região, fotografe pelo aplicativo Gatálogo para alertar o tutor imediatamente.',
    );
    return buffer.toString().trim();
  }

  static Future<bool> shareMissingPoster({
    required Cat cat,
    required Map<String, dynamic> report,
    String? locationName,
  }) async {
    final text = buildMissingPosterText(
      cat: cat,
      report: report,
      locationName: locationName,
    );
    try {
      final file = File(cat.photoPath);
      if (await file.exists()) {
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: text,
            subject: 'PROCURA-SE: ${cat.displayName}',
          ),
        );
        return result.status == ShareResultStatus.success ||
            result.status == ShareResultStatus.dismissed;
      } else {
        final result = await SharePlus.instance.share(
          ShareParams(
            text: text,
            subject: 'PROCURA-SE: ${cat.displayName}',
          ),
        );
        return result.status == ShareResultStatus.success ||
            result.status == ShareResultStatus.dismissed;
      }
    } catch (e) {
      debugPrint('Erro ao compartilhar cartaz: $e');
      return false;
    }
  }
}
