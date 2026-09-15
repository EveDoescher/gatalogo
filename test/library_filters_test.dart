import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/models/cat_analysis.dart';
import 'package:catlogue/models/cat_reference_photo.dart';
import 'package:catlogue/pages/library_page.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FilterTestStore extends CatStore {
  FilterTestStore(super.session);

  final sampleCats = [
    Cat(
      id: 'cat-comp',
      captureNumber: 1,
      photoPath: 'test1.jpg',
      capturedAt: DateTime(2026, 9, 1),
      name: 'Mingau',
      locationName: 'Rua das Flores, Centro, Limeira - SP',
      status: 'completed',
    ),
    Cat(
      id: 'cat-pend',
      captureNumber: 2,
      photoPath: 'test2.jpg',
      capturedAt: DateTime(2026, 9, 2),
      name: 'Soneca',
      locationName: 'Av. Paulista, Bela Vista, São Paulo - SP',
      status: 'pending_analysis',
    ),
    Cat(
      id: 'cat-fail',
      captureNumber: 3,
      photoPath: 'test3.jpg',
      capturedAt: DateTime(2026, 9, 3),
      name: 'Frajola',
      locationName: 'Rua do Porto, Centro, Limeira - SP',
      status: 'failed',
    ),
  ];

  final sampleAnalyses = <String, CatAnalysis>{
    'cat-comp': const CatAnalysis(
      catId: 'cat-comp',
      status: AnalysisStatus.completed,
      coatType: 'Sólido',
      primaryColor: 'Branco',
    ),
    'cat-pend': const CatAnalysis(
      catId: 'cat-pend',
      status: AnalysisStatus.pending,
    ),
    'cat-fail': const CatAnalysis(
      catId: 'cat-fail',
      status: AnalysisStatus.failed,
    ),
  };

  @override
  List<Cat> get cats => sampleCats;

  @override
  CatAnalysis? analysisFor(String catId) => sampleAnalyses[catId];

  @override
  Future<List<CatReferencePhoto>> loadReferencePhotos(String catId) async => const [];
}

void main() {
  testWidgets('LibraryPage exibe gatos e abre modal de filtros avançados', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = SessionStore();
    final store = FilterTestStore(session);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryPage(catStore: store),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mingau'), findsOneWidget);
    expect(find.text('Soneca'), findsOneWidget);
    expect(find.text('Frajola'), findsOneWidget);

    // Abre o modal de filtros avançados pelo botão da barra de pesquisa
    final filterButton = find.byTooltip('Filtros avançados');
    expect(filterButton, findsOneWidget);
    await tester.tap(filterButton);
    await tester.pumpAndSettle();

    // Encontra o título no modal e o chip na barra de filtros
    expect(find.text('Filtros avançados'), findsNWidgets(2));
    expect(find.text('Status da análise'), findsOneWidget);
    expect(find.text('Concluídas'), findsOneWidget);
    expect(find.text('Pendentes'), findsOneWidget);
    expect(find.text('Com falha'), findsOneWidget);

    // Seleciona o filtro 'Com falha'
    await tester.tap(find.text('Com falha'));
    await tester.pumpAndSettle();

    // Aplica o filtro
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();

    // Apenas Frajola (status: failed) deve estar visível
    expect(find.text('Frajola'), findsOneWidget);
    expect(find.text('Mingau'), findsNothing);
    expect(find.text('Soneca'), findsNothing);

    // Remove o filtro através do chip ativo
    final removeFilterIcon = find.byIcon(LucideIcons.x);
    expect(removeFilterIcon, findsOneWidget);
    await tester.tap(removeFilterIcon);
    await tester.pumpAndSettle();

    // Todos voltam a aparecer
    expect(find.text('Mingau'), findsOneWidget);
    expect(find.text('Soneca'), findsOneWidget);
    expect(find.text('Frajola'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    store.dispose();
    session.dispose();
  });
}
