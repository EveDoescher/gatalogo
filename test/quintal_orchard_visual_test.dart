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
    'orchard grows fruit and collects each tree independently without local credit',
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
      void level(int current, int target) {
        h.production['facilities'] = [
          for (final f in h.productionRows('facilities'))
            if (f['kind'] == 'orchard')
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

      level(1, 0);
      h.production['tasks'] = [];
      final sprites = HabitatSprites();
      final scene = HabitatGame(h, sprites, ambientCycle: 0);
      scene.onGameResize(Vector2(390, 844));
      await tester.runAsync(scene.onLoad);
      scene.update(0);
      scene.zoom = 2.4;
      final focus = scene.productionTargets.firstWhere(
        (t) => t.kind == 'orchard' && t.target == 'apple',
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
      void trees(int apples, int pears, double progress) {
        h.production['residents'] = [
          for (final resident in h.productionRows('residents'))
            if (resident['kind'] != 'orchard') resident,
          {
            'kind': 'orchard',
            'count': 2,
            'ready': apples + pears,
            'animals': [
              for (var i = 0; i < 2; i++)
                {
                  'id': 'tree-$i',
                  'slot': i,
                  'ready': i == 0 ? apples : pears,
                  'progress': progress * 28800,
                  'production_progress': {
                    'observed_at': h.serverNow.toIso8601String(),
                    'cycle_seconds': 28800,
                    'elapsed_seconds': progress * 28800,
                    'pause_reason': (i == 0 ? apples : pears) == 3
                        ? 'full'
                        : null,
                  },
                },
            ],
          },
        ];
      }

      Future<void> state(String name) async {
        final label = 'quintal_orchard_$name';
        captures.add(label);
        await capture('$visualGalleryDirectory/$label.png');
        expect(h.productionStock, stock);
      }

      scene.zoom = 2.1;
      scene.moveCamera(const Offset(140, 370) - scene.productionFocus(focus));
      level(0, 0);
      await state('abandoned');
      level(0, 1);
      await state('clearing');
      level(1, 0);
      for (final (name, progress) in [
        ('empty', 0.0),
        ('bud', .33),
        ('growing', .66),
        ('full', 1.0),
      ]) {
        trees(0, 0, progress);
        await state(name);
        // A locally completed clock never grants/collects mature fruit.
        expect(h.productionRows('residents').last['ready'], 0);
      }
      trees(3, 3, 0);
      await state('ready');
      scene.update(.3);
      await state('pending');
      for (final fruit in ['apple', 'pear']) {
        trees(0, fruit == 'apple' ? 3 : 0, 0);
        final target = scene.productionTargets.firstWhere(
          (t) => t.kind == 'orchard' && t.target == fruit,
        );
        scene.showProductionAction(target, 'collect_residents');
        final before = jsonEncode(h.production['residents']);
        for (var frame = 0; frame < 16; frame++) {
          scene.update(.1);
          await capture(
            '$visualGalleryDirectory/pomar/$fruit/${frame.toString().padLeft(3, '0')}.png',
          );
          if ([0, 6, 15].contains(frame)) await state('${fruit}_$frame');
        }
        expect(jsonEncode(h.production['residents']), before);
      }
      scene.reducedMotion = true;
      scene.showProductionAction(focus, 'collect_residents');
      await state('reduced');
      scene.selectedProduction = focus;
      showActions = true;
      trees(3, 3, 0);
      for (final width in [320.0, 390.0]) {
        await tester.pumpWidget(const SizedBox());
        final height = width == 320 ? 568.0 : 844.0;
        tester.view.physicalSize = Size(width, height);
        scene.onGameResize(Vector2(width, height));
        scene.zoom = .8;
        scene.moveCamera(Offset(12, height / 2) - scene.productionFocus(focus));
        await state('actions_${width.toInt()}');
        expect(find.text('Recolher').hitTestable(), findsOneWidget);
      }
      expect(
        scene.productionTargets.where((t) => t.kind == 'orchard'),
        hasLength(2),
      );
      await tester.runAsync(() => updateVisualGallery(captures));
      scene.onRemove();
      await tester.pumpWidget(const SizedBox());
      h.dispose();
      store.dispose();
      account.dispose();
    },
  );
}
