import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:google_fonts/google_fonts.dart';
import 'package:catlogue/game/habitat_game.dart';
import 'package:catlogue/game/quintal_scene_target.dart';
import 'package:catlogue/game/habitat_sprites.dart';
import 'package:catlogue/game/habitat_cat_animations.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/services/product_api_service.dart';
import 'package:catlogue/widgets/quintal_object_actions.dart';

import 'visual_validation_capture_test.dart'
    show ValidationAccount, ValidationStore, ValidationDatabase;
import 'screen_corrections_test.dart' show screenApp;
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
  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async => throw StateError('Visual test cannot submit operations');
}

class _Scene extends CustomPainter {
  _Scene(this.game) : super(repaint: game.interactionPositions);
  final HabitatGame game;
  @override
  void paint(Canvas canvas, Size size) => game.render(canvas);
  @override
  bool shouldRepaint(_Scene old) => true;
}

void main() {
  testWidgets(
    'own bowls, gradual meals, preference, drinking and reduced motion in scene',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = Map<String, dynamic>.from(
        jsonDecode(
          File('test/fixtures/quintal_production.json').readAsStringSync(),
        ),
      );
      final cat = fixture['habitat']['cats'][0]['id'] as String;
      const other = 'other-cat';
      fixture['habitat']['pending_gift'] = null;
      fixture['habitat']['cats'] = [
        {'id': cat, 'name': 'Mimi'},
        {'id': other, 'name': 'Pipoca', 'primary_color': 'preto'},
      ];
      fixture['habitat']['selected_cat_ids'] = [cat, other];
      fixture['habitat']['cat_anchors'] = {
        cat: [2, 4],
        other: [7, 4],
      };
      fixture['habitat']['items'] = [
        for (final id in [cat, other])
          for (final role in ['food_bowl', 'water_bowl'])
            {
              'id': '$id-$role',
              'sku': role,
              'x': id == cat ? 4 : 6,
              'y': role == 'food_bowl' ? 4 : 5,
              'rotation': 0,
              'care_state': {
                'cat_id': id,
                'color_index': id == cat ? 0 : 2,
                'role': role,
              },
            },
      ];
      final account = ValidationAccount(),
          store = ValidationStore(ValidationAccount());
      final h = HabitatService(
        account,
        store,
        database: ValidationDatabase(),
        api: _Api(account, fixture),
      );
      final now = DateTime.utc(2026, 10, 15, 12);
      void resetCare() {
        fixture['production']['server_now'] = now.toIso8601String();
        fixture['production']['updates'] = [];
        fixture['production']['cats'] = [
          for (final id in [cat, other])
            {
              'cat_id': id,
              'affinity': 12,
              'food_bowl': '$id-food_bowl',
              'water_bowl': '$id-water_bowl',
              'recipe': 'garden',
              'portions': 1,
              'served_at': now.toIso8601String(),
              'last_meal_at': now.toIso8601String(),
              'next_appetite_at': now
                  .add(const Duration(hours: 12))
                  .toIso8601String(),
              'water_available': true,
              'water_until': now
                  .add(const Duration(hours: 24))
                  .toIso8601String(),
            },
        ];
      }

      resetCare();
      await h.load();
      final sprites = HabitatSprites();
      await tester.runAsync(() async {
        await sprites.initialize();
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
      final captures = <String>[];
      for (final scenario in [
        'meal',
        'refused',
        'drink',
        'reduced',
        'taste_320',
      ]) {
        final width = scenario == 'taste_320' ? 320.0 : 390.0;
        tester.view.physicalSize = Size(width, 844);
        resetCare();
        await h.refreshProduction();
        final game = HabitatGame(h, sprites, ambientCycle: 0)
          ..reducedMotion = scenario == 'reduced';
        game.onGameResize(Vector2(width, 844));
        await tester.runAsync(() async {
          await game.onLoad();
          await sprites.preloadReady([
            for (final color in [0, 2])
              for (var amount = 0; amount <= 2; amount++)
                sprites.keyFor('production:crafted-cat-food-$color-$amount', 0),
          ]);
          await Future.wait([
            for (final coat in ['solid_gray', 'solid_black'])
              for (final clip in [
                HabitatCatClip.eat,
                HabitatCatClip.upset,
                HabitatCatClip.dance,
                HabitatCatClip.happy,
              ])
                sprites.catCoat(coat).preload(clip),
          ]);
          await sprites.preloadReady([
            for (final item in h.items)
              sprites.keyFor(h.spriteFor(item), item.rotation),
          ]);
        });
        for (final item in h.items) {
          expect(
            sprites.cached(sprites.keyFor(h.spriteFor(item), item.rotation)),
            isNotNull,
            reason: item.id,
          );
        }
        game.update(0);
        final target = QuintalSceneTarget(
          'cat',
          cat,
          scenario == 'drink' ? 'water_cat' : 'food_cat',
          4,
          scenario == 'drink' ? 5 : 4,
        );
        game.selectedProduction = target;
        game.zoom = 1.9;
        game.moveCamera(Offset(width / 2, 490) - game.productionFocus(target));
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: screenApp(
              Scaffold(
                body: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _Scene(game))),
                    QuintalObjectOverlay(
                      game: game,
                      target: target,
                      onClose: () {},
                      onFish: () {},
                    ),
                  ],
                ),
              ),
              store,
              scale: width == 320 ? 1.5 : 1,
            ),
          ),
        );
        await tester.pump();
        final stock = Map.of(h.productionStock);
        if (scenario == 'drink') {
          game.showProductionAction(target, 'water_cat');
        } else {
          for (final care in fixture['production']['cats']) {
            final refused = scenario == 'refused' && care['cat_id'] == cat;
            care['portions'] = refused ? 0 : 1;
            care['last_reaction'] = {
              'kind': refused ? 'refused' : 'meal',
              'event_id': '$scenario-${care['cat_id']}',
              'at': now.toIso8601String(),
              'recipe': 'garden',
              'portions_before': 2,
              'portions_after': refused ? 0 : 1,
              'lost': 2,
              'preference': scenario == 'taste_320'
                  ? 3
                  : care['cat_id'] == cat
                  ? 1
                  : 6,
              'next_preference': scenario == 'taste_320'
                  ? 4
                  : care['cat_id'] == cat
                  ? 1
                  : 6,
            };
          }
          await h.refreshProduction();
        }
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        });
        await tester.pump();
        Future<void> capture(String path) async {
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull, reason: path);
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(path);
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        if (scenario == 'taste_320' || scenario == 'reduced') {
          final position = game.catRoutineState(cat)['position'];
          if (scenario == 'reduced') {
            for (var i = 0; i < 50; i++) {
              game.update(.1);
              await tester.pump();
            }
            expect(game.catRoutineState(cat)['position'], position);
            expect(game.catRoutineState(cat)['event'], isNull);
          }
          if (scenario == 'taste_320') {
            for (var i = 0; i < 90; i++) {
              game.update(.1);
              await tester.pump();
            }
          }
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
          });
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            find.text('Servir').hitTestable(),
            findsOneWidget,
            reason: scenario,
          );
          expect(
            tester.getRect(find.text('Pote de Mimi')).top,
            greaterThanOrEqualTo(78),
            reason: scenario,
          );
          final name = 'quintal_meals_$scenario';
          await capture('$visualGalleryDirectory/$name.png');
          captures.add(name);
        } else {
          final observed = <Map<String, dynamic>>[];
          var middleCaptured = false, sawVisit = false;
          for (var frame = 0; frame < 80; frame++) {
            game.update(.1);
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            await tester.pump();
            final state = game.catRoutineState(cat);
            if (state['visiting'] == true) {
              sawVisit = true;
              expect(game.productionBowlActive(target), isTrue);
              expect(
                state['target'],
                '$cat-${scenario == 'drink' ? 'water_bowl' : 'food_bowl'}',
              );
              if (!middleCaptured &&
                  (scenario == 'drink' || (state['food'] as num? ?? 2) < 1.6)) {
                final name = 'quintal_meals_$scenario';
                await capture('$visualGalleryDirectory/$name.png');
                captures.add(name);
                middleCaptured = true;
              }
            }
            final second = game.catRoutineState(other);
            if (scenario != 'drink' && second['target'] != null) {
              expect(second['target'], '$other-food_bowl');
            }
            observed.add({
              'frame': frame,
              'activity': state['activity'],
              'food': state['food'],
              'clip': state['clip'].toString(),
              'other_target': second['target'],
            });
            if (Platform.environment['GATALOGO_CAPTURE_MEALS'] == '1') {
              await capture(
                '$visualGalleryDirectory/refeicoes/$scenario/${frame.toString().padLeft(3, '0')}.png',
              );
            }
          }
          expect(
            sawVisit,
            isTrue,
            reason: '$scenario: ${game.catRoutineState(cat)}',
          );
          expect(middleCaptured, isTrue, reason: scenario);
          expect(h.productionStock, stock);
          if (scenario != 'drink') {
            expect(game.catRoutineState(cat)['event'], isNull);
            await h.refreshProduction();
            await tester.pump();
            game.update(0);
            expect(
              game.catRoutineState(cat)['event'],
              isNull,
              reason: 'Refresh must not replay the same meal',
            );
            expect(
              observed.any((s) => s['clip'] == HabitatCatClip.upset.toString()),
              isTrue,
            );
          } else {
            expect(h.productionCat(cat)['water_available'], isTrue);
          }
          File('$visualGalleryDirectory/refeicoes_$scenario.json')
              .writeAsStringSync(jsonEncode(observed));
        }
        // A new event can share its timestamp. Editing cancels this new visit.
        if (scenario == 'meal') {
          final care = fixture['production']['cats'][0];
          care['last_reaction']['event_id'] = 'same-time-new-event';
          await h.refreshProduction();
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pump();
          expect(game.catRoutineState(cat)['event'], 'same-time-new-event');
          game.editing = true;
          game.update(0);
          expect(game.catRoutineState(cat)['event'], isNull);
          expect(game.catRoutineState(cat)['target'], isNull);
        }
        game.onRemove();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
      await tester.runAsync(() => updateVisualGallery(captures));
      h.dispose();
      store.dispose();
      account.dispose();
    },
  );
}
