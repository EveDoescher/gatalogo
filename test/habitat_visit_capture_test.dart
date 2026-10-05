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
  testWidgets('record actual game renderer arrival, delivery and departure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = SessionStore();
    final store = CatStore(session);
    final habitat = HabitatService(
      session,
      store,
      database: ValidationDatabase(),
    );
    final sprites = HabitatSprites();
    final game = HabitatGame(habitat, sprites, ambientCycle: 0)..zoom = .72;
    await tester.runAsync(game.onLoad);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    game.pauseEngine();
    final frames = Directory('build/galeria-visual/visit-frames');
    await tester.runAsync(() => frames.create(recursive: true));
    for (var index = 0; index < 360; index++) {
      final age = index * .7;
      habitat.pendingGift = {
        'id': 'visual-fixture',
        'state': age < 22 ? 'visiting' : 'available',
        'visitor': 'bee',
        'created_at': DateTime.now()
            .toUtc()
            .subtract(Duration(milliseconds: (age * 1000).round()))
            .toIso8601String(),
      };
      await tester.runAsync(() async {
        game.update(.7);
        await game.prepareCurrentVisitors();
        final recorder = ui.PictureRecorder();
        game.render(ui.Canvas(recorder));
        final picture = recorder.endRecording();
        final image = await picture.toImage(600, 700);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${frames.path}/${index.toString().padLeft(3, '0')}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
    }
    expect(habitat.pendingGift?['state'], 'available');
    expect(
      habitat.balance,
      0,
    ); // Rendering and watching visitors never awards coins.
    await tester.pumpWidget(const SizedBox());
    sprites.catAnimations.dispose();
    habitat.dispose();
    store.dispose();
    session.dispose();
  }, skip: Platform.environment['GATALOGO_CAPTURE_MOTION'] != '1');
}
