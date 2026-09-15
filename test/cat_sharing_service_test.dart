import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/models/cat_analysis.dart';
import 'package:catlogue/services/cat_sharing_service.dart';

void main() {
  test('buildShareText formata texto com dados reais do gato e analise de IA', () {
    final cat = Cat(
      id: 'cat-123',
      captureNumber: 42,
      photoPath: 'photo.jpg',
      capturedAt: DateTime(2026, 9, 15),
      name: 'Frajola',
      locationName: 'Centro, Limeira - SP',
      status: 'completed',
    );

    const analysis = CatAnalysis(
      catId: 'cat-123',
      status: AnalysisStatus.completed,
      coatType: 'Bicolor',
      primaryColor: 'Preto e Branco',
      confidence: 0.96,
    );

    final text = CatSharingService.buildShareText(cat: cat, analysis: analysis);

    expect(text.contains('Gatálogo — Descoberta Felina'), isTrue);
    expect(text.contains('Frajola (Gato #042)'), isTrue);
    expect(text.contains('Padrão: Bicolor'), isTrue);
    expect(text.contains('Pelagem: Preto e Branco'), isTrue);
    expect(text.contains('Confiança da IA: 96%'), isTrue);
    expect(text.contains('Local: Centro, Limeira - SP'), isTrue);
    expect(text.contains('Identificado e protegido no Gatálogo.'), isTrue);
  });

  test('buildShareText trata gato sem analise e sem localizacao', () {
    final cat = Cat(
      id: 'cat-999',
      captureNumber: 7,
      photoPath: 'photo.jpg',
      capturedAt: DateTime(2026, 9, 15),
      name: null,
      locationName: null,
      status: 'pending_analysis',
    );

    final text = CatSharingService.buildShareText(cat: cat, analysis: null);

    expect(text.contains('Gato #007 (Gato #007)'), isTrue);
    expect(text.contains('Local:'), isFalse);
    expect(text.contains('Padrão:'), isFalse);
    expect(text.contains('Identificado e protegido no Gatálogo.'), isTrue);
  });
}
