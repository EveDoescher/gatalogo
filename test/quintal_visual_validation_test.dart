import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';
import 'package:catlogue/game/habitat_game.dart';
import 'package:catlogue/game/habitat_sprites.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/session_store.dart';

import 'visual_validation_capture_test.dart' show ValidationDatabase;

void main() {
  testWidgets(
    'quintal renderer matrix: edges, water, depth, expansion and zoom',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = SessionStore();
      final store = CatStore(session);
      final habitat =
          HabitatService(session, store, database: ValidationDatabase())
            ..items = [
              const HabitatItem(id: 'bed', sku: 'cat_bed', x: 3, y: 3),
              const HabitatItem(id: 'tree', sku: 'small_tree', x: 0, y: 0),
              const HabitatItem(id: 'oak', sku: 'oak_tree', x: 6, y: 3),
              const HabitatItem(id: 'stone', sku: 'small_rock', x: 0, y: 4),
              const HabitatItem(id: 'flower', sku: 'red_flowers', x: 6, y: 6),
              const HabitatItem(id: 'bowl', sku: 'food_bowl', x: 4, y: 5),
              const HabitatItem(id: 'garden', sku: 'leaf_garden', x: 5, y: 6),
              for (var x = 1; x <= 2; x++)
                for (var y = 5; y <= 6; y++)
                  HabitatItem(id: 'water-$x-$y', sku: 'water_tile', x: x, y: y),
              const HabitatItem(id: 'bridge', sku: 'wood_bridge', x: 1, y: 5),
            ]
            ..cats = [const HabitatCat(id: 'cat', name: 'Lua')]
            ..selectedCatIds = ['cat']
            ..catAnchors = {'cat': (4, 4)}
            ..pendingGift = {
              'id': 'validation',
              'state': 'available',
              'visitor': 'bee',
            };
      final sprites = HabitatSprites();
      final game = HabitatGame(habitat, sprites, ambientCycle: 0);
      await tester.runAsync(game.onLoad);
      final output = Directory('build/galeria-visual/quintal-auditoria');
      await tester.runAsync(() => output.create(recursive: true));
      for (final size in [const Size(390, 844), const Size(700, 700)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
        await tester.pump();
        game.pauseEngine();
        for (final expansion in [0, 3]) {
          habitat.expansionLevel = expansion;
          habitat.buildableCells = HabitatService.yardCells(expansion);
          for (final zoom in [.8, 1.6]) {
            game.zoom = zoom;
            for (final camera in {
              'centro': Offset.zero,
              'oeste': Offset(size.width * .4, 0),
              'leste': Offset(-size.width * .4, 0),
              'norte': Offset(0, size.height * .4),
              'sul': Offset(0, -size.height * .4),
            }.entries) {
              game.pan = camera.value;
              await tester.runAsync(() async {
                game.update(.7);
                await game.prepareCurrentVisitors();
                final recorder = ui.PictureRecorder();
                game.render(ui.Canvas(recorder));
                final picture = recorder.endRecording();
                final image = await picture.toImage(
                  size.width.toInt(),
                  size.height.toInt(),
                );
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final name =
                    '${size.width.toInt()}-e$expansion-z$zoom-${camera.key}';
                await File('${output.path}/$name.png')
                    .writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
                picture.dispose();
              });
              expect(tester.takeException(), isNull);
            }
          }
        }
      }
      for (final key in [
        'bed_NE',
        'rock_smallA_NE',
        'tree_default_NE',
        'flower_redA_NE',
        'bowl_NE',
      ]) {
        final preview = await tester.runAsync(() => sprites.preview(key));
        expect(
          preview!.$1.width,
          320,
          reason: '$key must use a source-model thumbnail',
        );
        expect(preview.$2.longestSide, greaterThan(270));
      }
      await tester.pumpWidget(const SizedBox());
      sprites.catAnimations.dispose();
      habitat.dispose();
      store.dispose();
      session.dispose();
    },
    skip: Platform.environment['GATALOGO_CAPTURE_QUINTAL'] != '1',
  );
}
