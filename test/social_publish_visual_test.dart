import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catlogue/pages/social_page.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/widgets/illustrated_home_components.dart';
import 'package:catlogue/widgets/post_composer.dart';

import 'screen_corrections_test.dart';
import 'gamification_service_test.dart' show Account;
import 'support/visual_gallery.dart';

void main() {
  testWidgets(
    'publish stays above navigation in both feeds and respects login',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        for (final (family, path) in [
          ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
          (
            'packages/lucide_icons_flutter/Lucide',
            'packages/lucide_icons_flutter/assets/lucide.ttf',
          ),
        ]) {
          final font = FontLoader(family)..addFont(rootBundle.load(path));
          await font.load();
        }
      });
      final session = Account();
      final store = ScreenStore(session);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: screenApp(
            IllustratedNavigationScaffold(
              index: 1,
              onSelect: (_) {},
              body: SocialPage(
                sessionStore: session,
                catStore: store,
                api: FeedFixture(session),
              ),
            ),
            store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SocialPage));
      await tester.runAsync(() async {
        for (final image in tester.widgetList<Image>(find.byType(Image))) {
          if (image.image is! NetworkImage) {
            await precacheImage(image.image, context);
          }
        }
      });
      await tester.pump();
      final button = tester.getRect(find.byType(FloatingActionButton));
      final menu = tester.getRect(find.byType(IllustratedNavigationBar));
      expect(button.bottom, lessThanOrEqualTo(menu.top));
      expect(button.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$visualGalleryDirectory/social_publish.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
        final html = File('$visualGalleryDirectory/galeria.html')
            .readAsStringSync();
        final names = RegExp(r'src="([^"/]+)\.png')
            .allMatches(html)
            .map((m) => m[1]!)
            .toSet();
        await updateVisualGallery({...names, 'social_publish'});
      });
      await tester.tap(find.text('Amigos').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Criar publicação'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 568);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Criar publicação'));
      await tester.pumpAndSettle();
      expect(find.byType(PostComposer), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      final guest = SessionStore();
      await tester.pumpWidget(
        screenApp(SocialPage(sessionStore: guest), store),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      session.dispose();
      guest.dispose();
    },
  );
}
