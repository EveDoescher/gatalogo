import 'package:catlogue/pages/auth_page.dart';
import 'package:catlogue/pages/friends_page.dart';
import 'package:catlogue/pages/result_history_page.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:catlogue/pages/home_page.dart';
import 'package:catlogue/pages/discovery_result_page.dart';
import 'package:catlogue/pages/library_page.dart';
import 'package:catlogue/pages/journey_page.dart';
import 'package:catlogue/pages/capture_page.dart';
import 'package:catlogue/pages/profile_page.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/widgets/game_components.dart';

import 'screen_corrections_test.dart' show ScreenStore, screenApp;

class JournalStore extends ScreenStore {
  JournalStore(super.session);
  @override
  Future<void> refreshGamification() async {}
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('individual identity, notes and favorites survive edits', () {
    final cat = Cat(
      id: 'one',
      individualId: 'known',
      captureNumber: 1,
      photoPath: 'photo.jpg',
      capturedAt: DateTime(2026),
      notes: 'Pata branca',
      isFavorite: true,
    );
    final edited = cat
        .withStatus('completed')
        .withLocation(latitude: 0, longitude: 0)
        .withName('Lua');
    final restored = Cat.fromMap(edited.toMap());
    expect(restored.individualId, 'known');
    expect(restored.notes, 'Pata branca');
    expect(restored.isFavorite, isTrue);
  });
  test('the album groups complementary photos without deleting records', () {
    final session = SessionStore();
    final store = JournalStore(session);
    store.sample.add(
      Cat(
        id: 'second',
        individualId: 'discovery',
        captureNumber: 3,
        photoPath: 'photo.jpg',
        capturedAt: DateTime(2026),
      ),
    );
    expect(store.individuals.length, 1);
    expect(store.photosOf(store.individuals.first).length, 2);
    expect(store.cats.length, 3);
    store.dispose();
    session.dispose();
  });
  for (final width in [320.0, 390.0, 820.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'journal screens and pending result fit width $width at $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, width < 600 ? 760 : 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.runAsync(() async {
            for (final sprite in [
              'tree_default_NE',
              'building-type-a',
              'animal-cat',
              'flower_redA_NE',
              'flower_yellowA_NE',
              'grass_NE',
            ]) {
              await GameSprite.sprites.ready(sprite);
            }
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
            await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
                  rootBundle.load(
                    'packages/lucide_icons_flutter/assets/lucide.ttf',
                  ),
                ))
                .load();
          });
          final session = SessionStore();
          final store = JournalStore(session);
          store.sample[0] = store.sample[0].withSync(
            photoPath: File(
              'assets/gatalogo_asset_library/cats/cat_orange_camera.png',
            ).absolute.path,
          );
          store.progress.summary = {
            'xp': 130,
            'level': 2,
            'level_title': 'Explorador',
            'level_min_xp': 100,
            'target_xp': 300,
            'balance': 55,
            'next_habitat_goal': {
              'title': 'Grama macia',
              'price': 20,
              'sku': 'soft_grass',
            },
            'daily_missions': [
              {
                'id': 'daily_record',
                'title': 'Guarde uma nova história',
                'progress': 1,
                'target': 1,
                'completed': true,
              },
            ],
            'challenges': [
              {
                'id': 'collector_5',
                'title': 'Olhar curioso',
                'description': 'Conheça cinco indivíduos diferentes.',
                'progress': 2,
                'target': 5,
                'next_piece': 3,
                'xp_reward': 50,
                'coin_reward': 15,
              },
              {
                'id': 'colors_3',
                'title': 'Paleta felina',
                'description': 'Confirme três cores diferentes.',
                'progress': 1,
                'target': 3,
                'xp_reward': 40,
                'coin_reward': 15,
              },
              {
                'id': 'days_3',
                'title': 'Dias de descobertas',
                'description': 'Registre em três dias diferentes, sem precisar ser seguidos.',
                'progress': 2,
                'target': 3,
                'xp_reward': 30,
                'coin_reward': 10,
              },
            ],
          };
          await tester.pumpWidget(screenApp(const SizedBox(), store));
          final warmContext = tester.element(find.byType(SizedBox).first);
          await tester.runAsync(() async {
            await precacheImage(
              FileImage(File(store.sample.first.photoPath)),
              warmContext,
            );
            for (final asset in [
              'assets/gatalogo_asset_library/branding/brand_gatalogo_logo.png',
              'assets/gatalogo_asset_library/cats/cat_orange_sleeping.png',
              'assets/gatalogo_asset_library/cats/cat_orange_crouching.png',
              'assets/3d_assets/kenney_mini-dungeon/Previews/coin.png',
            ]) {
              await precacheImage(AssetImage(asset), warmContext);
            }
            await GoogleFonts.pendingFonts([
              GoogleFonts.fredoka(fontWeight: FontWeight.w600),
              GoogleFonts.nunito(fontWeight: FontWeight.w900),
            ]);
          });
          final pages = <Widget>[
            HomePage(
              sessionStore: session,
              catStore: store,
              onNavigate: (_) {},
            ),
            LibraryPage(catStore: store, initialTab: 1),
            CapturePage(catStore: store),
            ProfilePage(sessionStore: session, catStore: store),
            JourneyPage(store: store),
            FriendsPage(sessionStore: session),
            AuthPage(sessionStore: session, onContinueOffline: () {}),
            ResultHistoryPage(store: store),
            DiscoveryResultPage(store: store, catId: 'discovery'),
          ];
          for (final page in pages) {
            if (page is ResultHistoryPage) {
              store.progress.results = [
                {
                  'event_id': 'history-discovery',
                  'state': 'confirmed',
                  'record_type': 'discovery',
                },
                {
                  'event_id': 'history-clue',
                  'state': 'pending',
                  'record_type': 'clue',
                },
              ];
            }
            final pageKey = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: pageKey,
                child: screenApp(page, store, scale: scale),
              ),
            );
            await tester.pumpAndSettle();
            if (scale == 1.0) {
              final providers = tester
                  .widgetList<Image>(find.byType(Image))
                  .map((image) => image.image)
                  .toList();
              await tester.runAsync(() async {
                for (final provider in providers) {
                  await precacheImage(provider, pageKey.currentContext!);
                }
              });
              await tester.pumpAndSettle();
              await capture(
                tester,
                pageKey,
                '${page.runtimeType}-${width.toInt()}',
              );
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '${page.runtimeType}',
            );
            await tester.pumpWidget(const SizedBox());
          }
          store.progress.results = [
            {
              'event_id': 'result',
              'record_id': 'discovery',
              'state': 'needs_review',
              'record_type': 'discovery',
              'credits': {'xp': 50, 'coins': 25},
              'attributes': {'primary_color': 'Preto'},
              'summary': {
                'xp': 130,
                'level': 2,
                'level_title': 'Explorador',
                'level_min_xp': 100,
                'target_xp': 300,
                'balance': 55,
              },
              'unlocked_items': [
                {
                  'level': 2,
                  'name': 'Flores amarelas',
                  'sku': 'yellow_flowers',
                },
              ],
            },
          ];
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: screenApp(
                DiscoveryResultPage(store: store, catId: 'discovery'),
                store,
                scale: scale,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => precacheImage(
              FileImage(File(store.sample.first.photoPath)),
              key.currentContext!,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Precisa de revisão'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (scale == 1.0) {
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('build/restructure').create(recursive: true);
              await File('build/restructure/result-${width.toInt()}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
          store.dispose();
          session.dispose();
        },
      );
    }
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/restructure').create(recursive: true);
    await File('build/restructure/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
