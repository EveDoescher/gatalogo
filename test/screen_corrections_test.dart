import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/app.dart';
import 'package:catlogue/pages/capture_page.dart';
import 'package:catlogue/pages/cat_details_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:catlogue/pages/friends_page.dart';
import 'package:catlogue/pages/missing_cats_page.dart';
import 'package:catlogue/pages/missing_cat_poster_page.dart';
import 'package:catlogue/pages/profile_page.dart';
import 'package:catlogue/pages/settings_page.dart';
import 'package:catlogue/pages/social_page.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/services/social_api_service.dart';
import 'package:catlogue/theme/app_theme.dart';
import 'package:catlogue/widgets/app_header_actions.dart';
import 'package:catlogue/widgets/post_composer.dart';
import 'package:catlogue/widgets/inbox_button.dart';

import 'product_flows_test.dart' show LocalStore;
import 'gamification_service_test.dart' show Account;

class FeedFixture extends SocialApiService {
  FeedFixture(super.session);
  @override
  Future<List<Map<String, dynamic>>> conversations() async => [];
  @override
  Future<List<Map<String, dynamic>>> feed({
    int limit = 20,
    String? cursor,
    String? cursorId,
    String mode = 'all',
  }) async => [
    {
      'id': 'post',
      'username': 'ana',
      'type': 'cat_post',
      'created_at': '2026-09-22T10:00:00Z',
      'payload': <String, dynamic>{
        'cat_name': 'Lua',
        'note': 'Um encontro no caminho de casa.',
        'author_avatar_url': '/avatars/ana.jpg',
        'location_name': 'Praça das Flores',
        'likes': [],
        'comments': [],
      },
    },
  ];
}

class ScreenStore extends LocalStore {
  ScreenStore(super.session);
  @override
  Future<void> loadCats() async {}
}

const sampleReport = <String, dynamic>{
  'id': 'report',
  'cat_client_id': 'pet',
  'name': 'Meu gato',
  'status': 'active',
  'latitude': -23.5,
  'longitude': -46.6,
  'radius_meters': 1000,
  'created_at': '2026-09-22T10:00:00Z',
  'last_seen_address': 'Rua das Flores, 15, Centro',
  'collar': 'Azul',
  'distinguishing_marks': 'Pata branca',
  'microchip': '123456',
  'contacts': [
    {'phone': '(11) 99999-1234', 'whatsapp': true},
  ],
};

