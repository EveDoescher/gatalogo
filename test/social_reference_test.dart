import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catlogue/pages/social_page.dart';
import 'package:catlogue/services/social_api_service.dart';
import 'package:catlogue/widgets/illustrated_home_components.dart';
import 'package:catlogue/widgets/community_post_card.dart';

import 'screen_corrections_test.dart' show ScreenStore, screenApp;
import 'gamification_service_test.dart' show Account;

class CommunityFixture extends SocialApiService {
  CommunityFixture(super.session, this.photo, {this.textOnlyFirst = false});
  final bool textOnlyFirst;
  final String photo;
  final modes = <String>[];
  int liked = 0;
  @override
  Future<List<Map<String, dynamic>>> conversations() async => [];
  @override
  Future<List<Map<String, dynamic>>> feed({
    int limit = 20,
    String? cursor,
    String mode = 'all',
  }) async {
    modes.add(mode);
    return [
      for (var i = 0; i < 2; i++)
        {
          'id': 'fixture-$i',
          'username': 'ana',
          'type': 'cat_post',
          'created_at': DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String(),
          'payload': <String, dynamic>{
            'note': 'Um encontro tranquilo no fim da tarde.',
            'location_name': 'Bairro Centro',
            'author_avatar_url': '/app/account/avatar/preset/bapinha',
            if (!textOnlyFirst || i != 0) 'photo_base64': photo,
            'likes_count': 23,
            'comments_count': 4,
            'comments': [],
          },
        },
    ];
  }

  @override
  Future<Map<String, dynamic>> toggleLike(String id) async {
    liked++;
    return {'liked': true, 'likes_count': 24};
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final view in [
    (360.0, 800.0, 1.0),
    (320.0, 800.0, 1.5),
    (820.0, 1100.0, 1.0),
  ]) {
    testWidgets(
      'Social composition and real API bindings at ${view.$1}/${view.$3}',
      (tester) async {
        tester.view.physicalSize = Size(view.$1, view.$2);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        GoogleFonts.config.allowRuntimeFetching = false;
        final session = Account();
        final store = ScreenStore(session);
        store.progress.summary = {'balance': 47};
        // Fixtures are isolated to tests; production feed and wallet use the API.
        final photo = base64Encode(
          File('assets/gatalogo_asset_library/cats/cat_orange_sleeping.png')
              .readAsBytesSync(),
        );
        final api = CommunityFixture(session, photo);
        await tester.pumpWidget(screenApp(const SizedBox(), store));
        final context = tester.element(find.byType(SizedBox).first);
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
          for (final path in [
            ...HomeArt.artwork.values,
            'backgrounds/background_garden_frame',
            'branding/brand_gatalogo_logo',
            'cats/cat_calico_peeking',
            'ui/ui_speech_heart',
            'flora/flora_leaves_pair_outline',
            'flora/flora_leaf_cluster_flat_dark_01',
          ]) {
            await precacheImage(
              AssetImage('assets/gatalogo_asset_library/$path.png'),
              context,
            );
          }
          await precacheImage(MemoryImage(base64Decode(photo)), context);
          await GoogleFonts.pendingFonts([
            GoogleFonts.fredoka(fontWeight: FontWeight.w600),
            for (final weight in [
              FontWeight.w400,
              FontWeight.w500,
              FontWeight.w600,
              FontWeight.w700,
              FontWeight.w800,
              FontWeight.w900,
            ])
              GoogleFonts.nunito(fontWeight: weight),
          ]);
        });
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: screenApp(
              Scaffold(
                extendBody: true,
                body: SocialPage(
                  sessionStore: session,
                  catStore: store,
                  api: api,
                  onNavigate: (_) {},
                ),
                bottomNavigationBar: IllustratedNavigationBar(
                  index: 1,
                  onSelect: (_) {},
                ),
              ),
              store,
              scale: view.$3,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final providers = tester
            .widgetList<Image>(find.byType(Image))
            .map((image) => image.image)
            .toList();
        await tester.runAsync(() async {
          for (final provider in providers) {
            await precacheImage(provider, key.currentContext!);
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('47'), findsOneWidget);
        expect(find.byType(CommunityPostCard), findsWidgets);
        if (view.$3 == 1) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: view.$1 == 360 ? 2 : 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/art-direction').create(recursive: true);
            await File('build/art-direction/social-${view.$1.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('Amigos').first);
        await tester.pumpAndSettle();
        expect(api.modes.last, 'friends');
        await tester.tap(find.text('Cartazes').first);
        await tester.pumpAndSettle();
        expect(api.modes.last, 'friends:poster_repost');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
        session.dispose();
      },
    );
  }
}
