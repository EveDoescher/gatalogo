import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/pages/home_page.dart';
import 'package:catlogue/pages/profile_page.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/widgets/illustrated_home_components.dart';

import 'screen_corrections_test.dart' show ScreenStore, screenApp;

class ReferenceStore extends ScreenStore {
  ReferenceStore(super.session);
  @override
  Future<void> refreshGamification() async {}
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final setup in [
    (360.0, 800.0, 1.0),
    (320.0, 800.0, 1.5),
    (820.0, 1100.0, 1.0),
  ]) {
    testWidgets(
      'illustrated Home renders without overflow at ${setup.$1} text ${setup.$3}',
      (tester) async {
        tester.view.physicalSize = Size(setup.$1, setup.$2);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        GoogleFonts.config.allowRuntimeFetching = false;
        await tester.runAsync(() async {
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
        await session.updateAvatarUrl('/app/account/avatar/preset/bapinha');
        final store = ReferenceStore(session);
        // Synthetic state reproduces the composition, never production balances.
        store.progress.summary = {
          'xp': 20,
          'level': 1,
          'level_title': 'Curioso',
          'level_min_xp': 0,
          'target_xp': 100,
          'balance': 0,
          'daily_missions': [
            {
              'id': 'daily_record',
              'title': 'Registre uma nova descoberta',
              'description': 'Encontre e fotografe um gato no seu dia.',
              'progress': 0,
              'target': 1,
              'xp_reward': 50,
              'coin_reward': 50,
              'completed': false,
            },
          ],
          'challenges': [
            for (var i = 0; i < 5; i++)
              {
                'id': 'challenge_$i',
                'title': 'Conquista $i',
                'progress': i == 0 ? 1 : 0,
                'target': 5,
                'completed': false,
              },
          ],
        };
        store.sample[0] = Cat(
          id: 'discovery',
          captureNumber: 37,
          photoPath: File(
            'assets/gatalogo_asset_library/cats/cat_orange_sleeping.png',
          ).absolute.path,
          capturedAt: DateTime.now().subtract(const Duration(days: 2)),
          locationName: 'Bairro Centro',
          status: 'completed',
        );
        await tester.pumpWidget(screenApp(const SizedBox(), store));
        final warmContext = tester.element(find.byType(SizedBox).first);
        await tester.runAsync(() async {
          for (final asset in [
            ...HomeArt.artwork.values,
            'backgrounds/background_garden_frame',
          ]) {
            await precacheImage(
              AssetImage('assets/gatalogo_asset_library/$asset.png'),
              warmContext,
            );
          }
          await precacheImage(
            const AssetImage(
              'assets/gatalogo_asset_library/branding/brand_gatalogo_logo.png',
            ),
            warmContext,
          );
          await precacheImage(
            FileImage(File(store.sample.first.photoPath)),
            warmContext,
          );
          await GoogleFonts.pendingFonts([
            GoogleFonts.fredoka(fontWeight: FontWeight.w600),
            GoogleFonts.nunito(fontWeight: FontWeight.w900),
            GoogleFonts.nunito(fontWeight: FontWeight.w800),
            GoogleFonts.nunito(fontWeight: FontWeight.w700),
            GoogleFonts.nunito(fontWeight: FontWeight.w400),
          ]);
        });
        var selected = -1;
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: screenApp(
              Scaffold(
                extendBody: true,
                body: HomePage(
                  sessionStore: session,
                  catStore: store,
                  onNavigate: (index) => selected = index,
                ),
                bottomNavigationBar: IllustratedNavigationBar(
                  index: 0,
                  onSelect: (index) => selected = index,
                ),
              ),
              store,
              scale: setup.$3,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Jornada de hoje'), findsOneWidget);
        expect(find.text('Suas conquistas'), findsOneWidget);
        if (setup.$3 == 1) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(
              pixelRatio: setup.$1 == 360 ? 2 : 1,
            );
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/home-reference').create(recursive: true);
            await File('build/home-reference/home-${setup.$1.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('Habitat').last);
        expect(selected, 4);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
        session.dispose();
      },
    );
  }

  testWidgets(
    'Home reflects account values and never invents missing progress',
    (tester) async {
      final session = SessionStore();
      final store = ReferenceStore(session);
      await tester.pumpWidget(
        screenApp(
          HomePage(sessionStore: session, catStore: store, onNavigate: (_) {}),
          store,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Missões indisponíveis'), findsOneWidget);
      expect(find.text('XP indisponível'), findsOneWidget);
      expect(find.text('0 / 1'), findsNothing);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      store.progress.summary = {
        'xp': 842,
        'level': 4,
        'level_title': 'Catalogador',
        'level_min_xp': 650,
        'target_xp': 1200,
        'balance': 237,
        'daily_missions': [
          {
            'id': 'from_server',
            'title': 'Missão real da conta',
            'description': 'Descrição recebida da API',
            'progress': 2,
            'target': 3,
            'xp_reward': 17,
            'coin_reward': 6,
            'completed': false,
          },
        ],
        'weekly_missions': [
          {'id': 'weekly_record', 'title': 'Missão semanal'},
        ],
        'challenges': [
          {
            'id': 'first',
            'title': 'Primeira descoberta',
            'progress': 1,
            'target': 1,
            'completed': true,
          },
        ],
      };
      store.notifyListeners();
      await tester.pumpAndSettle();
      for (final value in [
        '842 / 1200 XP',
        'Catalogador',
        '237',
        'Missão real da conta',
        '2 / 3',
        '+17 XP',
        '+6',
        '1 / 1',
      ]) {
        expect(find.text(value), findsOneWidget);
      }
      expect(find.text('Missão semanal'), findsNothing);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      store.progress.summary['balance'] = 91;
      store.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('91'), findsOneWidget);
      expect(find.text('237'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      session.dispose();
    },
  );

  testWidgets('guest can select either character and persist the choice', (
    tester,
  ) async {
    final session = SessionStore();
    final store = ReferenceStore(session);
    await tester.pumpWidget(
      screenApp(ProfilePage(sessionStore: session, catStore: store), store),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.camera).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bapinha'));
    await tester.pumpAndSettle();
    expect(session.avatarUrl, '/app/account/avatar/preset/bapinha');
    expect(
      await const FlutterSecureStorage().read(key: 'auth_avatar_url'),
      session.avatarUrl,
    );
    await tester.tap(find.byIcon(LucideIcons.camera).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bapinho'));
    await tester.pumpAndSettle();
    expect(session.avatarUrl, '/app/account/avatar/preset/bapinho');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    session.dispose();
  });
}
