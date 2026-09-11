import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/pages/home_page.dart';
import 'package:catlogue/pages/library_page.dart';
import 'package:catlogue/pages/my_cats_page.dart';
import 'package:catlogue/pages/journey_page.dart';
import 'package:catlogue/pages/auth_page.dart';
import 'package:catlogue/pages/cat_details_page.dart';

class LocalStore extends CatStore {
  LocalStore(super.session);
  final sample = [
    Cat(
      id: 'discovery',
      captureNumber: 1,
      photoPath: 'missing-test.jpg',
      capturedAt: DateTime(2026, 9, 8),
      name: 'Gato da praça',
      status: 'completed',
    ),
    Cat(
      id: 'pet',
      captureNumber: 2,
      photoPath: 'missing-test.jpg',
      capturedAt: DateTime(2026, 9, 8),
      name: 'Meu gato',
      isOwned: true,
    ),
  ];
  @override
  List<Cat> get cats => sample;
}

void main() {
  test('owned classification survives all edits and synchronization', () {
    final cat = Cat(
      id: 'a',
      captureNumber: 1,
      photoPath: 'a.jpg',
      capturedAt: DateTime(2026),
      isOwned: true,
    );
    final changed = cat
        .withName('Lua')
        .withStatus('completed')
        .withLocation(latitude: 0, longitude: 0)
        .withSync(syncState: 'synced');
    expect(changed.isOwned, isTrue);
    expect(Cat.fromMap(changed.toMap()).isOwned, isTrue);
    final legacy = cat.toMap()..remove('is_owned');
    expect(Cat.fromMap(legacy).isOwned, isFalse);
  });

  testWidgets('collection keeps owned pets separate and supports search', (
    tester,
  ) async {
    final session = SessionStore();
    final store = LocalStore(session);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LibraryPage(catStore: store)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gato da praça'), findsOneWidget);
    expect(find.text('Meu gato'), findsNothing);
    await tester.enterText(find.byType(TextField), 'ausente');
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma descoberta aqui'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    session.dispose();
  });

  for (final size in [const Size(360, 800), const Size(820, 1000)]) {
    testWidgets('product pages fit ${size.width} with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = SessionStore();
      final store = LocalStore(session);
      final pages = [
        Scaffold(
          body: HomePage(
            sessionStore: session,
            catStore: store,
            onNavigate: (_) {},
          ),
        ),
        MyCatsPage(store: store),
        PetProfilePage(catId: 'pet', store: store),
        AddPetPage(store: store),
        JourneyPage(store: store),
        CatDetailsPage(cat: store.cats.first, catStore: store),
        AuthPage(sessionStore: session, onContinueOffline: () {}),
      ];
      for (final page in pages) {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: page,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${page.runtimeType} must fit ${size.width}',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
      store.dispose();
      session.dispose();
    });
  }
}
