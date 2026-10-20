import 'package:catlogue/widgets/quintal_play_arena.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show GameWidget;
import 'package:catlogue/pages/habitat_page.dart';
import 'package:catlogue/pages/habitat_shop_page.dart';
import 'package:catlogue/pages/quintal_game_page.dart';
import 'package:catlogue/services/habitat_navigation.dart';
import 'package:catlogue/widgets/illustrated_home_components.dart';
import 'package:catlogue/widgets/quintal_object_actions.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/services/product_api_service.dart';
import 'package:catlogue/widgets/quintal_inventory_tray.dart';
import 'package:catlogue/widgets/habitat_care_sheet.dart';
import 'package:catlogue/widgets/quintal_activity_result.dart';
import 'package:catlogue/widgets/quintal_production_widgets.dart';
import 'package:catlogue/game/habitat_sprites.dart';
import 'package:catlogue/game/habitat_game.dart';
import 'package:catlogue/game/quintal_scene_target.dart';
import 'package:catlogue/game/quintal_resident_motion.dart';
import 'package:catlogue/game/quintal_play_result.dart';

import 'visual_validation_capture_test.dart'
    show ValidationAccount, ValidationStore, ValidationDatabase;
import 'screen_corrections_test.dart' show screenApp;
import 'support/visual_gallery.dart';

class _ProductionApi extends ProductApiService {
  _ProductionApi(super.session, this.fixture);
  final Map<String, dynamic> fixture;
  int biteSeconds = 0;
  @override
  Future<Map<String, dynamic>> get(String path) async => switch (path) {
    '/app/quintal' => fixture,
    '/app/habitat' => Map<String, dynamic>.from(fixture['habitat'] as Map),
    '/app/habitat/shop' => Map<String, dynamic>.from(fixture['shop'] as Map),
    _ => {},
  };
  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    // Visual validation never writes to a real account or network endpoint.
    if (path != '/app/quintal/operations' ||
        !{'start_fish', 'start_play'}.contains(body?['action'])) {
      throw StateError('Unexpected gallery operation: $path');
    }
    return {
      ...fixture,
      'outcome': {
        'session_id': 'gallery-fishing',
        'bite_seconds': biteSeconds,
        'zone': .3,
        'speed': .3,
        'phase': .2,
      },
    };
  }
}

