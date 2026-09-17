import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/models/cat_analysis.dart';
import 'package:catlogue/models/cat_reference_photo.dart';
import 'package:catlogue/pages/cat_details_page.dart';
import 'package:catlogue/pages/cat_gallery_page.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/session_store.dart';

class _FakeCatStore extends CatStore {
  _FakeCatStore(super.session, this.cat, this.analysis, this.referencePhotos);

  final Cat cat;
  final CatAnalysis? analysis;
  final List<CatReferencePhoto> referencePhotos;

  @override
  List<Cat> get cats => [cat];

  @override
  CatAnalysis? analysisFor(String catId) => catId == cat.id ? analysis : null;

  @override
  List<CatReferencePhoto> referencePhotosFor(String catId) =>
      catId == cat.id ? referencePhotos : const [];

  @override
  Future<List<CatReferencePhoto>> loadReferencePhotos(String catId) async =>
      catId == cat.id ? referencePhotos : const [];
}

void main() {
  testWidgets('CatDetailsPage renderiza analise, confianca real, cores formatadas e fotos', (tester) async {
    final cat = Cat(
      id: 'cat-test-1',
      captureNumber: 42,
      photoPath: 'test_cat.jpg',
      capturedAt: DateTime(2026, 9, 10, 14, 30),
      name: 'Mingau',
      status: 'completed',
      locationName: 'Jardim Paulista, São Paulo',
    );

    final analysis = CatAnalysis(
      catId: 'cat-test-1',
      status: AnalysisStatus.completed,
      coatType: 'Rajado',
      hairType: 'Curto',
      primaryColor: 'Laranja',
      confidence: 0.88,
      colors: const [
        CoatColor(name: 'Laranja', percentage: 0.60),
        CoatColor(name: 'Branco', percentage: 40.0),
      ],
    );

    final referencePhoto = CatReferencePhoto(
      catId: 'cat-test-1',
      kind: 'front',
      localPath: 'front_angle.jpg',
      status: 'ready',
      updatedAt: DateTime(2026, 9, 10),
    );

    final session = SessionStore();
    final store = _FakeCatStore(session, cat, analysis, [referencePhoto]);

    await tester.pumpWidget(
      MaterialApp(
        home: CatDetailsPage(cat: cat, catStore: store),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Informações básicas
    expect(find.text('Mingau'), findsOneWidget);
    expect(find.text('Gato #042'), findsOneWidget);

    // 2. Análise da pelagem: tipo de pelagem não deve ser a cor ('Laranja'), deve ser 'Curto'
    expect(find.text('Curto'), findsOneWidget);
    expect(find.text('Rajado'), findsOneWidget);

    // 3. Porcentagens de cor formatadas corretamente (60% e 40%)
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);

    // 4. Confiança calculada da análise (0.88 -> 88%)
    expect(find.text('Confiança: 88%'), findsOneWidget);

    // 5. Toque na confiança abre o modal explicativo
    await tester.tap(find.text('Confiança: 88%'));
    await tester.pumpAndSettle();
    expect(find.text('Confiança da IA (88%)'), findsOneWidget);
    expect(find.text('Critérios avaliados:'), findsOneWidget);
    expect(find.text('Entendi'), findsOneWidget);

    // Fecha o modal
    await tester.ensureVisible(find.text('Entendi'));
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.text('Confiança da IA (88%)'), findsNothing);

    // 6. Seção de fotos adicionais conta a foto de referência existente
    await tester.ensureVisible(find.text('1 Foto'));
    expect(find.text('1 Foto'), findsOneWidget);

    // 7. Clicar em "Adicionar fotos" navega para CatGalleryPage
    await tester.ensureVisible(find.text('Adicionar\nfotos'));
    await tester.tap(find.text('Adicionar\nfotos'));
    await tester.pumpAndSettle();
    expect(find.byType(CatGalleryPage), findsOneWidget);

    store.dispose();
    session.dispose();
  });

  testWidgets('CatDetailsPage exibe 0 Fotos e orientacao quando nao ha fotos adicionais', (tester) async {
    final cat = Cat(
      id: 'cat-test-2',
      captureNumber: 7,
      photoPath: 'main_cat.jpg',
      capturedAt: DateTime(2026, 9, 11),
      name: 'Tom',
      status: 'completed',
      locationName: 'Avenida dos Felinos, 789, Bairro Primavera, Gatolândia, São Paulo',
    );

    final session = SessionStore();
    final store = _FakeCatStore(session, cat, null, const []);

    await tester.pumpWidget(
      MaterialApp(
        home: CatDetailsPage(cat: cat, catStore: store),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Sanitizacao do endereco: remove numero residual '789'
    expect(find.textContaining('789'), findsNothing);
    expect(find.textContaining('Avenida dos Felinos'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Gatolândia'), findsAtLeastNWidgets(1));

    // 2. Contador de fotos adicionais deve ser 0 Fotos
    await tester.ensureVisible(find.text('0 Fotos'));
    expect(find.text('0 Fotos'), findsOneWidget);

    // 3. Orientacao para fotos adicionais deve estar presente
    expect(find.textContaining('Adicione fotos de diferentes'), findsOneWidget);

    store.dispose();
    session.dispose();
  });
}
