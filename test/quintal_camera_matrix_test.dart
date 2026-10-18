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
    'maximum production camera matrix keeps every action visible while moving',
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
      final sprites = HabitatSprites();
      final scene = HabitatGame(h, sprites, ambientCycle: 0);
      scene.onGameResize(Vector2(390, 844));
      await tester.runAsync(scene.onLoad);
      scene.update(0);
      scene.zoom = 2.4;
      var focus = scene.productionTargets.firstWhere((t) => t.role == 'market');
      scene.moveCamera(const Offset(195, 450) - scene.productionFocus(focus));
      final key = GlobalKey(), captures = <String>[];
      const showActions = true;
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

      final before = jsonEncode(h.production);
      final targets = scene.productionTargets.toList();
      expect(h.productionRows('plots'), hasLength(12));
      expect(
        targets.where((t) => t.kind == 'coop' && t.role == 'resident'),
        hasLength(4),
      );
      expect(
        targets.where((t) => t.kind == 'pasture' && t.role == 'resident'),
        hasLength(2),
      );
      var checked = 0;
      for (final width in [320.0, 390.0]) {
        final height = width == 320 ? 568.0 : 844.0;
        tester.view.physicalSize = Size(width, height);
        scene.onGameResize(Vector2(width, height));
        for (final zoom in [.8, 1.6, 2.4]) {
          for (var edge = 0; edge < 4; edge++) {
            for (final target in targets) {
              focus = target;
              scene.selectedProduction = target;
              scene.zoom = zoom;
              final location = switch (edge) {
                0 => Offset(0, height / 2),
                1 => Offset(width, height / 2),
                2 => Offset(width / 2, 0),
                _ => Offset(width / 2, height),
              };
              scene.moveCamera(location - scene.productionFocus(target));
              scene.update(.25);
              await paint();
              await tester.pump();
              final rect = tester.getRect(find.byType(QuintalObjectActions));
              final reason =
                  '$width / $zoom / edge $edge / ${target.kind}:${target.role}:${target.target}';
              expect(rect.left, greaterThanOrEqualTo(7.9), reason: reason);
              expect(
                rect.right,
                lessThanOrEqualTo(width - 7.9),
                reason: reason,
              );
              expect(rect.top, greaterThanOrEqualTo(77.9), reason: reason);
              expect(
                rect.bottom,
                lessThanOrEqualTo(height - 7.9),
                reason: reason,
              );
              expect(tester.takeException(), isNull, reason: reason);
              checked++;
              if (edge == 3 &&
                  target.kind == 'pasture' &&
                  target.role == 'resident' &&
                  target.target == '1') {
                final name = 'quintal_matrix_${width.toInt()}_z$zoom';
                captures.add(name);
                await capture('$visualGalleryDirectory/$name.png');
              }
            }
          }
        }
      }
      expect(checked, targets.length * 24);
      expect(jsonEncode(h.production), before);
      await tester.runAsync(() => updateVisualGallery(captures));
      scene.onRemove();
      await tester.pumpWidget(const SizedBox());
      h.dispose();
      store.dispose();
      account.dispose();
    },
  );
}
