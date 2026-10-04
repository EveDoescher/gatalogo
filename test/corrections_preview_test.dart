import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catlogue/app.dart';
import 'package:catlogue/pages/auth_page.dart';
import 'package:catlogue/pages/cat_details_page.dart';
import 'package:catlogue/pages/capture_page.dart';
import 'package:catlogue/pages/home_page.dart';
import 'package:catlogue/pages/journey_page.dart';
import 'package:catlogue/pages/library_page.dart';
import 'package:catlogue/pages/missing_cats_page.dart';
import 'package:catlogue/pages/missing_cat_poster_page.dart';
import 'package:catlogue/pages/my_cats_page.dart';
import 'package:catlogue/pages/profile_page.dart';
import 'package:catlogue/pages/settings_page.dart';
import 'package:catlogue/pages/social_page.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/widgets/post_composer.dart';

import 'screen_corrections_test.dart'
    show ScreenStore, sampleReport, screenApp, FeedFixture;
import 'gamification_service_test.dart' show Account;

void main() {
  testWidgets('render corrected screens with bundled fonts for visual review', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(() async {
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final lucide = FontLoader('packages/lucide_icons_flutter/Lucide');
      lucide.addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
      await lucide.load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = SessionStore();
    final store = ScreenStore(session);
    final signedSession = Account();
    final screens = <String, Widget>{
      'login': AuthPage(sessionStore: session, onContinueOffline: () {}),
      'home': Scaffold(
        body: HomePage(
          sessionStore: session,
          catStore: store,
          onNavigate: (_) {},
        ),
      ),
      'navigation': MainNavigation(sessionStore: session, catStore: store),
      'capture': CapturePage(catStore: store),
      'collection': Scaffold(body: LibraryPage(catStore: store)),
      'cat_detail': CatDetailsPage(cat: store.cats.first, catStore: store),
      'my_cats': MyCatsPage(store: store),
      'pet': PetProfilePage(catId: 'pet', store: store),
      'profile': ProfilePage(sessionStore: session, catStore: store),
      'achievements': JourneyPage(store: store),
      'social': SocialPage(
        sessionStore: signedSession,
        catStore: store,
        api: FeedFixture(signedSession),
      ),
      'composer': Scaffold(
        body: PostComposer(session: session, cats: store.cats),
      ),
      'quick_alert': CreateMissingReportPage(store: store, quickMode: true),
      'registered_alert': CreateMissingReportPage(
        store: store,
        initialCat: store.pets.first,
      ),
      'active_alert': MissingReportDetailPage(
        store: store,
        report: sampleReport,
      ),
      'poster': MissingCatPosterPage(
        catStore: store,
        cat: store.pets.first,
        report: sampleReport,
      ),
      'settings': SettingsPage(sessionStore: session, catStore: store),
    };
    for (final entry in screens.entries) {
      await tester.pumpWidget(screenApp(entry.value, store));
      await tester.runAsync(() async {
        final assets = await AssetManifest.loadFromAssetBundle(rootBundle);
        final context = tester.element(find.byType(MaterialApp));
        await Future.wait([
          for (final asset in assets.listAssets().where((path) =>
              path.startsWith('assets/gatalogo_asset_library/') && path.endsWith('.png')))
            precacheImage(AssetImage(asset), context),
        ]);
      });
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.key);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/corrections/${entry.key}.png'),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
    store.dispose();
    session.dispose();
    signedSession.dispose();
  }, skip: Platform.environment['GATALOGO_PREVIEWS'] != '1');
}
