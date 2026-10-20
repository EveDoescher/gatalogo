import 'package:catlogue/widgets/app_loading_screen.dart';
import 'package:catlogue/widgets/milestone_widgets.dart';
import 'package:catlogue/game/habitat_game.dart';
import 'package:flame/game.dart';
import 'package:catlogue/services/habitat_navigation.dart';
import 'package:catlogue/widgets/habitat_reward_reveal.dart';
import 'package:latlong2/latlong.dart';

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:catlogue/pages/friends_page.dart';
import 'package:catlogue/pages/result_history_page.dart';
import 'package:catlogue/pages/discovery_result_page.dart';
import 'package:catlogue/pages/notifications_page.dart';
import 'package:catlogue/pages/experience_settings_page.dart';
import 'package:catlogue/pages/inbox_page.dart';
import 'package:catlogue/pages/conversation_page.dart';
import 'package:catlogue/pages/public_profile_page.dart';
import 'package:catlogue/pages/cat_gallery_page.dart';
import 'package:catlogue/pages/location_page.dart';
import 'package:catlogue/pages/missing_map_consolidated_page.dart';
import 'package:catlogue/pages/community_posters_page.dart';
import 'package:catlogue/pages/habitat_page.dart';
import 'package:catlogue/pages/habitat_shop_page.dart';
import 'package:catlogue/pages/habitat_help_page.dart';
import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/game/habitat_sprites.dart';
import 'package:catlogue/widgets/illustrated_home_components.dart';

import 'social_reference_test.dart' show CommunityFixture;

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

import 'screen_corrections_test.dart' show ScreenStore, sampleReport, screenApp;
import 'gamification_service_test.dart' show Account;
import 'support/visual_gallery.dart';
import 'support/fixture_image_client.dart';

class ValidationAccount extends Account {
  ValidationAccount() {
    _ready = true;
  }
  bool _ready = false;
  @override
  bool get isSignedIn => _ready;
  @override
  Future<String?> accessToken({bool refresh = false}) async => 'test';
}

class ValidationStore extends ScreenStore {
  ValidationStore(super.session);
  @override
  Future<void> refreshGamification() async {}
  @override
  Future<void> syncCatalog({bool manual = false}) async {}
}

