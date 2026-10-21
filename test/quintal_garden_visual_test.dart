import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:catlogue/game/habitat_game.dart';
import 'package:catlogue/game/habitat_sprites.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/services/product_api_service.dart';

import 'visual_validation_capture_test.dart'
    show ValidationAccount, ValidationStore, ValidationDatabase;
import 'support/visual_gallery.dart';

class _Api extends ProductApiService {
  _Api(super.session, this.fixture);
  final Map<String, dynamic> fixture;
  @override
  Future<Map<String, dynamic>> get(String path) async => switch (path) {
    '/app/quintal' => fixture,
    '/app/habitat' => Map<String, dynamic>.from(fixture['habitat']),
    '/app/habitat/shop' => Map<String, dynamic>.from(fixture['shop']),
    _ => {},
  };
}

class _Scene extends CustomPainter {
  _Scene(this.game);
  final HabitatGame game;
  @override
  void paint(Canvas canvas, Size size) => game.render(canvas);
  @override
  bool shouldRepaint(_Scene old) => true;
}

void main() {
  testWidgets(
    'garden expands from confirmed rows and foliage keeps its soil origin',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = Map<String, dynamic>.from(
        jsonDecode(
          File('test/fixtures/quintal_production.json').readAsStringSync(),
        ),
      );
      final account = ValidationAccount(),
          store = ValidationStore(ValidationAccount());
      final h = HabitatService(
        account,
        store,
        database: ValidationDatabase(),
        api: _Api(account, fixture),
      );
      await h.load();
      const crops = ['corn', 'wheat', 'carrot', 'turnip', 'pumpkin', 'melon'];
      final now = h.serverNow;
      Map<String, dynamic> plot(int slot, {bool planted = false}) => {
        'slot': slot,
        'crop': planted ? crops[slot % 6] : null,
        'watered': false,
        'started_at': planted
            ? now.subtract(const Duration(hours: 3)).toIso8601String()
            : null,
        'ready_at': planted
            ? now.subtract(const Duration(hours: 1)).toIso8601String()
            : null,
      };
      void level(int current, int target) {
        h.production['facilities'] = [
          for (final f in h.productionRows('facilities'))
            if (f['kind'] == 'garden')
              {
                ...f,
                'level': current,
                'target_level': target,
                'started_at': target > 0
                    ? now.subtract(const Duration(hours: 1)).toIso8601String()
                    : null,
                'ready_at': target > 0
                    ? now.add(const Duration(hours: 1)).toIso8601String()
                    : null,
              }
            else
              f,
        ];
      }

      level(1, 2);
      h.production['plots'] = [
        for (var slot = 0; slot < 4; slot++) plot(slot, planted: true),
      ];
      final sprites = HabitatSprites();
      final scene = HabitatGame(h, sprites, ambientCycle: 0);
      scene.onGameResize(Vector2(390, 844));
      await tester.runAsync(scene.onLoad);
      scene.update(0);
      scene.focusProduction('garden');
      scene.zoom = 1.65;
      final focus = scene.productionTargets.firstWhere(
        (t) => t.kind == 'garden' && t.role == 'plot' && t.target == '2',
      );
      scene.moveCamera(const Offset(235, 360) - scene.productionFocus(focus));
      final key = GlobalKey(), captures = <String>[];
      Future<void> paint() async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: CustomPaint(
                  size: const Size(390, 844),
                  painter: _Scene(scene),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      Future<void> capture(String path) async {
        await paint();
        await tester.runAsync(() => GoogleFonts.pendingFonts());
        await paint();
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(path);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      final stock = Map.of(h.productionStock);
      for (final end in [8, 12]) {
        final previous = h.productionRows('plots');
        final origins = {
          for (final t in scene.productionTargets.where(
            (t) => t.kind == 'garden' && t.role == 'plot',
          ))
            t.target: (t.x, t.y),
        };
        expect(previous.length, end - 4);
        level(end ~/ 4 - 1, end ~/ 4);
        scene.update(0);
        // The in-progress expansion still exposes only the old planting targets.
        expect(
          scene.productionTargets
              .where((t) => t.kind == 'garden' && t.role == 'plot')
              .length,
          end - 4,
        );
        final works = scene.productionTargets.singleWhere(
          (t) => t.kind == 'garden' && t.role == 'build',
        );
        final badge = scene.productionBadgeBounds(works).center;
        expect(scene.productionObjectAt(badge)?.role, 'build');
        final name = 'quintal_garden_expanding_$end';
        captures.add(name);
        await capture('$visualGalleryDirectory/$name.png');
        level(end ~/ 4, 0);
        h.production['plots'] = [
          ...previous,
          for (var slot = end - 4; slot < end; slot++) plot(slot),
        ];
        scene.update(0);
        expect(
          scene.productionTargets
              .where((t) => t.kind == 'garden' && t.role == 'plot')
              .length,
          end,
        );
        for (var frame = 0; frame < 32; frame++) {
          scene.update(.05);
          if ([0, 12, 31].contains(frame)) {
            final name = 'quintal_garden_${end}_$frame';
            captures.add(name);
            await capture('$visualGalleryDirectory/$name.png');
          }
          if (Platform.environment['GATALOGO_CAPTURE_GARDEN'] == '1') {
            await capture(
              '$visualGalleryDirectory/horta/expand_$end/${frame.toString().padLeft(3, '0')}.png',
            );
          }
        }
        for (final t in scene.productionTargets.where(
          (t) =>
              t.kind == 'garden' &&
              t.role == 'plot' &&
              origins.containsKey(t.target),
        )) {
          expect((t.x, t.y), origins[t.target]);
        }
        expect(h.productionRows('plots').take(end - 4).toList(), previous);
      }
      h.production['plots'] = [
        for (var slot = 0; slot < 12; slot++) plot(slot, planted: slot < 6),
      ];
      final before = jsonEncode(h.production);
      for (var frame = 0; frame < 32; frame++) {
        scene.update(.2);
        if (Platform.environment['GATALOGO_CAPTURE_GARDEN'] == '1') {
          await capture(
            '$visualGalleryDirectory/horta/foliage/${frame.toString().padLeft(3, '0')}.png',
          );
        }
      }
      for (final still in [false, true]) {
        scene.reducedMotion = still;
        scene.update(.2);
        final name = still
            ? 'quintal_garden_foliage_reduced'
            : 'quintal_garden_foliage';
        captures.add(name);
        await capture('$visualGalleryDirectory/$name.png');
      }
      expect(jsonEncode(h.production), before);
      expect(h.productionStock, stock);
      await tester.runAsync(() => updateVisualGallery(captures));
      scene.onRemove();
      await tester.pumpWidget(const SizedBox());
      h.dispose();
      store.dispose();
      account.dispose();
    },
  );
}
