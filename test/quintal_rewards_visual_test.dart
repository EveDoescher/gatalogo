import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catlogue/game/habitat_game.dart';
import 'package:catlogue/game/habitat_sprites.dart';
import 'package:catlogue/pages/habitat_page.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/services/product_api_service.dart';
import 'package:catlogue/widgets/habitat_care_sheet.dart';
import 'package:catlogue/widgets/illustrated_home_components.dart';

import 'visual_validation_capture_test.dart'
    show ValidationAccount, ValidationStore, ValidationDatabase;
import 'screen_corrections_test.dart' show screenApp;
import 'quintal_rewards_widgets_test.dart'
    show bondRewards, progressReceipt, bondReceipt;
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
  ]) async {
    if (path == '/app/habitat/encounters') {
      return Map<String, dynamic>.from(fixture['habitat']);
    }
    if (body?['action'] != 'ack_rewards') {
      throw StateError('Unexpected visual operation: $path');
    }
    fixture['progress'] = <String, dynamic>{};
    return {
      ...fixture,
      'outcome': {'acknowledged': 1},
    };
  }
}

void main() {
  testWidgets(
    'reward receipts and bond prizes fit the real scene and inventory',
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
      fixture['production']['updates'] = [];
      fixture['production']['catalog']['bond_rewards'] = bondRewards;
      fixture['habitat']['pending_gift'] = null;
      fixture['habitat']['items'].add({
        'id': 'reward-flowers',
        'sku': 'yellow_flowers',
        'rotation': 0,
        'care_state': {},
      });
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
      await tester.runAsync(() async {
        await sprites.initialize();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
          ..addFont(
            rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
          );
        await lucide.load();
        GoogleFonts.nunito(fontWeight: FontWeight.w800);
        GoogleFonts.nunito(fontWeight: FontWeight.w900);
        await GoogleFonts.pendingFonts();
        final warm = HabitatGame(h, sprites);
        await warm.onLoad();
        warm.onRemove();
      });
      final captures = <String>[];
      Future<void> capture(GlobalKey key, String name) async {
        await tester.runAsync(() async {
          await GoogleFonts.pendingFonts();
          await Future<void>.delayed(const Duration(milliseconds: 120));
        });
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: name);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$visualGalleryDirectory/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        captures.add(name);
      }

      for (final width in [390.0, 320.0]) {
        tester.view.physicalSize = Size(width, 844);
        for (final kind in ['progress', 'bond']) {
          final receipt = kind == 'progress'
              ? progressReceipt
              : {...bondReceipt, 'cat_id': h.cats.first.id};
          fixture['progress'] = {
            'celebrations': [receipt],
          };
          final key = GlobalKey(), active = ValueNotifier(true);
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
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
                  ),
                ),
                store,
                scale: width == 320 ? 1.5 : 1,
              ),
            ),
          );
          await tester.pump();
          final game =
              (tester.widget(
                    find.byWidgetPredicate((w) => w is GameWidget),
                  ) as GameWidget).game
                  as HabitatGame;
          var loaded = false;
          Future<void>.value(game.toBeLoaded()).then((_) => loaded = true);
          for (var attempt = 0; attempt < 100 && !loaded; attempt++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(milliseconds: 50));
          }
          expect(loaded, true);
          game.focusProduction(kind == 'progress' ? 'garden' : 'coop');
          game.reducedMotion = true;
          await tester.pump(const Duration(seconds: 2));
          expect(find.text(receipt['title'] as String), findsOneWidget);
          await capture(key, 'quintal_reward_${kind}_${width.toInt()}');
          if (kind == 'bond') {
            await tester.ensureVisible(find.text('Ver no inventário'));
            await tester.tap(find.text('Ver no inventário'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(h.pendingProductionRewards, isEmpty);
            expect(find.text('Decorações'), findsOneWidget);
            expect(find.text('Flores amarelas'), findsWidgets);
            await capture(key, 'quintal_reward_inventory_${width.toInt()}');
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          active.dispose();
        }
        fixture['progress'] = <String, dynamic>{};
        for (final affinity in [20, 50, 100, 200]) {
          h.production['cats'][0]['affinity'] = affinity;
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: screenApp(
                Scaffold(
                  body: HabitatCareSheet(
                    habitat: h,
                    cat: h.cats.first,
                    sprites: sprites,
                    preference: 'brincadeira',
                    onAction: (_) {},
                    onInventory: () {},
                  ),
                ),
                store,
                scale: width == 320 ? 1.5 : 1,
              ),
            ),
          );
          await capture(key, 'quintal_bond_${affinity}_${width.toInt()}');
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        }
      }
      await tester.runAsync(() => updateVisualGallery(captures));
      sprites.catAnimations.dispose();
      h.dispose();
      store.dispose();
      account.dispose();
    },
  );
}
