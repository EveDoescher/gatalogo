import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/pages/home_page.dart';
import 'package:catlogue/pages/my_cats_page.dart';

import 'product_flows_test.dart' show LocalStore;

void main() {
  final fontPath = Platform.environment['GATALOGO_PREVIEW_FONT'];
  testWidgets('render product previews for visual review', (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader('Roboto');
      final bytes = await File(fontPath!).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      final iconBytes = await File('${File(fontPath).parent.path}/MaterialIcons-Regular.otf').readAsBytes();
      icons.addFont(Future.value(ByteData.sublistView(iconBytes)));
      await icons.load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = SessionStore();
    final store = LocalStore(session);
    final pages = {
      'home': Scaffold(
        body: HomePage(
          sessionStore: session,
          catStore: store,
          onNavigate: (_) {},
        ),
      ),
      'my_cat': PetProfilePage(catId: 'pet', store: store),
    };
    for (final entry in pages.entries) {
      await tester.pumpWidget(
        MaterialApp(debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            fontFamily: 'Roboto',
          ),
          home: entry.value,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/${entry.key}.png'),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
    store.dispose();
    session.dispose();
  }, skip: fontPath == null);
}
