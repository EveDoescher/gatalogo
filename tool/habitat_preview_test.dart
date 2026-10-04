import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:catlogue/app.dart';
import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/game/habitat_game.dart';
import 'package:catlogue/game/habitat_sprites.dart';
import 'package:catlogue/pages/habitat_page.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';

import '../test/screen_corrections_test.dart' show ScreenStore;

class _MemoryDatabase implements CatDatabase {
  @override
  Future<Map<String, dynamic>?> readHabitatCache(String ownerId) async => null;
  @override
  Future<void> saveHabitatSnapshot(
    String ownerId,
    Map<String, dynamic> snapshot,
  ) async {}
  @override
  Future<void> saveHabitatDraft(
    String ownerId,
    Map<String, dynamic>? draft,
  ) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('capture Habitat with bottom navigation', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(() async {
      final material = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
        ..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        );
      await Future.wait([material.load(), lucide.load()]);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);
    final session = SessionStore();
    final store = ScreenStore(session);
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: MainNavigation(sessionStore: session, catStore: store),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Habitat').last);
    await tester.pump(const Duration(milliseconds: 400));
    final gameFinder = find.byType(GameWidget<HabitatGame>);
    final game = tester.widget<GameWidget<HabitatGame>>(gameFinder).game!;
    final habitat = game.habitat;
    habitat.items = [
      const HabitatItem(id: 'bed', sku: 'cat_bed', x: 2, y: 6),
      const HabitatItem(id: 'tree', sku: 'small_tree', x: 1, y: 3),
      const HabitatItem(id: 'bush', sku: 'small_bush', x: 6, y: 3),
      const HabitatItem(id: 'flowers', sku: 'red_flowers', x: 5, y: 6),
      const HabitatItem(
        id: 'tent',
        sku: 'canvas_shelter',
        x: 3,
        y: 3,
        rotation: 2,
      ),
      const HabitatItem(id: 'spare-tree', sku: 'detailed_tree'),
      const HabitatItem(id: 'spare-bed', sku: 'floor_bed'),
      const HabitatItem(id: 'spare-house', sku: 'green_cottage'),
    ];
    habitat.balance = 150;
    habitat.cats = [
      const HabitatCat(id: 'luna', name: 'Luna'),
      const HabitatCat(id: 'nina', name: 'Nina'),
      const HabitatCat(id: 'milo', name: 'Milo'),
    ];
    habitat.selectedCatIds = ['luna'];
    habitat.catAnchors = {'luna': (6, 5)};
    final keys = [
      'animal-cat',
      'bed_NE',
      'tree_default_NE',
      'plant_bushSmall_NE',
      'flower_redA_NE',
      'tent_smallOpen_SW',
      'building-type-a',
      'tree_detailed_NE',
      'bed_floor_NE',
    ];
    for (final key in keys) {
      unawaited(game.sprites.ready(key));
    }
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (keys.every((key) => game.sprites.cached(key) != null)) break;
    }
    for (final key in keys) {
      expect(
        game.sprites.cached(key),
        isNotNull,
        reason: 'Missing preview asset: $key',
      );
    }

