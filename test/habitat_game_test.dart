import 'dart:convert';

import 'package:catlogue/game/habitat_game.dart';
import 'package:catlogue/game/habitat_world.dart';
import 'package:catlogue/game/habitat_path_style.dart';
import 'package:catlogue/game/habitat_sprites.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('zoom preserves the same world location even at each pan limit', () {
    final session = SessionStore();
    final habitat = HabitatService(session, CatStore(session));
    final game = HabitatGame(habitat, HabitatSprites());
    for (final size in [Vector2(390, 844), Vector2(320, 568)]) {
      game.onGameResize(size);
      final center = Offset(size.x / 2, size.y / 2);
      for (final production in [false, true]) {
        habitat.production = production ? {'facilities': []} : {};
        for (final direction in [
          const Offset(1, 1),
          const Offset(-1, 1),
          const Offset(1, -1),
          const Offset(-1, -1),
        ]) {
          game.zoom = 1;
          game.pan = Offset.zero;
          game.moveCamera(direction * 100000);
          final landmark = game.groundAnchor(0, 0);
          game.scaleCamera(1.9, center);
          expect(
            (game.groundAnchor(0, 0) - (center + (landmark - center) * 1.9))
                .distance,
            lessThan(.001),
            reason: 'Zoom must not clamp back toward the yard before reaching the same world edge.',
          );
          final before = game.pan;
          game.moveCamera(direction * 20);
          expect(
            (game.pan - before).distance,
            greaterThan(20),
            reason: 'The smaller visible world area leaves room to pan after zooming.',
          );
        }
      }
    }
    game.onRemove();
    habitat.dispose();
    session.dispose();
  });

  testWidgets(
    'solid models stay centered and fit their cells in every orientation',
    (tester) async {
      final session = SessionStore();
      final habitat = HabitatService(session, CatStore(session));
      final sprites = HabitatSprites();
      final game = HabitatGame(habitat, sprites);
      await tester.runAsync(game.onLoad);
      final profiles = jsonDecode(
        (await tester.runAsync(
          () => rootBundle.loadString(
            'assets/3d_assets/kenney_nature-kit/Isometric/habitat_lighting.json',
          ),
        ))!,
      ) as Map;
      profiles.addAll(
        jsonDecode(
          (await tester.runAsync(
            () => rootBundle.loadString('assets/habitat/decor/profiles.json'),
          ))!,
        ) as Map,
      );
      final productionProfiles = jsonDecode(
        (await tester.runAsync(
          () => rootBundle.loadString('assets/quintal/production/manifest.json'),
        ))!,
      ) as Map;
      profiles.addAll(<String, dynamic>{
        for (final entry in productionProfiles.entries)
          'production:${entry.key}': entry.value,
      });
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.pump(const Duration(milliseconds: 300));
      for (var level = 0; level <= 3; level++) {
        habitat.buildableCells = HabitatService.yardCells(level);
        expect(
          (game.giftBounds.bottomCenter - game.giftPosition).distance,
          lessThan(.001),
          reason:
              'the visible gift must be anchored at the external delivery cell',
        );
        expect(
          game.cellAt(game.giftBounds.bottomCenter),
          isNull,
          reason:
              'the visible chest must remain outside editable land at expansion $level',
        );
      }
      for (final zoom in [.65, 1.0, 1.9]) {
        game.scaleCamera(zoom, Offset(game.size.x / 2, game.size.y / 2));
        for (final direction in [
          const Offset(-1, -1),
          const Offset(1, -1),
          const Offset(-1, 1),
          const Offset(1, 1),
        ]) {
          game.moveCamera(
            Offset(
              direction.dx * game.size.x * 10,
              direction.dy * game.size.y * 10,
            ),
          );
          final region = game.sceneryRegion;
          final world = HabitatWorld(habitat.buildableCells);
          expect(
            world
                .decorationsWithin(
                  region.left.toInt(),
                  region.top.toInt(),
                  region.right.toInt(),
                  region.bottom.toInt(),
                )
                .length,
            greaterThan(20),
          );
        }
      }
      game.pan = Offset.zero;
      game.zoom = 1;
      for (final key in HabitatWorld.scenerySprites) {
        expect(sprites.cached(key), isNotNull, reason: key);
      }
      habitat.buildableCells = HabitatService.yardCells(0);
      for (final type in habitat.shop.where(
        (item) => !item.isGround && item.sku != 'low_fence',
      )) {
        for (
          var rotation = 0;
          rotation < (type.rotatable ? 4 : 1);
          rotation++
        ) {
          final item = HabitatItem(
            id: type.sku,
            sku: type.sku,
            x: 2,
            y: 2,
            rotation: rotation,
          );
          final width = rotation.isOdd ? type.height : type.width;
          final height = rotation.isOdd ? type.width : type.height;
          var center = Offset.zero;
          for (var x = 2; x < 2 + width; x++) {
            for (var y = 2; y < 2 + height; y++) {
              center += game.groundAnchor(x, y);
            }
          }
          center /= (width * height).toDouble();
          final key = sprites.keyFor(habitat.spriteFor(item), rotation);
          final source = sprites.bounds(key);
          final destination = game.itemBounds(item);
          final scale = destination.width / source.width;
          final projectedCenter =
              destination.topLeft +
              (sprites.groundOrigin(key) +
                      sprites.groundCenter(key) -
                      source.topLeft) *
                  scale;
          expect(
            (projectedCenter - center).distance,
            lessThan(0.001),
            reason: '$key must be centered in its occupied cells',
          );
          if (!type.sprite.startsWith('tree_') &&
              !type.sprite.startsWith('plant_') &&
              !type.sprite.startsWith('flower_')) {
            final size = profiles[key]['groundSize'] as List;
            expect(
              (size[0] as num) * scale,
              lessThanOrEqualTo(width * game.tileWidth / 2),
              reason: '$key exceeds footprint width',
            );
            expect(
              (size[1] as num) * scale,
              lessThanOrEqualTo(height * game.tileWidth / 2),
              reason: '$key exceeds footprint depth',
            );
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
      habitat.dispose();
      session.dispose();
    },
  );

  test('path pieces join at ends, corners and intersections', () {
    expect(pathSprite('path_stone', [true, false, false, false]), (
      'path_stoneEnd',
      0,
    ));
    expect(pathSprite('path_stone', [true, false, true, false]), (
      'path_stoneCorner',
      0,
    ));
    expect(pathSprite('path_stone', [false, true, true, false]), (
      'path_stoneCorner',
      1,
    ));
    expect(pathSprite('path_wood', [false, true, false, true]), (
      'path_woodCorner',
      2,
    ));
    expect(pathSprite('path_wood', [true, false, false, true]), (
      'path_woodCorner',
      3,
    ));
    expect(pathSprite('path_stone', [true, true, true, true]), (
      'path_stoneCircle',
      0,
    ));
  });

  testWidgets('camera hit testing follows pan and pinch zoom', (tester) async {
    final session = SessionStore();
    final habitat = HabitatService(session, CatStore(session));
    final game = HabitatGame(habitat, HabitatSprites());
    await tester.runAsync(game.onLoad);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump(const Duration(milliseconds: 300));

    final perspective = game.tileHeight / game.tileWidth;
    expect(
      perspective,
      0.5,
      reason: 'The ground must match the 30-degree source camera.',
    );
    final worldBefore = game.groundAnchor(-7, -1);
    final yardBefore = game.groundAnchor(3, 3);
    final initial = game.cellTop(3, 3) + Offset(0, game.tileHeight / 2);
    expect(game.cellAt(initial), (3, 3));
    game.moveCamera(const Offset(55, -24));
    expect(game.groundAnchor(-7, -1) - worldBefore, const Offset(55, -24));
    expect(game.groundAnchor(3, 3) - yardBefore, const Offset(55, -24));
    expect(game.cellAt(game.cellTop(3, 3) + Offset(0, game.tileHeight / 2)), (
      3,
      3,
    ));
    game.scaleCamera(1.5, Offset(game.size.x / 2, game.size.y / 2));
    expect(game.zoom, closeTo(1.5, 0.001));
    expect(game.tileHeight / game.tileWidth, closeTo(perspective, 0.001));
    final worldDelta = game.groundAnchor(-7, -1) - game.groundAnchor(3, 3);
    final initialDelta = worldBefore - yardBefore;
    expect(worldDelta.dx, closeTo(initialDelta.dx * 1.5, 0.001));
    expect(worldDelta.dy, closeTo(initialDelta.dy * 1.5, 0.001));
    expect(game.cellAt(game.cellTop(3, 3) + Offset(0, game.tileHeight / 2)), (
      3,
      3,
    ));
    expect(
      game.cellAt(game.cellTop(0, -2) + Offset(0, game.tileHeight / 2)),
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    habitat.dispose();
    session.dispose();
  });

  testWidgets('visible tree canopy and cat can be selected by their sprites', (
    tester,
  ) async {
    final session = SessionStore();
    final habitat = HabitatService(session, CatStore(session))
      ..items = [const HabitatItem(id: 'tree', sku: 'small_tree', x: 3, y: 3)]
      ..cats = [const HabitatCat(id: 'cat', name: 'Lua')]
      ..selectedCatIds = ['cat']
      ..catAnchors = {'cat': (5, 4)};
    final sprites = HabitatSprites();
    final game = HabitatGame(habitat, sprites);
    await tester.runAsync(() async {
      await game.onLoad();
      await sprites.preloadReady(['tree_default_NE', 'animal-cat']);
    });
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump(const Duration(milliseconds: 400));

    final tree = habitat.items.single;
    final canopy = game.itemBounds(tree).topCenter + const Offset(0, 6);
    expect(game.itemAtScreen(canopy), same(tree));
    final catCenter =
        game.cellTop(5, 4) +
        Offset(0, game.tileHeight * 0.75 - game.tileWidth * 0.4);
    expect(game.catAtScreen(catCenter), 'cat');

    await tester.pumpWidget(const SizedBox());
    habitat.dispose();
    session.dispose();
  });

  testWidgets(
    'cats wander only through free yard cells without changing anchors',
    (tester) async {
      final session = SessionStore();
      final habitat = HabitatService(session, CatStore(session))
        ..cats = [const HabitatCat(id: 'cat', name: 'Lua')]
        ..selectedCatIds = ['cat']
        ..catAnchors = {'cat': (3, 3)};
      final game = HabitatGame(habitat, HabitatSprites());
      await tester.runAsync(game.onLoad);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.pump(const Duration(milliseconds: 300));

      final visited = <(int, int)>{};
      for (var step = 0; step < 100; step++) {
        game.update(0.2);
        final cell = game.catCells.single;
        expect(habitat.isFreeForCat(cell.$1, cell.$2), isTrue);
        visited.add(cell);
      }
      expect(visited.length, greaterThan(1));
      expect(habitat.catAnchors['cat'], (3, 3));
      await tester.pumpWidget(const SizedBox());
      habitat.dispose();
      session.dispose();
    },
  );
}
