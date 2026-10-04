import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/pages/habitat_page.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _HabitatDatabase implements CatDatabase {
  @override
  Future<Map<String, dynamic>?> readHabitatCache(String ownerId) async => null;

  @override
  Future<void> saveHabitatSnapshot(
    String ownerId,
    Map<String, dynamic> value,
  ) async {}

  @override
  Future<void> saveHabitatDraft(
    String ownerId,
    Map<String, dynamic>? value,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Habitat uses a full scene, floating menu, trays and full shop', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = SessionStore();
    final store = CatStore(session);
    final habitat = HabitatService(
      session,
      store,
      database: _HabitatDatabase(),
    );
    final active = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      MaterialApp(
        home: HabitatPage(
          sessionStore: session,
          catStore: store,
          active: active,
          habitatService: habitat,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Um cantinho para descansar'), findsNothing);
    expect(find.text('Inventário'), findsNothing);
    expect(find.byTooltip('Aproximar'), findsNothing);

    await tester.tap(find.byTooltip('Abrir ações do Habitat'));
    await tester.pump();
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Inventário'), findsOneWidget);
    expect(find.text('Loja'), findsOneWidget);
    expect(find.text('Gatos'), findsOneWidget);

    await tester.tap(find.text('Inventário'));
    await tester.pump();
    expect(find.text('Modo edição'), findsOneWidget);
    expect(find.text('Inventário'), findsOneWidget);

    habitat.items = [
      const HabitatItem(id: 'bed', sku: 'cat_bed'),
      for (var index = 0; index < 5; index++)
        HabitatItem(id: 'path-$index', sku: 'pebble_path'),
    ];
    await habitat.place('bed', 1, 1, 0);
    await tester.pump();
    expect(find.text('Caminha'), findsNothing);
    expect(find.text('Caminho de pedrinhas'), findsOneWidget);
    expect(find.text('5 disponíveis'), findsOneWidget);
    await habitat.paintGround('pebble_path', [(1, 1)]);
    await tester.pump();
    expect(find.text('Caminho de pedrinhas'), findsOneWidget);
    expect(find.text('4 disponíveis'), findsOneWidget);
    await habitat.paintGround('pebble_path', [(1, 2), (1, 3), (1, 4), (1, 5)]);
    await tester.pump();
    expect(find.text('Caminho de pedrinhas'), findsNothing);
    await habitat.storeItem('path-0');
    await habitat.storeItem('bed');
    await tester.pump();
    expect(find.text('Caminho de pedrinhas'), findsOneWidget);
    expect(find.text('Caminha'), findsOneWidget);
    expect(find.text('1 disponível'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Fechar bandeja'));
    await tester.pump();
    await tester.tap(find.byTooltip('Abrir ações do Habitat'));
    await tester.pump();
    await tester.tap(find.text('Gatos'));
    await tester.pump();
    expect(find.text('0/3 no habitat'), findsOneWidget);
    expect(
      find.text('Cadastre um gato em Meus Gatos para vê-lo aqui.'),
      findsOneWidget,
    );
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.byTooltip('Fechar bandeja'));
    await tester.pump();
    await tester.tap(find.byTooltip('Abrir ações do Habitat'));
    await tester.pump();
    await tester.tap(find.text('Loja'));
    await tester.pump();
    expect(find.text('Loja do Habitat'), findsOneWidget);
    expect(find.text('Expandir terreno'), findsOneWidget);
    await tester.ensureVisible(find.text('Natureza'));
    await tester.tap(find.text('Natureza'));
    await tester.pump();
    expect(find.text('Árvore pequena'), findsOneWidget);
    expect(find.text('Caminha'), findsNothing);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(-600, 0),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Terreno'));
    await tester.tap(find.text('Terreno'));
    await tester.pump();
    expect(find.text('Lago'), findsOneWidget);
    expect(find.text('Terra'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar ao Habitat'));
    await tester.pump();
    expect(find.text('Loja do Habitat'), findsNothing);
    expect(find.byTooltip('Abrir ações do Habitat'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    active.dispose();
    habitat.dispose();
    store.dispose();
    session.dispose();
  });
}