    Future<void> save(String state) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      for (final label in [
        'Início',
        'Social',
        'Gatalogar',
        'Coleção',
        'Habitat',
      ]) {
        expect(find.text(label), findsOneWidget);
        expect(tester.getRect(find.text(label)).bottom, lessThan(844));
      }
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('build/habitat_navigation_$state.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.tap(find.byTooltip('Abrir ações do Habitat'));
    await tester.pump();
    await save('menu');
    await tester.tap(find.text('Inventário'));
    await tester.pump();
    final bed = habitat.items.firstWhere((item) => item.id == 'bed');
    await tester.tapAt(
      tester.getTopLeft(gameFinder) + game.itemBounds(bed).center,
    );
    await tester.pump();
    expect(find.byTooltip('Girar objeto'), findsOneWidget);
    await save('editing');
    for (var rotation = 1; rotation < 4; rotation++) {
      habitat.items[0] = bed.at(2, 6, rotation);
      await tester.pump();
      await save('bed_rotation_$rotation');
    }
    habitat.items[0] = bed;
    await tester.tap(find.byTooltip('Fechar bandeja'));
    await tester.pump();
    await tester.tap(find.byTooltip('Abrir ações do Habitat'));
    await tester.pump();
    await tester.tap(find.text('Gatos'));
    await tester.pump();
    await save('cats');
    await tester.tap(find.byTooltip('Fechar bandeja'));
    await tester.pump();
    await tester.tap(find.byTooltip('Abrir ações do Habitat'));
    await tester.pump();
    await tester.tap(find.text('Loja'));
    await tester.pump();
    await save('shop');
    await tester.ensureVisible(find.text('Casinhas'));
    await tester.tap(find.text('Casinhas'));
    await tester.pump();
    await save('new_houses');
    await tester.ensureVisible(find.text('Terreno'));
    await tester.tap(find.text('Terreno'));
    await tester.pump();
    await save('terrain_shop');
    await tester.tap(find.byTooltip('Voltar ao Habitat'));
    await tester.pump();
    await tester.tap(find.byTooltip('Abrir ações do Habitat'));
    await tester.pump();
    await tester.tap(find.text('Concluir edição'));
    await tester.pump();
    habitat.items = [
      const HabitatItem(id: 'solar', sku: 'solar_cottage', x: 1, y: 0),
      const HabitatItem(id: 'planter', sku: 'garden_planter', x: 5, y: 1),
      const HabitatItem(id: 'autumn', sku: 'autumn_tree', x: 6, y: 2),
      const HabitatItem(id: 'bowl', sku: 'food_bowl', x: 5, y: 7),
      const HabitatItem(id: 'crate', sku: 'play_crate', x: 2, y: 6),
      HabitatItem(
        id: 'leaves',
        sku: 'leaf_garden',
        x: 1,
        y: 5,
        careState: {
          'grow_at': DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        },
      ),
      for (var x = 4; x <= 5; x++)
        for (var y = 3; y <= 6; y++)
          HabitatItem(id: 'water-$x-$y', sku: 'water_tile', x: x, y: y),
      const HabitatItem(id: 'bridge', sku: 'wood_bridge', x: 4, y: 4),
      const HabitatItem(id: 'lily', sku: 'water_lily', x: 4, y: 6),
      const HabitatItem(id: 'spare-palm', sku: 'palm_tree'),
    ];
    habitat.selectedCatIds = ['luna', 'nina'];
    habitat.catAnchors = {'luna': (1, 4), 'nina': (6, 6)};
    expect(habitat.layoutProblem(habitat.items), isNull);
    await tester.runAsync(
      () => game.sprites.preloadReady([
        for (final item in habitat.items)
          game.sprites.keyFor(habitat.spriteFor(item), item.rotation),
      ]),
    );
    game.reducedMotion = true;
    game.update(0);
    game.resumeEngine();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    game.pauseEngine();
    await tester.pump();
    await save('living_yard');
    final catPoint = game.groundAnchor(1, 4) - Offset(0, game.tileWidth * 0.3);
    expect(game.catAtScreen(catPoint), 'luna');
    await tester.tapAt(tester.getTopLeft(gameFinder) + catPoint);
    await tester.pump();
    await save('care');
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    session.dispose();
  });

  testWidgets('capture Habitat reference states', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(() async {
      final material = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
        ..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        );
      await Future.wait([material.load(), lucide.load()]);
    });
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = SessionStore();
    final store = CatStore(session);
    final habitat = HabitatService(session, store, database: _MemoryDatabase());
    final active = ValueNotifier(true);
    final key = GlobalKey();
    final sprites = HabitatSprites();
    await tester.runAsync(() async {
      final game = HabitatGame(habitat, sprites);
      await game.onLoad();
      await sprites.preloadReady([
        for (final direction in ['NE', 'SE', 'SW', 'NW']) ...[
          'bed_$direction',
          'tent_smallOpen_$direction',
        ],
        'tree_default_NE',
        'plant_bushSmall_NE',
        'flower_redA_NE',
        'building-type-a',
        'building-type-f',
      ]);
      game.onRemove();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: RepaintBoundary(
          key: key,
          child: HabitatPage(
            sessionStore: session,
            catStore: store,
            active: active,
            habitatService: habitat,
            sprites: sprites,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    habitat.items.add(
      const HabitatItem(id: 'audit-tent', sku: 'canvas_shelter'),
    );
    await habitat.place('guest-cat_bed', 2, 6, 0);
    await habitat.place('guest-small_tree', 1, 3, 0);
    await habitat.place('guest-small_bush', 6, 3, 0);
    await habitat.place('guest-red_flowers', 5, 6, 0);
    habitat.items.addAll([
      const HabitatItem(id: 'spare-tree', sku: 'small_tree'),
      const HabitatItem(id: 'spare-bed', sku: 'cat_bed'),
      const HabitatItem(id: 'spare-house', sku: 'green_cottage'),
    ]);
    habitat.cats = [const HabitatCat(id: 'audit-cat', name: 'Luna')];
    habitat.selectedCatIds = ['audit-cat'];
    habitat.catAnchors = {'audit-cat': (6, 5)};
    await habitat.place('audit-tent', 3, 3, 2);

    Future<void> save(String name) async {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 700)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('build/habitat_audit_$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await save('main');
    await tester.tap(find.byTooltip('Abrir ações do Habitat'));
    await tester.pump();
    await save('menu');
    await tester.tap(find.text('Inventário'));
    await tester.pump();
    await save('inventory');
    await tester.tap(find.byTooltip('Fechar bandeja'));
    await tester.pump();
    await tester.tap(find.byTooltip('Abrir ações do Habitat'));
    await tester.pump();
    await tester.tap(find.text('Gatos'));
    await tester.pump();
    await save('cats');
    await tester.tap(find.byTooltip('Fechar bandeja'));
    await tester.pump();
    await tester.tap(find.byTooltip('Abrir ações do Habitat'));
    await tester.pump();
    await tester.tap(find.text('Loja'));
    await tester.pump();
    await save('shop');
    await tester.tap(find.byTooltip('Voltar ao Habitat'));
    await tester.pump();
    await tester.tap(find.text('Modo edição'));
    await tester.pump();
    habitat.items = [
      const HabitatItem(id: 'house', sku: 'green_cottage', x: 2, y: 2),
      const HabitatItem(id: 'tree', sku: 'small_tree', x: 0, y: 5),
      const HabitatItem(id: 'bed', sku: 'cat_bed', x: 2, y: 6),
      const HabitatItem(
        id: 'tent',
        sku: 'canvas_shelter',
        x: 5,
        y: 5,
        rotation: 2,
      ),
      for (var x = 2; x <= 5; x++)
        HabitatItem(id: 'path-$x', sku: 'pebble_path', x: x, y: 5),
    ];
    habitat.catAnchors = {'audit-cat': (6, 3)};
    await habitat.place('house', 2, 2, 0);
    await save('house');
    final game = tester
        .widget<GameWidget<HabitatGame>>(find.byType(GameWidget<HabitatGame>))
        .game!;
    game.scaleCamera(1.9, const Offset(195, 360));
    await save('zoom');
    game.scaleCamera(1, const Offset(195, 360));
    for (var rotation = 0; rotation < 4; rotation++) {
      await habitat.place('bed', 2, 6, rotation);
      await habitat.place('tent', 5, 5, rotation);
      expect(sprites.cached(sprites.keyFor('bed', rotation)), isNotNull);
      expect(
        sprites.cached(sprites.keyFor('tent_smallOpen', rotation)),
        isNotNull,
      );
      await save('rotation_$rotation');
    }
    habitat.items[0] = const HabitatItem(
      id: 'house',
      sku: 'large_cottage',
      x: 2,
      y: 2,
    );
    await habitat.place('house', 2, 2, 0);
    await save('large_house');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    active.dispose();
    habitat.dispose();
    store.dispose();
    session.dispose();
  });
}