void main() {
  testWidgets('world object actions and inventory remain readable at phone sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    GoogleFonts.config.allowRuntimeFetching = false;
    final fixture = Map<String, dynamic>.from(
      jsonDecode(
        File('test/fixtures/quintal_production.json').readAsStringSync(),
      ) as Map,
    );
    final abandoned = jsonDecode(
      File('test/fixtures/quintal_abandoned.json').readAsStringSync(),
    ) as Map;
    final repairing = jsonDecode(
      File('test/fixtures/quintal_repairing.json').readAsStringSync(),
    ) as Map;
    final account = ValidationAccount(),
        store = ValidationStore(ValidationAccount());
    final api = _ProductionApi(account, fixture);
    final h = HabitatService(
      account,
      store,
      database: ValidationDatabase(),
      api: api,
    );
    await h.load();
    final sprites = HabitatSprites();
    await tester.runAsync(() async {
      await sprites.initialize();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final lucide = FontLoader('packages/lucide_icons_flutter/Lucide');
      lucide.addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
      await lucide.load();
      GoogleFonts.nunito(fontWeight: FontWeight.w800);
      GoogleFonts.nunito(fontWeight: FontWeight.w900);
      await GoogleFonts.pendingFonts();
      final warm = HabitatGame(h, sprites);
      await warm.onLoad();
      await sprites.preloadReady([
        for (final item in h.items.where((i) => !i.isPlaced))
          sprites.keyFor(h.spriteFor(item), item.rotation),
      ]);
      warm.onRemove();
    });
    final cases = <String, Widget>{
      for (final gained in [2, 0])
        'quintal_play_result_$gained': Scaffold(
          appBar: AppBar(title: const Text('Brincar com Mimi')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: QuintalActivityResult(
              success: true,
              title: 'Uma boa brincadeira juntos!',
              description: quintalPlayResultDescription({
                'care_effect': {
                  'bond_gained': gained,
                  'bond_total': 14,
                  'play_bonus_after': 20,
                },
              }),
              artwork: const QuintalArtwork('action_play', size: 160),
              onClose: () {},
            ),
          ),
        ),
      'quintal_cat_play': QuintalGamePage(
        habitat: h,
        catId: h.cats.first.id,
        catName: h.cats.first.name,
      ),
      for (final result in ['success', 'failure', 'practice'])
        'quintal_fishing_result_$result': Scaffold(
          appBar: AppBar(title: const Text('Pescar no píer')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: QuintalActivityResult(
              success: result != 'failure',
              title: result == 'failure'
                  ? 'O peixe escapou'
                  : result == 'practice'
                  ? 'Boa captura de treino!'
                  : 'Boa pescaria!',
              description: result == 'failure'
                  ? 'Na próxima, acompanhe o peixe com a faixa. Nenhum peixe foi adicionado ao inventário.'
                  : result == 'practice'
                  ? 'Treino concluído, sem adicionar peixes ao inventário.'
                  : '1 peixe(s) no inventário!',
              artwork: QuintalArtwork(
                result == 'failure' ? 'action_fish_rod' : 'fish',
                size: 160,
              ),
              onClose: () {},
            ),
          ),
        ),
      'quintal_cat_care': Scaffold(
        body: HabitatCareSheet(
          habitat: h,
          cat: h.cats.first,
          sprites: sprites,
          preference: 'descanso',
          onAction: (_) {},
        ),
      ),
    };
    final captures = <String>[];
    Future<void> loadVisibleArtwork() async {
      final context = tester.element(find.byType(MaterialApp));
      final images = tester
          .widgetList<Image>(find.byType(Image))
          .map((w) => w.image)
          .toList();
      await tester.runAsync(() async {
        await Future.wait(
          images.map((provider) => precacheImage(provider, context)),
        );
      });
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 844);
      for (final entry in cases.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(key: key, child: screenApp(entry.value, store)),
        );
        await tester.runAsync(() async {
          final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
          final context = tester.element(find.byType(MaterialApp));
          await Future.wait([
            for (final asset in manifest.listAssets().where(
              (a) =>
                  (a.startsWith('assets/gatalogo_asset_library/') ||
                      a.startsWith('assets/quintal/production/') ||
                      a.startsWith('assets/quintal/ui/')) &&
                  a.endsWith('.png'),
            ))
              precacheImage(AssetImage(asset), context),
          ]);
          await GoogleFonts.pendingFonts();
        });
        await tester.pump(const Duration(milliseconds: 200));
        if (entry.key == 'quintal_cat_play') {
          for (
            var attempt = 0;
            attempt < 100 &&
                find
                    .byWidgetPredicate(
                      (w) =>
                          w is QuintalPlayArena ||
                          w.key == const ValueKey('world-play-control'),
                    )
                    .evaluate()
                    .isEmpty;
            attempt++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump();
          }
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is QuintalPlayArena ||
                  w.key == const ValueKey('world-play-control'),
            ),
            findsOneWidget,
            reason:
                'Capture play only after the cat assets and session are ready',
          );
          await loadVisibleArtwork();
        }
        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} at $width',
        );
        if (width == 390 || entry.key == 'quintal_cat_play') {
          final captureName = width == 390 ? entry.key : '${entry.key}_320';
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('$visualGalleryDirectory/$captureName.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          captures.add(captureName);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    tester.view.physicalSize = const Size(390, 844);
    for (final caseName
        in [
          'garden',
          'garden_mature',
          'garden_empty',
          for (final crop in [
            'carrot',
            'turnip',
            'corn',
            'wheat',
            'pumpkin',
            'melon',
          ])
            'garden_harvest_$crop',
          'garden_harvest_reduced',
          'garden_project',
          'garden_project_max',
          'coop_project',
          'pasture_project',
          'kitchen_project',
          'garden_upgrading',
          'garden_upgrading_max',
          'coop_upgrading',
          'pasture_upgrading',
          'kitchen_upgrading',
          'coop',
          'coop_water',
          'coop_paused_nest',
          'coop_producing_nest',
          'coop_water_effect',
          'garden_water_effect',
          'cat_water_effect',
          'cat_food_effect',
          'coop_food_effect',
          'pasture_food_effect',
          'coop_water_reduced',
          'coop_scratch',
          'coop_shelter',
          'pasture_shelter',
          'coop_shelter_level1',
          'pasture_shelter_level1',
          'coop_shelter_upgrading',
          'coop_gate',
          'pasture_gate',
          'coop_routine_food',
          'coop_routine_water',
          'coop_nest',
          'pasture',
          'pasture_milk',
          'pasture_routine_food',
          'pasture_routine_water',
          'pasture_milking_empty',
          'pasture_milking_half',
          'pasture_milking_full',
          'pier',
          'kitchen',
          'market',
          'market_waiting',
          'market_ready',
          'orchard',
          'cat_food',
          'cat_water',
          'cat_play',
          'garden_choices',
          'kitchen_choices',
          'kitchen_fruit_choices',
          'market_fruit_choices',
          'cat_food_fruit_choices',
          'orchard_purpose',
          'kitchen_queue',
          'kitchen_waiting',
          'kitchen_simultaneous',
          'pier_fishing',
          'pier_fishing_waiting',
          'market_choices',
          'cat_food_choices',
          'garden_abandoned',
          'coop_abandoned',
          'pasture_abandoned',
          'kitchen_abandoned',
          'market_abandoned',
          'orchard_abandoned',
          'pier_abandoned',
          'coop_repairing',
          'pasture_repairing',
        ].where(
          (name) =>
              Platform.environment['GATALOGO_SCENE_CASES'] == null ||
              Platform.environment['GATALOGO_SCENE_CASES']!
                  .split(',')
                  .contains(name),
        )) {
      h.production = Map<String, dynamic>.from(
        (caseName.endsWith('_abandoned')
                ? abandoned
                : caseName.endsWith('_repairing')
                ? repairing
                : fixture)['production']
            as Map,
      );
      if (caseName.contains('_fruit_')) {
        h.production['stock'] = {
          ...h.productionStock,
          'apple': 3,
          'pear': 3,
          'ration:apple': 3,
          'ration:pear': 3,
        };
      }
      if (caseName == 'orchard_purpose') {
        h.production['facilities'] = [
          for (final f in h.productionRows('facilities'))
            {...f, if (f['kind'] == 'orchard') 'level': 0},
        ];
        h.production['offers'] = [
          {'id': 'orchard:1', 'available': true, 'reasons': []},
        ];
      }
      if (caseName == 'garden_water_effect') {
        h.production['plots'] = [
          for (final p in h.productionRows('plots'))
            if (p['slot'] == 0)
              {
                ...p,
                'watered': true,
                'started_at': h.serverNow
                    .subtract(const Duration(minutes: 5))
                    .toIso8601String(),
                'ready_at': h.serverNow
                    .add(const Duration(minutes: 15))
                    .toIso8601String(),
              }
            else
              p,
        ];
      }
      if (caseName == 'garden_mature') {
        const crops = ['corn', 'wheat', 'carrot', 'turnip', 'pumpkin', 'melon'];
        h.production['plots'] = [
          for (var slot = 0; slot < 8; slot++)
            {
              'slot': slot,
              'crop': slot < crops.length ? crops[slot] : null,
              'started_at': slot < crops.length
                  ? h.serverNow
                        .subtract(const Duration(hours: 2))
                        .toIso8601String()
                  : null,
              'ready_at': slot < crops.length
                  ? h.serverNow
                        .subtract(const Duration(minutes: 1))
                        .toIso8601String()
                  : null,
              'watered': false,
            },
        ];
      }
      if (caseName == 'pasture_repairing') {
        h.production['facilities'] = [
          for (final f in h.productionRows('facilities'))
            if (f['kind'] == 'pasture')
              {
                ...f,
                'level': 0,
                'target_level': 1,
                'ready_at': h.serverNow
                    .add(const Duration(hours: 1))
                    .toIso8601String(),
              }
            else
              {...f},
        ];
      }
      if (caseName.endsWith('_shelter_level1')) {
        final kind = caseName.split('_').first;
        h.production['facilities'] = [
          for (final f in h.productionRows('facilities'))
            {...f, if (f['kind'] == kind) 'level': 1},
        ];
        h.production['residents'] = [
          for (final r in h.productionRows('residents'))
            {
              ...r,
              if (r['kind'] == kind) ...{
                'count': kind == 'coop' ? 2 : 1,
                'animals': (r['animals'] as List)
                    .take(kind == 'coop' ? 2 : 1)
                    .toList(),
              },
            },
        ];
      }
      final expanding = caseName.contains('_upgrading');
      final project = caseName.contains('_project');
      final expansionKind = caseName.split('_').first;
      if (expanding || project) {
        final currentLevel = caseName.endsWith('_max') ? 2 : 1;
        if (project) {
          h.production['offers'] = [
            {
              'id': '$expansionKind:${currentLevel + 1}',
              'available': true,
              'reasons': <String>[],
            },
          ];
        }
        h.production['facilities'] = [
          for (final f in h.productionRows('facilities'))
            if (f['kind'] == expansionKind)
              {
                ...f,
                'level': currentLevel,
                'target_level': project ? 0 : currentLevel + 1,
                'started_at': project
                    ? null
                    : h.serverNow
                          .subtract(const Duration(hours: 1))
                          .toIso8601String(),
                'ready_at': project
                    ? null
                    : h.serverNow
                          .add(const Duration(hours: 1))
                          .toIso8601String(),
              }
            else
              {...f},
        ];
        if (expansionKind == 'garden') {
          h.production['plots'] = h
              .productionRows('plots')
              .where((p) => (p['slot'] as num) < currentLevel * 4)
              .toList();
        }
        if (expansionKind == 'coop' || expansionKind == 'pasture') {
          final count = expansionKind == 'coop' ? 2 : 1;
          h.production['residents'] = [
            for (final r in h.productionRows('residents'))
              if (r['kind'] == expansionKind)
                {
                  ...r,
                  'count': count,
                  'ready': count,
                  'fed_count': count,
                  'capacity': count * 2,
                  'animals': (r['animals'] as List).take(count).toList(),
                }
              else
                {...r},
          ];
        }
      }
      if (caseName == 'kitchen_queue' ||
          caseName == 'kitchen_waiting' ||
          caseName == 'kitchen_simultaneous') {
        // Explicit isolated examples of the three authoritative task states.
        final now = h.serverNow;
        String at(int minutes) =>
            now.add(Duration(minutes: minutes)).toIso8601String();
        h.production['tasks'] = [
          if (caseName != 'kitchen_waiting')
            {
              'id': 'gallery-ready',
              'kind': 'cook',
              'target': 'garden',
              'status': 'ready',
              'started_at': at(-20),
              'ready_at': at(-5),
            },
          {
            'id': 'gallery-cooking',
            'kind': 'cook',
            'target': 'fish',
            'status': 'running',
            'started_at': at(-5),
            'ready_at': at(10),
          },
          {
            'id': 'gallery-queued',
            'kind': 'cook',
            'target': 'chicken',
            'status': 'queued',
            'started_at': at(10),
            'ready_at': at(35),
          },
        ];
      }
      if (caseName == 'market_ready' || caseName == 'market_waiting') {
        final ready = caseName == 'market_ready';
        final now = h.serverNow;
        h.production['tasks'] = [
          {
            'id': 'gallery-market-order',
            'kind': 'order',
            'target': 'chicken',
            'status': ready ? 'ready' : 'running',
            'started_at': now
                .subtract(const Duration(minutes: 10))
                .toIso8601String(),
            'ready_at': now
                .add(Duration(minutes: ready ? -1 : 5))
                .toIso8601String(),
          },
        ];
      }
      api.biteSeconds = caseName.endsWith('fishing_waiting') ? 30 : 0;
      if (caseName == 'coop_paused_nest' || caseName == 'coop_producing_nest') {
        final paused = caseName == 'coop_paused_nest';
        h.production['residents'] = [
          for (final r in h.productionRows('residents'))
            if (r['kind'] == 'coop')
              {
                ...r,
                'ready': 0,
                'production_status': paused ? 'needs_water' : 'producing',
                if (paused) 'water_until': null,
                'next_ready_at': null,
                'production_progress': {
                  'observed_at': h.serverNow.toIso8601String(),
                  'cycle_seconds': 21600,
                  'elapsed_seconds': 7200,
                  'pause_reason': paused ? 'needs_water' : null,
                  'active_until': h.serverNow
                      .add(const Duration(hours: 8))
                      .toIso8601String(),
                  'expires_reason': 'needs_water',
                },
                'animals': [
                  for (final a in r['animals'] as List)
                    {...a as Map, 'ready': 0},
                ],
              }
            else
              {...r},
        ];
      }
      if (caseName.startsWith('pasture_milking_')) {
        h.production['residents'] = [
          for (final r in h.productionRows('residents'))
            if (r['kind'] == 'pasture')
              {
                ...r,
                'ready': 1,
                'animals': [
                  for (final a in r['animals'] as List)
                    {...a as Map, if (a['slot'] == 0) 'ready': 0},
                ],
              }
            else
              {...r},
        ];
      }
      final area = caseName.startsWith('cat_')
          ? 'pier'
          : caseName.split('_').first;
      final game = HabitatGame(h, sprites, ambientCycle: 1);
      final key = GlobalKey();
      await tester.runAsync(() async {
        await game.onLoad();
      });
      game.onGameResize(Vector2(390, 844));
      game.scaleCamera(1.35, const Offset(195, 422));
      game.focusProduction(area);
      game.reducedMotion = true;
      game.update(.1);
      final target = caseName.startsWith('cat_')
          ? QuintalSceneTarget(
              'cat',
              h.cats.first.id,
              caseName.startsWith('cat_food') ? 'food_cat' : 'water_cat',
              4,
              caseName.startsWith('cat_food') ? 4 : 5,
            )
          : game.productionTargets
                .where(
                  (t) =>
                      t.kind == area &&
                      (caseName == 'garden_empty' ||
                              caseName == 'garden_choices'
                          ? t.target == '5'
                          : caseName.endsWith('_water') ||
                                caseName.startsWith('coop_water_')
                          ? t.role == 'water'
                          : caseName.endsWith('_milk') ||
                                caseName.startsWith('pasture_milking_')
                          ? t.role == 'resident'
                          : caseName.endsWith('_nest')
                          ? t.role == 'collect'
                          : caseName == 'coop_upgrading'
                          ? t.role == 'collect'
                          : caseName == 'pasture_upgrading'
                          ? t.role == 'resident'
                          : true),
                )
                .first;
      game.selectedProduction = target;
      if (caseName.startsWith('garden_harvest_')) {
        final crop = caseName.endsWith('_reduced')
            ? 'carrot'
            : caseName.split('_').last;
        game.reducedMotion = caseName.endsWith('_reduced');
        game.selectedProduction = null;
        expect(target.role, 'plot');
        final variant = const {'carrot', 'turnip'}.contains(crop)
            ? 'harvest'
            : '3';
        expect(
          sprites.cached(
            sprites.keyFor('production:crafted-crop-$crop-$variant', 0),
          ),
          isNotNull,
        );
        game.scaleCamera(1.9, game.productionFocus(target));
        game.moveCamera(const Offset(195, 422) - game.productionFocus(target));
        h.production['plots'] = [
          for (final p in h.productionRows('plots'))
            if (p['slot'].toString() == target.target)
              {
                ...p,
                'crop': null,
                'started_at': null,
                'ready_at': null,
                'watered': false,
              }
            else
              p,
        ];
        game.showProductionAction(
          QuintalSceneTarget(
            target.kind,
            target.target,
            target.role,
            target.x,
            target.y,
            crop: crop,
          ),
          'harvest',
        );
        game.update(.45);
      }
      if (caseName == 'coop_scratch') {
        game.reducedMotion = false;
        game.selectedProduction = null;
        final instant =
            List.generate(
              quintalResidentSlotSeconds * 10,
              (i) => i / 10,
            ).firstWhere(
              (time) => quintalResidentPose(area, 0, time).clip == 'scratch',
            );
        game.update(instant);
      }
      if (caseName.contains('_shelter')) {
        game.reducedMotion = false;
        game.selectedProduction = null;
        final instant =
            List.generate(
              quintalResidentSlotSeconds * 10,
              (i) => i / 10,
            ).firstWhere((time) {
              final p = quintalResidentPose(
                area,
                0,
                time,
                level: h.facilityLevel(area),
              );
              return caseName.endsWith('_shelter')
                  ? p.elevation > 0 && p.clip == 'walk' && !p.sheltered
                  : p.sheltered && p.clip == 'idle';
            });
        game.update(instant);
      }
      if (caseName.endsWith('_gate')) {
        game.reducedMotion = false;
        game.selectedProduction = null;
        final instant = List.generate(1800, (i) => i / 10).firstWhere((time) {
          final p = quintalResidentPose(area, 0, time);
          return p.x < .8 && p.y >= 3 && p.clip == 'walk';
        });
        game.update(instant);
      }
      if (caseName.contains('_routine_')) {
        game.reducedMotion = false;
        final destinationY = caseName.endsWith('_food') ? 1.0 : 4.6;
        final instant = List.generate(1200, (i) => i / 10).firstWhere((time) {
          final p = quintalResidentPose(
            area,
            0,
            time,
            fed: true,
            watered: true,
          );
          return p.clip == 'eat' && p.y == destinationY;
        });
        game.update(instant);
      }
      if (caseName.startsWith('pasture_milking_')) {
        game.reducedMotion = false;
        game.showProductionAction(target, 'collect_residents');
        game.update(
          caseName.endsWith('_empty')
              ? .15
              : caseName.endsWith('_half')
              ? .85
              : 1.6,
        );
      }
      final toolAction = switch (caseName) {
        'coop_water_effect' || 'coop_water_reduced' => 'water_residents',
        'garden_water_effect' => 'water_crop',
        'cat_water_effect' => 'water_cat',
        'cat_food_effect' => 'serve',
        'coop_food_effect' || 'pasture_food_effect' => 'feed_residents',
        _ => null,
      };
      if (toolAction != null) {
        for (final tool in ['watering-can', 'feed-scoop', 'hay-fork']) {
          for (var stage = 0; stage < 5; stage++) {
            final key = sprites.keyFor(
              'production:crafted-tool-$tool-$stage',
              0,
            );
            expect(
              sprites.cached(key),
              isNotNull,
              reason: 'Tool pose must be bundled and preloaded: $key',
            );
          }
        }
        game.reducedMotion = caseName.endsWith('_reduced');
        game.showProductionAction(target, toolAction);
        game.update(.5);
      }
      if (caseName.endsWith('_repairing')) {
        expect(target.role, 'build', reason: 'Capture must show actual works');
      }
      if (caseName.startsWith('cat_')) {
        game.moveCamera(const Offset(195, 485) - game.productionFocus(target));
      }
      if (!caseName.startsWith('cat_')) {
        final hit = game.productionObjectAt(game.productionFocus(target));
        expect(hit?.kind, target.kind);
        expect(hit?.target, target.target);
        expect(hit?.role, target.role);
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: screenApp(
            Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _ScenePainter(game)),
                  ),
                  if (caseName != 'garden_mature' &&
                      !caseName.startsWith('garden_harvest_') &&
                      caseName != 'kitchen_simultaneous' &&
                      !caseName.endsWith('_gate') &&
                      !caseName.contains('_shelter') &&
                      caseName != 'coop_scratch')
                    QuintalObjectOverlay(
                      game: game,
                      target: target,
                      onClose: () {},
                      onFish: () => QuintalGamePage.open(
                        tester.element(find.byType(Scaffold).first),
                        habitat: h,
                        scene: game,
                      ),
                    ),
                ],
              ),
            ),
            store,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      if (project) {
        final stock = Map.of(h.productionStock);
        final targets = game.productionTargets.length;
        await tester.tap(find.text('Melhorar espaço'));
        await tester.pump();
        expect(game.constructionPreviewKind, expansionKind);
        expect(h.productionStock, stock);
        expect(game.productionTargets.length, targets);
      }
      if (expanding && !caseName.contains('_shelter')) {
        final works = game.productionTargets.singleWhere(
          (t) => t.kind == expansionKind && t.role == 'build',
        );
        final badge =
            game.productionFocus(works) -
            Offset(0, game.productionObjectHeight(works) + 54);
        expect(game.productionObjectAt(badge)?.role, 'build');

        expect(find.textContaining('Ampliando ·'), findsOneWidget);
        if (expansionKind == 'garden') {
          expect(
            game.productionTargets
                .where((t) => t.kind == 'garden' && t.role == 'plot')
                .length,
            caseName == 'garden_upgrading_max' ? 8 : 4,
          );
        }
      }
      if (caseName == 'kitchen_simultaneous') {
        final badge =
            game.productionFocus(target) -
            Offset(0, game.productionObjectHeight(target) + 54);
        for (final dx in [-24.0, 24.0]) {
          final hit = game.productionObjectAt(badge + Offset(dx, 0));
          expect(hit?.kind, 'kitchen');
          expect(hit?.role, target.role);
        }
        expect(
          h.productionRows('tasks').where((t) => t['status'] == 'ready'),
          hasLength(1),
        );
        expect(
          h.productionRows('tasks').where((t) => t['status'] == 'running'),
          hasLength(1),
        );
      }
      if (caseName == 'cat_play') {
        game.reducedMotion = false;
        unawaited(
          QuintalGamePage.open(
            tester.element(find.byType(Scaffold).first),
            habitat: h,
            scene: game,
            catId: h.cats.first.id,
            catName: h.cats.first.name,
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        for (
          var attempt = 0;
          attempt < 100 &&
              find
                  .byWidgetPredicate(
                    (w) =>
                        w is QuintalPlayArena ||
                        w.key == const ValueKey('world-play-control'),
                  )
                  .evaluate()
                  .isEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is QuintalPlayArena ||
                w.key == const ValueKey('world-play-control'),
          ),
          findsOneWidget,
        );
        expect(game.activityInProgress, isTrue);
        expect(
          tester.widget<QuintalGamePage>(find.byType(QuintalGamePage)).scene,
          same(game),
        );
        expect(game.hasWorldPlay, isTrue);
        await tester.pump(const Duration(milliseconds: 200));
      }
      if (caseName == 'market_ready') {
        expect(find.text('Seu pedido está pronto!'), findsOneWidget);
        expect(find.text('Retirar'), findsOneWidget);
      }
      if (caseName.endsWith('_choices')) {
        final action = caseName.startsWith('garden')
            ? 'Plantar'
            : caseName.startsWith('kitchen')
            ? 'Receitas'
            : caseName.startsWith('market')
            ? 'Fazer pedido'
            : 'Servir';
        await tester.tap(find.text(action));
        await tester.pump(const Duration(milliseconds: 200));
      }
      if (caseName.contains('_fruit_')) {
        final choice = find.text(
          caseName.startsWith('market') ? 'Frutas' : 'Mistura com maçã',
        );
        if (caseName.startsWith('market')) {
          await tester.tap(find.text('Frango'));
          await tester.pump();
          await tester.tap(find.text('Frutas'));
          await tester.pump();
          await tester.ensureVisible(find.text('Confirmar encomenda'));
        } else {
          // Reveal the recipe horizontally without scrolling its name under the header.
          await Scrollable.of(tester.element(choice)).position
              .ensureVisible(tester.renderObject(choice), alignment: .5);
        }
        await tester.pump();
      }
      if (caseName == 'orchard_purpose') {
        await tester.tap(find.text('Ver projeto'));
        await tester.pump();
        expect(find.textContaining('Colha maçãs e peras'), findsOneWidget);
      }
      if (caseName == 'kitchen_queue') {
        await tester.tap(find.text('Fila'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Pronto para recolher'), findsOneWidget);
        expect(find.textContaining('Preparando ·'), findsOneWidget);
        expect(find.textContaining('Na fila ·'), findsOneWidget);
      }
      if (caseName.startsWith('pier_fishing')) {
        await tester.tap(find.text('Pescar'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Pescar no píer'), findsOneWidget);
        if (caseName.endsWith('waiting')) {
          expect(find.text('Aguardando uma mordida…'), findsOneWidget);
        }
      }
      await loadVisibleArtwork();
      expect(tester.takeException(), isNull, reason: area);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$visualGalleryDirectory/quintal_world_$caseName.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      captures.add('quintal_world_$caseName');
      if (Platform.environment['GATALOGO_CAPTURE_MOTION'] == '1' &&
          (caseName == 'coop' || caseName == 'pasture_milk')) {
        final motionDirectory = Directory(
          '$visualGalleryDirectory/ancoragem/$caseName',
        );
        motionDirectory.createSync(recursive: true);
        game.reducedMotion = false;
        final initialPan = game.pan;
        final initialZoom = game.zoom;
        for (var frame = 0; frame < 64; frame++) {
          if (frame < 16) game.moveCamera(const Offset(-3, 1));
          if (frame >= 16 && frame < 32) {
            game.scaleCamera(game.zoom + .018, const Offset(195, 422));
          }
          if (frame >= 32 && frame < 48) game.moveCamera(const Offset(3, -1));
          if (frame >= 48) {
            game.scaleCamera(game.zoom - .018, const Offset(195, 422));
          }
          game.update(1 / 16);
          await tester.pump(const Duration(milliseconds: 63));
          final actionBounds = tester.getRect(
            find.byType(QuintalObjectActions),
          );
          expect(
            actionBounds.center.dx,
            closeTo(game.productionFocus(target).dx, .01),
          );
          expect(
            actionBounds.bottom,
            closeTo(
              game.productionFocus(target).dy -
                  game.productionObjectHeight(target) -
                  10,
              .01,
            ),
          );
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${motionDirectory.path}/${frame.toString().padLeft(3, '0')}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        game.pan = initialPan;
        game.zoom = initialZoom;
        game.reducedMotion = true;
      }

      if (Platform.environment['GATALOGO_CAPTURE_PLAY'] == '1' &&
          caseName == 'cat_play') {
        final directory = Directory('$visualGalleryDirectory/brincadeira');
        directory.createSync(recursive: true);
        final control = find.byKey(const ValueKey('world-play-control'));
        final rect = tester.getRect(control);
        for (var frame = 0; frame < 48; frame++) {
          if (frame == 0 || frame == 24) {
            await tester.tapAt(
              Offset(
                frame == 0 ? rect.right - 40 : rect.left + 40,
                rect.center.dy,
              ),
            );
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          game.update(.1);
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is QuintalPlayArena ||
                  w.key == const ValueKey('world-play-control'),
            ),
            findsOneWidget,
          );
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${directory.path}/${frame.toString().padLeft(3, '0')}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      if (Platform.environment['GATALOGO_CAPTURE_GATES'] == '1' &&
          caseName.endsWith('_gate')) {
        final directory = Directory('$visualGalleryDirectory/portoes/$area');
        directory.createSync(recursive: true);
        for (var frame = 0; frame < 96; frame++) {
          game.update(.3);
          game.interactionPositions.value++;
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${directory.path}/${frame.toString().padLeft(3, '0')}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      if (Platform.environment['GATALOGO_CAPTURE_TOOLS'] == '1' &&
          toolAction != null) {
        final directory = Directory(
          '$visualGalleryDirectory/ferramentas/$caseName',
        );
        directory.createSync(recursive: true);
        game.update(2);
        game.showProductionAction(target, toolAction);
        for (var frame = 0; frame < 32; frame++) {
          if (frame > 0) game.update(.05);
          game.interactionPositions.value++;
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${directory.path}/${frame.toString().padLeft(3, '0')}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      if (Platform.environment['GATALOGO_CAPTURE_HARVEST'] == '1' &&
          caseName.startsWith('garden_harvest_')) {
        final name = caseName.split('_').last;
        final directory = Directory('$visualGalleryDirectory/colheita/$name');
        directory.createSync(recursive: true);
        game.update(2);
        game.showProductionAction(
          QuintalSceneTarget(
            target.kind,
            target.target,
            target.role,
            target.x,
            target.y,
            crop: name == 'reduced' ? 'carrot' : name,
          ),
          'harvest',
        );
        for (var frame = 0; frame < 32; frame++) {
          if (frame > 0) game.update(.05);
          game.interactionPositions.value++;
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${directory.path}/${frame.toString().padLeft(3, '0')}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      if (Platform.environment['GATALOGO_CAPTURE_SHELTERS'] == '1' &&
          caseName.endsWith('_shelter')) {
        final directory = Directory('$visualGalleryDirectory/abrigos/$area');
        directory.createSync(recursive: true);
        for (var frame = 0; frame < 192; frame++) {
          game.update(.2);
          game.interactionPositions.value++;
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${directory.path}/${frame.toString().padLeft(3, '0')}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            if (frame == 60) {
              await File(
                '$visualGalleryDirectory/quintal_world_${caseName}_inside.png',
              ).writeAsBytes(bytes.buffer.asUint8List());
            }
            image.dispose();
          });
        }
      }

      if (Platform.environment['GATALOGO_CAPTURE_SHELTERS'] == '1' &&
          caseName == 'coop_scratch') {
        final directory = Directory('$visualGalleryDirectory/abrigos/scratch');
        directory.createSync(recursive: true);
        for (var frame = 0; frame < 64; frame++) {
          game.update(.1);
          game.interactionPositions.value++;
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${directory.path}/${frame.toString().padLeft(3, '0')}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      // The same live overlay must also fit narrow devices.
      tester.view.physicalSize = const Size(320, 568);
      game.onGameResize(Vector2(320, 568));
      game.focusProduction(area);
      game.interactionPositions.value++;
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$caseName at 320 × 568');
      if (game.activityInProgress) {
        await tester.tap(find.byTooltip('Voltar ao Quintal'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(game.activityInProgress, isFalse);
      }
      game.onRemove();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      tester.view.physicalSize = const Size(390, 844);
    }
    // Isolated visual fixture: the four requested coats in the real scene.
    await h.load();
    h.cats = const [
      HabitatCat(
        id: 'coat-tabby',
        name: 'Rajado',
        primaryColor: 'Cinza',
        coatType: 'Rajado',
      ),
      HabitatCat(
        id: 'coat-bicolor',
        name: 'Laranja e branco',
        primaryColor: 'Laranja',
        coatType: 'Bicolor',
        coatColors: ['Branco'],
      ),
      HabitatCat(
        id: 'coat-orange',
        name: 'Laranja',
        primaryColor: 'Laranja',
        coatType: 'Sólido',
      ),
      HabitatCat(
        id: 'coat-brown',
        name: 'Branco e marrom',
        primaryColor: 'Branco',
        coatType: 'Bicolor',
        coatColors: ['Marrom'],
      ),
    ];
    h.selectedCatIds = h.cats.map((cat) => cat.id).toList();
    final available = h.walkableCells().toList()
      ..sort((a, b) => (a.$1 + a.$2).compareTo(b.$1 + b.$2));
    final positions = <(int, int)>[];
    for (final target in [(2, 2), (4, 2), (2, 4), (4, 4)]) {
      int distance((int, int) p) =>
          (p.$1 - target.$1).abs() + (p.$2 - target.$2).abs();
      available.sort((a, b) => distance(a).compareTo(distance(b)));
      positions.add(
        available.firstWhere(
          (cell) => positions.every(
            (p) => (p.$1 - cell.$1).abs() + (p.$2 - cell.$2).abs() >= 2,
          ),
        ),
      );
    }
    expect(positions, hasLength(4));
    h.catAnchors = {for (var i = 0; i < 4; i++) h.cats[i].id: positions[i]};
    final coatGame = HabitatGame(h, sprites)..reducedMotion = true;
    await tester.runAsync(coatGame.onLoad);
    coatGame.onGameResize(Vector2(390, 844));
    coatGame.scaleCamera(1.4, const Offset(195, 422));
    final midpoint =
        positions
            .map((p) => coatGame.groundAnchor(p.$1, p.$2))
            .reduce((a, b) => a + b) /
        4;
    coatGame.moveCamera(const Offset(195, 395) - midpoint);
    coatGame.update(.1);
    final coatKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: coatKey,
        child: screenApp(
          IllustratedNavigationScaffold(
            index: 4,
            onSelect: (_) {},
            body: CustomPaint(
              painter: _ScenePainter(coatGame),
              child: const SizedBox.expand(),
            ),
          ),
          store,
        ),
      ),
    );
    await tester.pump();
    await loadVisibleArtwork();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (coatKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$visualGalleryDirectory/quintal_world_cat_coats.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    captures.add('quintal_world_cat_coats');
    coatGame.onRemove();
    await tester.pumpWidget(const SizedBox());
    // Use the actual page and its gesture handler, including the app menu.
    final pageKey = GlobalKey();
    var pageReady = false;
    final active = ValueNotifier(false);
    await h.load();
    await tester.pumpWidget(
      RepaintBoundary(
        key: pageKey,
        child: screenApp(
          IllustratedNavigationScaffold(
            index: 4,
            onSelect: (_) {},
            body: HabitatPage(
              sessionStore: account,
              catStore: store,
              active: active,
              habitatService: h,
              sprites: sprites,
              onReady: () => pageReady = true,
            ),
          ),
          store,
        ),
      ),
    );
    await tester.pump();
    final gameFinder = find.byWidgetPredicate((w) => w is GameWidget);
    final pageGame =
        (tester.widget(gameFinder) as GameWidget).game as HabitatGame;
    var loaded = false;
    Future<void>.value(pageGame.toBeLoaded()).then((_) => loaded = true);
    for (var attempt = 0; attempt < 100 && (!loaded || !pageReady); attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(loaded, true);
    expect(
      pageReady,
      true,
      reason: "Wait for synchronized scene before tapping",
    );
    pageGame.scaleCamera(
      1.35,
      Offset(pageGame.size.x / 2, pageGame.size.y / 2),
    );
    pageGame.focusProduction('coop');
    pageGame.reducedMotion = true;
    pageGame.update(.1);
    pageGame.resumeEngine();
    await tester.pump(const Duration(milliseconds: 100));
    final nest = pageGame.productionTargets.firstWhere(
      (t) => t.kind == 'coop' && t.role == 'collect',
    );
    await tester.tapAt(
      tester.getTopLeft(gameFinder) + pageGame.productionFocus(nest),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Galinheiro'), findsOneWidget);
    await loadVisibleArtwork();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (pageKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$visualGalleryDirectory/quintal_world_page.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    captures.add('quintal_world_page');
    // Capture inventory through the actual page: no separate inventory route.
    await tester.tap(find.byTooltip('Abrir ações do Quintal'));
    await tester.pump();
    await tester.tap(find.text('Inventário'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(QuintalInventoryTray), findsOneWidget);
    for (final (tab, file) in [
      ('Decorações', 'quintal_inventory'),
      ('Rações', 'quintal_inventory_rations'),
      ('Ingredientes', 'quintal_inventory_ingredients'),
    ]) {
      await tester.tap(find.text(tab));
      await tester.pump(const Duration(milliseconds: 200));
      await loadVisibleArtwork();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (pageKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$visualGalleryDirectory/$file.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      captures.add(file);
      tester.view.physicalSize = const Size(320, 568);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$tab on narrow phone');
      final tray = tester.getRect(find.byType(QuintalInventoryTray));
      expect(tray.height, lessThanOrEqualTo(320));
      expect(tray.top, greaterThan(180));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
    }
    final stockBeforeNavigation = Map.of(h.productionStock);
    for (final destination in ['Preparar mais', 'Ver pote de']) {
      if (find.byType(QuintalInventoryTray).evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Abrir ações do Quintal'));
        await tester.pump();
        await tester.tap(find.text('Inventário'));
        await tester.pump();
      }
      await tester.tap(find.text('Rações'));
      await tester.pump();
      await tester.tap(find.text('Mistura da horta'));
      await tester.pump();
      final link = find.textContaining(destination);
      await tester.scrollUntilVisible(
        link,
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(tester.element(link.first), alignment: .5);
      await tester.pump();
      await tester.tap(link.first);
      await tester.pump();
      await tester.pump();
      expect(find.byType(QuintalInventoryTray), findsNothing);
      final actions = tester.widget<QuintalObjectActions>(
        find.byType(QuintalObjectActions),
      );
      expect(
        actions.target.role,
        destination == 'Preparar mais' ? 'kitchen' : 'food_cat',
      );
      if (destination != 'Preparar mais') {
        expect(h.productionCat(actions.target.target)['food_bowl'], isNotNull);
      }
      expect(h.productionStock, stockBeforeNavigation);
    }

    await tester.tap(find.byTooltip('Abrir ações do Quintal'));
    await tester.pump();
    await tester.tap(find.text('Loja'));
    await tester.pump();
    await tester.ensureVisible(find.text('Produção'));
    await tester.tap(find.text('Produção'));
    await tester.pump();
    await tester.ensureVisible(find.text('Horta').last);
    await loadVisibleArtwork();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (pageKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$visualGalleryDirectory/quintal_shop_production.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    captures.add('quintal_shop_production');
    await tester.tap(find.text('Horta').last);
    await tester.pump();
    expect(find.byType(HabitatShopPage), findsNothing);
    expect(HabitatNavigation.focusProduction.value, 'garden');
    HabitatNavigation.focusProduction.value = null;

    await tester.pumpWidget(const SizedBox());
    active.dispose();
    final existing = Directory(visualGalleryDirectory)
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.png') && !f.path.endsWith('quintal-assets.png'),
        )
        .map((f) => f.uri.pathSegments.last.replaceAll('.png', ''))
        .toSet();
    await tester.runAsync(
      () => updateVisualGallery(
        {...existing, ...captures}
            .where(
              (name) =>
                  !name.contains('contact') &&
                  (captures.contains(name) ||
                      !name.startsWith('quintal_') ||
                      name.startsWith('quintal_world_') ||
                      name.startsWith('quintal_shop_') ||
                      name.startsWith('quintal_inventory')),
            )
            .toList()
          ..sort(),
      ),
    );
    h.dispose();
  });
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.game) : super(repaint: game.interactionPositions);
  final HabitatGame game;
  @override
  void paint(Canvas canvas, Size size) => game.render(canvas);
  @override
  bool shouldRepaint(_ScenePainter oldDelegate) => true;
}
