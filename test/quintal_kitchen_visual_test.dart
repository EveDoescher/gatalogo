import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catlogue/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:catlogue/game/habitat_game.dart';
import 'package:catlogue/game/habitat_sprites.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/services/product_api_service.dart';
import 'package:catlogue/widgets/quintal_object_actions.dart';

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
    'kitchen keeps cooking queue and ready food visible without local credit',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      GoogleFonts.config.allowRuntimeFetching = false;
      final theme = AppTheme.lightTheme;
      await tester.runAsync(() async {
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
              rootBundle.load(
                'packages/lucide_icons_flutter/assets/lucide.ttf',
              ),
            ))
            .load();
        GoogleFonts.nunito(fontWeight: FontWeight.w800);
        GoogleFonts.nunito(fontWeight: FontWeight.w900);
        await GoogleFonts.pendingFonts();
      });
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
      final now = h.serverNow;
      String at(int minutes) =>
          now.add(Duration(minutes: minutes)).toIso8601String();
      Map<String, dynamic> task(String id, int start, int end) => {
        'id': id,
        'kind': 'cook',
        'target': 'garden',
        'status': end <= 0 ? 'ready' : 'active',
        'started_at': at(start),
        'ready_at': at(end),
      };
      void level(int current, int target) {
        h.production['facilities'] = [
          for (final f in h.productionRows('facilities'))
            if (f['kind'] == 'kitchen')
              {
                ...f,
                'level': current,
                'target_level': target,
                'started_at': target > 0 ? at(-30) : null,
                'ready_at': target > 0 ? at(30) : null,
              }
            else
              f,
        ];
      }

      level(2, 0);
      h.production['tasks'] = [
        task('ready', -20, -10),
        task('active', -5, 5),
        task('queued', 5, 15),
      ];
      final sprites = HabitatSprites();
      final scene = HabitatGame(h, sprites, ambientCycle: 0);
      scene.onGameResize(Vector2(390, 844));
      await tester.runAsync(scene.onLoad);
      scene.update(0);
      scene.zoom = 2.4;
      final focus = scene.productionTargets.firstWhere(
        (t) => t.role == 'kitchen',
      );
      scene.moveCamera(const Offset(195, 450) - scene.productionFocus(focus));
      final key = GlobalKey(), captures = <String>[];
      var showActions = false;
      Future<void> paint() async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: theme,
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    size: Size(scene.size.x, scene.size.y),
                    textScaler: const TextScaler.linear(1.5),
                  ),
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size(scene.size.x, scene.size.y),
                        painter: _Scene(scene),
                      ),
                      if (showActions)
                        QuintalObjectOverlay(
                          game: scene,
                          target: focus,
                          onClose: () {},
                          onFish: () {},
                        ),
                    ],
                  ),
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
        if (showActions) {
          final context = tester.element(find.byType(MaterialApp));
          final images = tester
              .widgetList<Image>(find.byType(Image))
              .map((w) => w.image)
              .toList();
          await tester.runAsync(() async {
            for (final image in images) {
              await precacheImage(image, context);
            }
            await GoogleFonts.pendingFonts();
          });
          await paint(); // Repaint after automatic framing and asset loading.
        }
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
      final before = jsonEncode(h.production['tasks']);
      // At both capacities and zooms, the complete progress bar clears the
      // actual building bounds. Both status badges keep their tap targets.
      for (final current in [1, 2]) {
        level(current, current == 1 ? 2 : 0);
        for (final zoom in [.8, 1.6, 2.4]) {
          scene.zoom = zoom;
          final building = sprites.keyFor(
            'production:crafted-kitchen-$current-ready',
            0,
          );
          final bounds = sprites.placedBounds(
            building,
            scene.productionFocus(focus),
            sprites.worldScale(building, scene.tileWidth),
          );
          final badge = scene.productionBadgeBounds(focus).center;
          expect(badge.dy + 44, lessThan(bounds.top));
          for (final dx in [-24.0, 24.0]) {
            expect(
              scene.productionObjectAt(badge + Offset(dx, 0))?.kind,
              'kitchen',
            );
          }
        }
      }
      level(2, 0);
      scene.zoom = 2.4;
      scene.moveCamera(const Offset(195, 450) - scene.productionFocus(focus));
      for (var frame = 0; frame < 64; frame++) {
        scene.update(.1);
        if (Platform.environment['GATALOGO_CAPTURE_KITCHEN'] == '1') {
          await capture(
            '$visualGalleryDirectory/cozinha/simultaneous/${frame.toString().padLeft(3, '0')}.png',
          );
        }
        if ([0, 16, 63].contains(frame)) {
          final name = 'quintal_kitchen_level2_$frame';
          captures.add(name);
          await capture('$visualGalleryDirectory/$name.png');
        }
      }
      expect(jsonEncode(h.production['tasks']), before);
      expect(h.productionStock, stock);
      // A timer crossing its deadline never credits/collects the serving dish.
      h.production['tasks'] = [
        task('ready', -20, -10),
        task('active', -10, -1),
        task('queued', -1, 9),
      ];
      scene.update(.1);
      captures.add('quintal_kitchen_next_started');
      await capture('$visualGalleryDirectory/quintal_kitchen_next_started.png');
      expect(h.productionStock, stock);
      scene.reducedMotion = true;
      scene.update(.1);
      captures.add('quintal_kitchen_reduced');
      await capture('$visualGalleryDirectory/quintal_kitchen_reduced.png');
      // Already prepared food remains in place during expansion.
      level(1, 2);
      scene.update(.1);
      captures.add('quintal_kitchen_expanding_ready');
      await capture(
        '$visualGalleryDirectory/quintal_kitchen_expanding_ready.png',
      );
      expect(h.productionStock, stock);
      level(2, 0);
      scene.selectedProduction = focus;
      showActions = true;
      for (final width in [320.0, 390.0]) {
        await tester.pumpWidget(const SizedBox());
        final height = width == 320 ? 568.0 : 844.0;
        tester.view.physicalSize = Size(width, height);
        scene.onGameResize(Vector2(width, height));
        scene.zoom = .8;
        scene.moveCamera(Offset(12, height / 2) - scene.productionFocus(focus));
        final name = 'quintal_camera_kitchen_${width.toInt()}';
        captures.add(name);
        await capture('$visualGalleryDirectory/$name.png');
        final actions = tester.getRect(find.byType(QuintalObjectActions));
        expect(actions.left, greaterThanOrEqualTo(8));
        expect(actions.right, lessThanOrEqualTo(width - 8));
        expect(actions.top, greaterThanOrEqualTo(78));
        for (final label in ['Receitas', 'Recolher', 'Fila']) {
          expect(find.text(label).hitTestable(), findsOneWidget);
          final text = tester.renderObject<RenderParagraph>(find.text(label));
          expect(
            text.size.height,
            lessThan(35),
            reason: '$label must not split inside a word',
          );
        }
      }
      await tester.runAsync(() => updateVisualGallery(captures));
      scene.onRemove();
      await tester.pumpWidget(const SizedBox());
      h.dispose();
      store.dispose();
      account.dispose();
    },
  );
}
