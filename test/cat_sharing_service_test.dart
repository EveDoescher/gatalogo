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

  test('buildPostShareText formata texto completo de post do feed', () {
    final text = CatSharingService.buildPostShareText(
      catName: 'Mingau',
      author: 'alice',
      location: 'Parque Ecológico, Campinas',
      note: 'Gato super dócil perto do lago',
    );

    expect(text.contains('Mingau no Gatálogo'), isTrue);
    expect(text.contains('Descoberta registrada por @alice'), isTrue);
    expect(text.contains('Local: Parque Ecológico, Campinas'), isTrue);
    expect(text.contains('Nota: Gato super dócil perto do lago'), isTrue);
    expect(text.contains('rede de catalogação e resgate felino'), isTrue);
  });

  test('buildPostShareText formata texto sem local e nota opcionais', () {
    final text = CatSharingService.buildPostShareText(
      catName: 'Garfield',
      author: 'bob',
    );

    expect(text.contains('Garfield no Gatálogo'), isTrue);
    expect(text.contains('Descoberta registrada por @bob'), isTrue);
    expect(text.contains('Local:'), isFalse);
    expect(text.contains('Nota:'), isFalse);
  });

  test('buildAchievementShareText formata texto de conquista desbloqueada', () {
    final text = CatSharingService.buildAchievementShareText(
      title: 'Primeiro Resgate',
      description: 'Ajudou a resgatar um felino perdido',
      rarity: 'Raro',
    );

    expect(text.contains('Conquista Desbloqueada no Gatálogo!'), isTrue);
    expect(text.contains('Marco: Primeiro Resgate'), isTrue);
    expect(text.contains('Raridade: Raro'), isTrue);
    expect(text.contains('Detalhes: Ajudou a resgatar um felino perdido'), isTrue);
  });

  test('buildMissingPosterText formata cartaz de alerta', () {
    final cat = Cat(
      id: 'cat-alert',
      captureNumber: 15,
      photoPath: 'photo.jpg',
      capturedAt: DateTime(2026, 9, 15),
      name: 'Tom',
      collar: 'Vermelha com sino',
      distinguishingMarks: 'Patinha dianteira branca',
      microchip: 'BR-987654321',
      status: 'completed',
    );

    final text = CatSharingService.buildMissingPosterText(
      cat: cat,
      report: {'reward': 'Sim'},
      locationName: 'Jardim Primavera',
    );

    expect(text.contains('ALERTA DE DESAPARECIMENTO'), isTrue);
    expect(text.contains('PROCURA-SE: Tom'), isTrue);
    expect(text.contains('Último local visto: Jardim Primavera'), isTrue);
    expect(text.contains('Coleira: Vermelha com sino'), isTrue);
    expect(text.contains('Marcas características: Patinha dianteira branca'), isTrue);
    expect(text.contains('Microchip: BR-987654321'), isTrue);
  });
}