Widget screenApp(Widget page, ScreenStore store, {double scale = 1}) =>
    AppStoreScope(
      store: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page,
      ),
    );

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final size in [const Size(320, 720), const Size(820, 1000)]) {
    testWidgets(
      'remaining corrected screens fit ${size.width} with enlarged text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = SessionStore();
        final store = ScreenStore(session);
        final pages = <Widget>[
          CapturePage(catStore: store),
          SocialPage(sessionStore: session, catStore: store),
          FriendsPage(sessionStore: session),
          ProfilePage(sessionStore: session, catStore: store),
          SettingsPage(sessionStore: session, catStore: store),
          CreateMissingReportPage(store: store, quickMode: true),
          CreateMissingReportPage(store: store, initialCat: store.pets.first),
          MissingReportDetailPage(store: store, report: sampleReport),
          MissingCatPosterPage(
            catStore: store,
            cat: store.pets.first,
            report: sampleReport,
          ),
          Scaffold(
            body: PostComposer(session: session, cats: store.cats),
          ),
        ];
        final errors = <String>[];
        for (final page in pages) {
          await tester.pumpWidget(screenApp(page, store, scale: 1.3));
          await tester.pumpAndSettle();
          final error = tester.takeException();
          if (error != null) {
            errors.add('${page.runtimeType} at ${size.width}: $error');
          }
          if (page is! Scaffold) {
            expect(
              find.byType(InboxButton),
              findsOneWidget,
              reason: '${page.runtimeType} needs a shared inbox',
            );
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
        store.dispose();
        session.dispose();
        expect(errors, isEmpty);
      },
    );
  }

  testWidgets('quick alert selects its mode even when registered pets exist', (
    tester,
  ) async {
    final session = SessionStore();
    final store = ScreenStore(session);
    await tester.pumpWidget(
      screenApp(CreateMissingReportPage(store: store, quickMode: true), store),
    );
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {true},
    );
    expect(
      find.widgetWithText(TextField, 'Coleira (opcional)'),
      findsOneWidget,
    );
    await tester.tap(find.text('Gato Cadastrado'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {false},
    );
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    session.dispose();
  });

  testWidgets(
    'poster has optional details and community before external sharing',
    (tester) async {
      final session = SessionStore();
      final store = ScreenStore(session);
      await tester.pumpWidget(
        screenApp(
          MissingCatPosterPage(
            cat: store.pets.first,
            catStore: store,
            report: sampleReport,
          ),
          store,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Região monitorada'), findsNothing);
      expect(find.textContaining('Rua das Flores'), findsOneWidget);
      final community = find.text('Publicar na comunidade');
      await tester.scrollUntilVisible(community, 300);
      final external = find.text('Compartilhar em outros apps');
      expect(
        tester.getTopLeft(community).dy,
        lessThan(tester.getTopLeft(external).dy),
      );
      expect(find.textContaining('Copiar texto'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'five navigation actions fit and Quintal opens the playable scene',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = SessionStore();
      final store = ScreenStore(session);
      await tester.pumpWidget(
        screenApp(
          MainNavigation(sessionStore: session, catStore: store),
          store,
          scale: 1.3,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Quintal').last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Um cantinho para descansar'), findsNothing);
      expect(find.byTooltip('Abrir ações do Quintal'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Ajuda do Quintal'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(
        find.text('Como ganhar moedas'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Como ganhar moedas'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'signed-in feed displays author avatar and floating composer on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = Account();
      final store = ScreenStore(session);
      await tester.pumpWidget(
        screenApp(
          SocialPage(
            sessionStore: session,
            catStore: store,
            api: FeedFixture(session),
          ),
          store,
          scale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is NetworkImage &&
              (widget.image as NetworkImage).url.contains('/avatars/ana.jpg'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(PostComposer), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'notes and overflow menu use the light palette, and sharing stays inside the app',
    (tester) async {
      final session = Account();
      final store = ScreenStore(session);
      await tester.pumpWidget(
        screenApp(
          CatDetailsPage(cat: store.cats.first, catStore: store),
          store,
        ),
      );
      await tester.pumpAndSettle();
      final menu = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      expect(menu.color, AppColors.surface);
      final entries = menu
          .itemBuilder(tester.element(find.byType(PopupMenuButton<String>)))
          .whereType<PopupMenuItem<String>>()
          .map((entry) => entry.value)
          .toList();
      expect(entries, ['rename', 'delete']);
      await tester.scrollUntilVisible(
        find.text('Adicionar'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).backgroundColor,
        AppColors.background,
      );
      final input = tester.widget<TextField>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
      );
      expect(input.decoration?.fillColor, AppColors.cardAltBackground);
      expect(input.style?.color, AppColors.textTitle);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compartilhar'));
      await tester.pumpAndSettle();
      expect(find.byType(PostComposer), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'poster editor supports multiple contacts and independent WhatsApp choices',
    (tester) async {
      final session = SessionStore();
      final store = ScreenStore(session);
      await tester.pumpWidget(
        screenApp(
          MissingCatPosterPage(
            catStore: store,
            cat: store.pets.first,
            report: {...sampleReport, 'contacts': []},
            initialEditing: true,
          ),
          store,
        ),
      );
      Future<void> tapVisible(Finder target) async {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      final add = find.text('Adicionar telefone');
      await tapVisible(add);
      final confirm = find.byKey(const ValueKey('confirm_poster_contact'));
      final phone = find.byKey(const ValueKey('poster_contact_phone'));
      await tapVisible(confirm);
      expect(find.text('Informe um telefone válido com DDD.'), findsOneWidget);
      await tester.enterText(phone, '(11) 99999-1234');
      await tapVisible(find.byKey(const ValueKey('poster_contact_whatsapp')));
      await tapVisible(confirm);
      expect(find.text('(11) 99999-1234'), findsOneWidget);
      expect(find.text('Telefone e WhatsApp'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tapVisible(find.text('Adicionar outro telefone'));
      await tester.enterText(phone, '(11) 3333-1234');
      await tapVisible(confirm);
      expect(find.text('Telefone adicionado'), findsNWidgets(2));
      expect(find.text('Somente telefone'), findsOneWidget);
      await tapVisible(find.byTooltip('Editar contato 1'));
      await tester.enterText(phone, '(11) 99999-5678');
      await tapVisible(find.text('Cancelar'));
      expect(find.text('(11) 99999-1234'), findsOneWidget);
      expect(find.text('(11) 99999-5678'), findsNothing);
      await tapVisible(find.byTooltip('Editar contato 1'));
      await tester.enterText(phone, '(11) 99999-5678');
      await tapVisible(confirm);
      expect(find.text('(11) 99999-5678'), findsOneWidget);
      await tapVisible(find.byTooltip('Remover contato 1'));
      expect(find.text('(11) 99999-5678'), findsNothing);
      expect(find.text('(11) 3333-1234'), findsOneWidget);
      expect(find.text('Telefone adicionado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'settings switch updates the persisted automatic sync preference',
    (tester) async {
      final session = SessionStore();
      final store = ScreenStore(session);
      await tester.pumpWidget(
        screenApp(SettingsPage(sessionStore: session, catStore: store), store),
      );
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Sincronização Automática',
      );
      await tester.scrollUntilVisible(toggle, 250);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(session.autoSyncEnabled, false);
      expect(tester.widget<SwitchListTile>(toggle).value, false);
      expect(
        await const FlutterSecureStorage().read(key: 'auto_sync_enabled'),
        'false',
      );
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      session.dispose();
    },
  );
}