class ValidationDatabase implements CatDatabase {
  @override
  Future<Map<String, dynamic>?> readHabitatCache(String ownerId) async => null;
  @override
  Future<void> saveHabitatSnapshot(
    String ownerId,
    Map<String, dynamic> value,
  ) async {}
  @override
  Future<void> saveHabitatDraft(
    String ownerId,
    Map<String, dynamic>? value,
  ) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('fresh captures of every changed screen for user validation', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    // No native audio plugin is available in renderer-only widget captures.
    for (final name in [
      'xyz.luan/audioplayers.global/events',
      'xyz.luan/audioplayers.global',
    ]) {
      final channel = MethodChannel(name);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
    }
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          paths,
          (call) async => Directory('build/validation-cache').absolute.path,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(paths, null),
    );
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
    final signedSession = ValidationAccount();
    final store = ValidationStore(signedSession);
    for (var i = 0; i < store.sample.length; i++) {
      store.sample[i] = store.sample[i].withSync(
        photoPath: File(
          'assets/gatalogo_asset_library/cats/cat_orange_sleeping.png',
        ).absolute.path,
      );
    }
    final milestoneFixture = jsonDecode(
      File('test/fixtures/milestones_v2.json').readAsStringSync(),
    ) as Map;
    store.progress.summary = Map<String, dynamic>.from(
      milestoneFixture['basic'] as Map,
    );
    store.progress.results = [
      {
        'event_id': 'event',
        'record_id': 'discovery',
        'state': 'confirmed',
        'record_type': 'discovery',
        'credits': {'xp': 50, 'coins': 25},
        'attributes': {'primary_color': 'Laranja'},
        'summary': store.progress.summary,
      },
    ];
    final sprites = HabitatSprites();
    final habitat = HabitatService(
      session,
      store,
      database: ValidationDatabase(),
    );
    final active = ValueNotifier<bool>(true);
    await tester.runAsync(() async {
      await sprites.initialize();
      final warmGame = HabitatGame(habitat, sprites);
      await warmGame.onLoad();
      warmGame.onRemove();
    });
    final photoBytes = await tester.runAsync(
      () => File(store.sample.first.photoPath).readAsBytes(),
    );
    final photo = base64Encode(photoBytes!);
    final previousImageClient = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = () => FixtureImageClient(photoBytes);
    addTearDown(
      () => debugNetworkImageHttpClientProvider = previousImageClient,
    );
    await tester.pumpWidget(screenApp(const SizedBox(), store));
    final warmContext = tester.element(find.byType(MaterialApp));
    await tester.runAsync(() async {
      for (final cat in store.sample) {
        await precacheImage(FileImage(File(cat.photoPath)), warmContext);
      }
    });
    final screens = <String, Widget>{
      'login': AuthPage(sessionStore: session, onContinueOffline: () {}),
      'home': IllustratedNavigationScaffold(
        index: 0,
        onSelect: (_) {},
        body: HomePage(
          sessionStore: session,
          catStore: store,
          onNavigate: (_) {},
        ),
      ),
      'navigation': MainNavigation(sessionStore: session, catStore: store),
      'capture': IllustratedNavigationScaffold(
        index: 2,
        onSelect: (_) {},
        body: CapturePage(catStore: store),
      ),
      'collection': IllustratedNavigationScaffold(
        index: 3,
        onSelect: (_) {},
        body: LibraryPage(catStore: store),
      ),
      'challenges': IllustratedNavigationScaffold(
        index: 3,
        onSelect: (_) {},
        body: LibraryPage(catStore: store, initialTab: 1),
      ),
      'cat_detail': CatDetailsPage(cat: store.cats.first, catStore: store),
      'my_cats': MyCatsPage(store: store),
      'pet': PetProfilePage(catId: 'pet', store: store),
      'profile': ProfilePage(sessionStore: session, catStore: store),
      'achievements': JourneyPage(store: store),
      'social': IllustratedNavigationScaffold(
        index: 1,
        onSelect: (_) {},
        body: SocialPage(
          sessionStore: signedSession,
          catStore: store,
          api: CommunityFixture(signedSession, photo),
        ),
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
      'friends': FriendsPage(sessionStore: session),
      'friends_discover': FriendsPage(sessionStore: session),
      'friends_invites': FriendsPage(sessionStore: session),
      'friends_ranking': FriendsPage(sessionStore: session),
      'history': ResultHistoryPage(store: store),
      'result': DiscoveryResultPage(store: store, catId: 'discovery'),
      'add_pet': AddPetPage(store: store),
      'add_pet_details': AddPetPage(store: store),
      'cat_gallery': CatGalleryPage(cat: store.pets.first, store: store),
      'cat_gallery_angles': CatGalleryPage(cat: store.pets.first, store: store),
      'notifications': NotificationsPage(store: store),
      'experience': ExperienceSettingsPage(session: session),
      'inbox': InboxPage(sessionStore: session),
      'chat': ConversationPage(
        sessionStore: signedSession,
        conversationId: 'chat',
        catStore: store,
        initialUsername: 'ana',
      ),
      'public_profile': PublicProfilePage(
        sessionStore: signedSession,
        username: 'ana',
      ),
      'community_posters': CommunityPostersPage(session: signedSession),
      'community_case': CommunityCasePage(
        session: signedSession,
        reportId: 'report',
      ),
      'missing_cats': MissingCatsPage(catStore: store, sessionStore: session),
      'clues': CluesPage(report: sampleReport, store: store),
      'clue_detail': ClueDetailPage(
        clue: {
          'id': 'clue',
          'photo_url': '/app/clues/photo/clue',
          'status': 'pending',
          'created_at': '2026-10-04T10:00:00Z',
          'distance_meters': 350,
        },
        report: sampleReport,
        store: store,
      ),
      'contribution': ContributionPage(store: store, matchId: 'clue'),
      'map': LocationPage(
        catStore: store,
        readOnly: true,
        initial: const LatLng(-23.5, -46.6),
      ),
      'missing_map': MissingMapConsolidatedPage(
        report: sampleReport,
        store: store,
        cat: store.pets.first,
        clues: const [],
      ),
      'habitat': IllustratedNavigationScaffold(
        index: 4,
        onSelect: (_) {},
        body: HabitatPage(
          sessionStore: session,
          catStore: store,
          active: active,
          habitatService: habitat,
          sprites: sprites,
        ),
      ),
      'shop': IllustratedNavigationScaffold(
        index: 4,
        onSelect: (_) {},
        body: HabitatShopPage(
          habitat: habitat,
          sprites: sprites,
          onClose: () {},
        ),
      ),
      'habitat_help': IllustratedNavigationScaffold(
        index: 4,
        onSelect: (_) {},
        body: HabitatHelpPage(habitat: habitat, onClose: () {}),
      ),
      'inbox_filled': InboxPage(sessionStore: signedSession),
      'notifications_filled': NotificationsPage(store: store),
      'missing_cats_filled': MissingCatsPage(
        catStore: store,
        sessionStore: signedSession,
      ),
      'community_posters_filled': CommunityPostersPage(session: signedSession),
      'community_case_filled': CommunityCasePage(
        session: signedSession,
        reportId: 'report',
      ),
      'clues_filled': CluesPage(report: sampleReport, store: store),
      'contribution_confirmed': ContributionPage(
        store: store,
        matchId: 'confirmed',
      ),
      'friends_filled': FriendsPage(sessionStore: signedSession),
      'friends_discover_filled': FriendsPage(sessionStore: signedSession),
      'friends_invites_filled': FriendsPage(sessionStore: signedSession),
      'friends_ranking_filled': FriendsPage(sessionStore: signedSession),
      'home_progress': IllustratedNavigationScaffold(
        index: 0,
        onSelect: (_) {},
        body: HomePage(
          sessionStore: signedSession,
          catStore: store,
          onNavigate: (_) {},
        ),
      ),
      'challenges_progress': IllustratedNavigationScaffold(
        index: 3,
        onSelect: (_) {},
        body: LibraryPage(catStore: store, initialTab: 1),
      ),
      'achievements_progress': JourneyPage(store: store),
      'achievements_medals': JourneyPage(
        store: store,
        initialSection: 'achievement',
      ),
    };
    final basicProgress = store.progress.summary;
    final populatedProgress = Map<String, dynamic>.from(
      milestoneFixture['populated'] as Map,
    );
    screens['missions_paused'] = JourneyPage(store: store);
    screens['public_profile_medals'] = screens['public_profile']!;
    screens['missions_initial_progress'] = JourneyPage(
      store: store,
      initialSection: 'initial',
    );
    screens['missions_weekly_progress'] = JourneyPage(
      store: store,
      initialSection: 'weekly',
    );
    screens['seasonal_challenges'] = JourneyPage(
      store: store,
      initialSection: 'challenge',
    );
    screens['medal_celebration_progress'] = Scaffold(
      body: SafeArea(
        child: AchievementPresentation(
          goal: Map<String, dynamic>.from(
            (populatedProgress['achievements'] as List).first as Map,
          ),
          celebration: true,
        ),
      ),
    );
    for (final name in [
      'habitat_gift',
      'habitat_expanded',
      'habitat_edit_ground',
      'habitat_outskirts_north',
      'habitat_outskirts_south',
      'habitat_outskirts_east',
      'habitat_outskirts_west',
    ]) {
      screens[name] = screens['habitat']!;
    }
    screens['poster_details'] = screens['poster']!;
    screens['poster_settings'] = MissingCatPosterPage(
      catStore: store,
      cat: store.pets.first,
      report: Map.of(sampleReport),
      initialEditing: true,
    );
    screens['poster_contacts'] = screens['poster_settings']!;
    screens['composer_text'] = PostComposer(
      session: signedSession,
      initialNote: 'Hoje encontrei um gatinho na praça. Ficou observando as folhas por um tempão. 🌿',
    );
    screens['social_text'] = IllustratedNavigationScaffold(
      index: 1,
      onSelect: (_) {},
      body: SocialPage(
        sessionStore: signedSession,
        catStore: store,
        api: CommunityFixture(signedSession, photo, textOnlyFirst: true),
      ),
    );
    screens['composer_photo'] = PostComposer(
      session: signedSession,
      initialCat: store.pets.first,
      initialNote: 'Uma pausa no sol da tarde.',
    );
    screens['habitat_reward'] = Stack(
      children: [
        screens['habitat']!,
        Positioned(
          left: 16,
          right: 16,
          bottom: 180,
          child: HabitatRewardReveal(label: '+12 moedas', onClose: () {}),
        ),
      ],
    );
    var filled = false;
    await http.runWithClient(
      () async {
        for (final entry in screens.entries) {
          final only = Platform.environment['GATALOGO_CAPTURE_ONLY'];
          if (only != null && !only.split(',').contains(entry.key)) continue;
          filled = entry.key.endsWith('_filled');
          store.progress.summary =
              entry.key.endsWith('_progress') ||
                  entry.key == 'achievements_medals'
              ? populatedProgress
              : entry.key == 'missions_paused'
              ? {...basicProgress, 'rewards_enabled': false}
              : basicProgress;
          store.notifications.clear();
          if (entry.key == 'shop') {
            habitat.freeShop = true;
            habitat.shop = [
              for (final item in habitat.shop)
                HabitatShopItem.fromMap({
                  ...item.toMap(),
                  'base_price': item.price,
                  'price': 0,
                  'purchasable': item.price > 0,
                }),
            ];
          }
          if (entry.key == 'shop') {
            await tester.runAsync(
              () => Future.wait([
                for (final item in habitat.shop)
                  sprites.preview(sprites.keyFor(item.sprite, 0)),
              ]),
            );
          }
          debugPrint('CAPTURE ${entry.key}: start');
          final captureKey = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: captureKey,
              child: screenApp(entry.value, store),
            ),
          );
          await tester.runAsync(() async {
            final assets = await AssetManifest.loadFromAssetBundle(rootBundle);
            final context = tester.element(find.byType(MaterialApp));
            await Future.wait([
              for (final asset in assets.listAssets().where(
                (path) =>
                    path.startsWith('assets/gatalogo_asset_library/') &&
                    path.endsWith('.png'),
              ))
                precacheImage(AssetImage(asset), context),
            ]);
          });
          debugPrint('CAPTURE ${entry.key}: assets ready');
          await tester.runAsync(() => GoogleFonts.pendingFonts());
          debugPrint('CAPTURE ${entry.key}: fonts ready');
          final friendTab = {
            'friends_discover': 'Descobrir',
            'friends_invites': 'Convites',
            'friends_ranking': 'Ranking',
            'friends_discover_filled': 'Descobrir',
            'friends_invites_filled': 'Convites',
            'friends_ranking_filled': 'Ranking',
          }[entry.key];
          if (friendTab != null) {
            await tester.tap(find.text(friendTab).first);
            await tester.pump(const Duration(milliseconds: 400));
          }
          if (entry.key.startsWith('habitat') && entry.key != 'habitat_help') {
            final game =
                (tester.widget(
                      find.byWidgetPredicate((w) => w is GameWidget),
                    ) as GameWidget).game
                    as HabitatGame;
            var loaded = false;
            Future<void>.value(game.toBeLoaded()).then((_) => loaded = true);
            for (var attempt = 0; attempt < 40 && !loaded; attempt++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 50)),
              );
              await tester.pump(const Duration(milliseconds: 50));
            }
            expect(loaded, true, reason: '${entry.key}: scene assets loaded');
            if (entry.key.startsWith('habitat_outskirts_')) {
              game.scaleCamera(.65, Offset(game.size.x / 2, game.size.y / 2));
              final direction = switch (entry.key) {
                'habitat_outskirts_north' => const Offset(0, 1),
                'habitat_outskirts_south' => const Offset(0, -1),
                'habitat_outskirts_east' => const Offset(-1, 0),
                _ => const Offset(1, 0),
              };
              game.moveCamera(
                Offset(
                  direction.dx * game.size.x * .65,
                  direction.dy * game.size.y * .65,
                ),
              );
            }
            if (entry.key == 'habitat_expanded') {
              habitat.expansionLevel = 2;
              habitat.buildableCells = HabitatService.yardCells(2);
            }
            if (entry.key == 'habitat_gift' ||
                entry.key == 'habitat_expanded') {
              habitat.pendingGift = {
                'id': 'fixture-gift',
                'state': 'available',
                'visitor': 'bee',
              };
              HabitatNavigation.hasGift.value = true;
              await habitat.place('guest-cat_bed', 2, 2, 0);
              game.focusGift();
            }
            await tester.pump(const Duration(seconds: 2));
            await tester.pump(const Duration(seconds: 1));
            for (var frame = 0; frame < 45; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
            }
            for (
              var attempt = 0;
              attempt < 100 &&
                  find.byType(AppLoadingScreen).evaluate().isNotEmpty;
              attempt++
            ) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 50)),
              );
              await tester.pump(const Duration(milliseconds: 50));
            }
            expect(
              find.byType(AppLoadingScreen),
              findsNothing,
              reason: '${entry.key}: synchronized scene ready',
            );
            if (entry.key == 'habitat_edit_ground') {
              await tester.tap(find.byTooltip('Abrir ações do Quintal'));
              await tester.pump();
              await tester.tap(find.text('Editar'));
              await tester.pump();
            }
          } else {
            await tester.pump(const Duration(milliseconds: 600));
          }
          if (entry.key == 'composer_text') {
            tester.view.viewInsets = const FakeViewPadding(bottom: 280);
            await tester.pump(const Duration(milliseconds: 300));
          }
          if (entry.key == 'poster_details' ||
              entry.key == 'poster_contacts' ||
              entry.key == 'add_pet_details' ||
              entry.key == 'cat_gallery_angles') {
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -570),
            );
            await tester.pump(const Duration(milliseconds: 300));
          }
          final providers = tester
              .widgetList<Image>(find.byType(Image))
              .where(
                (w) =>
                    w.image is! NetworkImage ||
                    (w.image as NetworkImage).url.endsWith(
                      '/fixture/cat-photo',
                    ),
              )
              .map((w) => w.image)
              .toList();
          await tester.runAsync(() async {
            for (final provider in providers) {
              await precacheImage(provider, captureKey.currentContext!);
            }
          });
          await tester.pump(const Duration(milliseconds: 100));
          if (entry.key == 'community_posters_filled') {
            expect(find.text('Caso encerrado · cartaz de ana'), findsOneWidget);
            expect(find.text('Repostar na comunidade'), findsOneWidget);
          }
          if (entry.key == 'clues_filled') {
            final photos = find.byWidgetPredicate(
              (widget) => widget is Image && widget.image is MemoryImage,
            );
            expect(photos, findsNWidgets(3));
            // The list request creates protected photo requests after the
            // first warm-up. Decode those newly mounted images before capture.
            final lateProviders = tester
                .widgetList<Image>(photos)
                .map((w) => w.image)
                .toList();
            await tester.runAsync(() async {
              for (final provider in lateProviders) {
                await precacheImage(provider, captureKey.currentContext!);
              }
            });
            await tester.pump(const Duration(milliseconds: 100));
            for (final element in photos.evaluate()) {
              final raw = find.descendant(
                of: find.byWidget(element.widget),
                matching: find.byType(RawImage),
              );
              final rendered = tester.renderObject<RenderImage>(raw);
              expect(rendered.image, isNotNull);
              expect(rendered.size, const Size(62, 62));
            }
          }
          expect(tester.takeException(), isNull, reason: entry.key);
          if (entry.key == 'shop') {
            expect(find.text('Expandir grátis para teste'), findsOneWidget);
          }
          await tester.runAsync(() async {
            final boundary =
                captureKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(visualGalleryDirectory).create(recursive: true);
            await File('$visualGalleryDirectory/${entry.key}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
            debugPrint('CAPTURE ${entry.key}: saved');
          });
          await tester.pumpWidget(const SizedBox());
          tester.view.resetViewInsets();
          await tester.pump(const Duration(milliseconds: 600));
        }
        for (final width in [320.0, 820.0]) {
          tester.view.physicalSize = Size(width, 1000);
          for (final name in [
            'my_cats',
            'add_pet',
            'pet',
            'cat_gallery',
            'public_profile',
            'inbox',
            'notifications',
            'settings',
            'experience',
            'composer',
            'quick_alert',
            'registered_alert',
            'active_alert',
            'poster',
            'poster_settings',
            'clues',
            'clue_detail',
            'contribution',
            'missing_cats',
            'community_case',
            'community_posters',
            'collection',
            'cat_detail',
            'chat',
            'habitat_help',
            'achievements',
            'history',
            'result',
            'shop',
            'inbox_filled',
            'notifications_filled',
            'missing_cats_filled',
            'community_posters_filled',
            'community_case_filled',
            'clues_filled',
            'friends_filled',
            'friends_discover_filled',
            'friends_invites_filled',
            'friends_ranking_filled',
            'home_progress',
            'challenges_progress',
            'achievements_progress',
          ]) {
            final only = Platform.environment['GATALOGO_CAPTURE_ONLY'];
            if (only != null && !only.split(',').contains(name)) continue;
            filled = name.endsWith('_filled');
            store.progress.summary = name.endsWith('_progress')
                ? populatedProgress
                : basicProgress;
            store.notifications.clear();
            await tester.pumpWidget(
              screenApp(screens[name]!, store, scale: 1.5),
            );
            await tester.pump(const Duration(milliseconds: 600));
            final tab = {
              'friends_discover_filled': 'Descobrir',
              'friends_invites_filled': 'Convites',
              'friends_ranking_filled': 'Ranking',
            }[name];
            if (tab != null) {
              await tester.ensureVisible(find.text(tab).first);
              await tester.tap(find.text(tab).first);
              await tester.pump(const Duration(milliseconds: 400));
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$name at $width with enlarged text',
            );
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
      },
      () => MockClient((request) async {
        final path = request.url.path;
        // A transparent fixture preserves the unavailable-map state without
        // attempting to decode API JSON as remote street tiles.
        if (request.url.host == 'tile.openstreetmap.org') {
          return http.Response.bytes(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
            ),
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        if (path == '/app/clues/photo/clue' || path == '/fixture/cat-photo') {
          return http.Response.bytes(
            photoBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        dynamic data = [];
        if (filled) {
          const person = {
            'id': 'ana',
            'username': 'ana',
            'bio': 'Passeios pelo bairro e novas descobertas.',
            'avatar_url': '/app/account/avatar/preset/bapinha',
            'reason': 'Exploradora ativa',
            'score': 1,
            'criterion': 'cats',
            'period': 'weekly',
            'server_now': '2026-10-05T12:00:00-03:00',
            'reset_at': '2026-10-12T00:00:00-03:00',
            'rank': 1,
            'xp': 180,
            'level': 2,
            'streak': 3,
          };
          final report = {
            ...sampleReport,
            'clue_count': 2,
            'author': 'ana',
            'photo_url': '/fixture/cat-photo',
          };
          if (path.endsWith('/social/friends') ||
              path.endsWith('/social/suggestions') ||
              path.endsWith('/social/leaderboard/weekly')) {
            data = [person];
          }
          if (path.endsWith('/social/invites')) {
            data = [
              {
                'id': 'invite',
                'status': 'pending',
                'sender': person,
                'recipient': {'id': 'first'},
              },
            ];
          }
          if (path.endsWith('/app/reports') ||
              path.endsWith('/social/reports')) {
            data = [
              report,
              {
                ...report,
                'id': 'resolved',
                'name': 'Lua',
                'status': 'resolved',
              },
            ];
          }
          if (path.endsWith('/social/reports/report')) {
            data = {
              ...report,
              'description':
                  'Último avistamento perto da praça. Usa coleira azul.',
            };
          }
          if (path.endsWith('/app/reports/report/clues')) {
            data = [
              for (final status in ['pending', 'confirmed', 'dismissed'])
                {
                  'id': status,
                  'photo_url': '/app/clues/photo/clue',
                  'status': status,
                  'created_at': '2026-10-04T10:00:00Z',
                  'distance_meters': 350,
                  'note': 'Visto perto da praça.',
                },
            ];
          }
          if (path.endsWith('/vision/notifications')) {
            data = [
              for (final type in ['possible_match', 'message', 'achievement'])
                {
                  'id': type,
                  'type': type,
                  'created_at': '2026-10-04T10:00:00Z',
                  'payload': {'match_id': 'clue'},
                },
            ];
          }
          if (path.endsWith('/social/conversations')) {
            data = [
              {
                'id': 'chat',
                'other_user': person,
                'unread_count': 2,
                'sighting_context': true,
                'updated_at': '2026-10-04T10:00:00Z',
                'last_message': {
                  'id': 'message',
                  'body': 'Encontrei um gatinho na praça hoje!',
                  'sender_id': 'ana',
                  'created_at': '2026-10-04T10:00:00Z',
                },
              },
            ];
          }
        }
        if (path.endsWith('/app/account')) {
          data = {
            'username': 'teste',
            'bio': 'Passeios e gatos.',
            'preferences': {},
            'avatar_url': '/app/account/avatar/preset/bapinha',
          };
        }
        if (path.endsWith('/app/progress/clues/clue')) {
          data = {
            'status': 'pending',
            'report_status': 'active',
            'report_id': 'report',
            'message': 'Aguardando confirmação do tutor.',
          };
        }
        if (path.endsWith('/app/progress/clues/confirmed')) {
          data = {
            'status': 'confirmed',
            'report_status': 'resolved',
            'report_id': 'report',
            'message': 'Sua pista foi reconhecida pelo tutor.',
          };
        }
        if (path.contains('/profiles/')) {
          data = {
            'id': 'ana',
            'username': 'ana',
            'bio': 'Gatos e passeios tranquilos.',
            'achievements': [(populatedProgress['achievements'] as List).first],
            'avatar_url': '/app/account/avatar/preset/bapinha',
            'level': 2,
            'level_title': 'Explorador',
            'xp': 130,
            'cats_count': 1,
            'friendship_status': 'none',
          };
        }
        if (path.endsWith('/conversations/chat')) {
          data = {
            'other_user_id': 'ana',
            'username': 'ana',
            'avatar_url': '/app/account/avatar/preset/bapinha',
            'is_online': false,
          };
        }
        if (path.endsWith('/conversations/chat/messages')) {
          data = [
            {
              'id': 'message',
              'conversation_id': 'chat',
              'sender_id': 'ana',
              'body': 'Encontrei um gatinho na praça hoje!',
              'created_at': '2026-10-04T10:00:00Z',
            },
          ];
        }
        if (!filled && path.endsWith('/social/reports/report')) {
          data = {...sampleReport, 'author': 'ana', 'contacts': []};
        }
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await tester.runAsync(() => updateVisualGallery(screens.keys));
    debugNetworkImageHttpClientProvider = previousImageClient;
    active.dispose();
    habitat.dispose();
    store.dispose();
    session.dispose();
    signedSession.dispose();
  }, skip: Platform.environment['GATALOGO_CAPTURE_ALL'] != '1');
}
