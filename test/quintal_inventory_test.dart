import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/services/product_api_service.dart';
import 'package:catlogue/services/quintal_inventory.dart';
import 'package:catlogue/widgets/quintal_inventory_tray.dart';
import 'package:catlogue/theme/app_theme.dart';

import 'visual_validation_capture_test.dart'
    show ValidationAccount, ValidationStore, ValidationDatabase;
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
    Map<String, dynamic>? data,
  ]) => throw StateError('Inventory navigation must not mutate resources');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HabitatService h;
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final fixture = Map<String, dynamic>.from(
      jsonDecode(
        File('test/fixtures/quintal_production.json').readAsStringSync(),
      ),
    );
    final account = ValidationAccount();
    h = HabitatService(
      account,
      ValidationStore(account),
      database: ValidationDatabase(),
      api: _Api(account, fixture),
    );
    await h.load();
  });
  tearDown(() => h.dispose());

  test('stock, served portions and uncollected outputs stay distinct', () {
    final before = jsonEncode(h.production);
    final inventory = quintalInventory(h);
    expect(inventory['wheat']!.available, 18);
    expect(
      inventory['wheat']!.reserved,
      0,
      reason: 'Ready inputs have been consumed',
    );
    expect(inventory['ration:garden']!.available, 6);
    expect(inventory['ration:garden']!.served, 1);
    expect(inventory['ration:garden']!.ready, 3);
    expect(inventory['corn']!.ready, 4);
    expect(inventory['egg']!.ready, 4);
    expect(inventory['milk']!.ready, 2);
    expect(inventory['apple']!.ready, 3);
    expect(inventory['pear']!.ready, 3);
    expect(jsonEncode(h.production), before);
  });

  test(
    'reservation, deadline, cancel and collection never double debit stock',
    () {
      final now = h.serverNow;
      h.production['stock'] = {'wheat': 16};
      final task = <String, dynamic>{
        'id': 'one',
        'kind': 'cook',
        'status': 'active',
        'started_at': now.toIso8601String(),
        'ready_at': now.add(const Duration(minutes: 10)).toIso8601String(),
        'inputs': {'wheat': 2},
        'outputs': {'ration:garden': 3},
      };
      h.production['tasks'] = [task];
      var inventory = quintalInventory(h);
      expect(inventory['wheat']!.available, 16);
      expect(inventory['wheat']!.reserved, 2);
      expect(inventory['ration:garden']!.preparing, 3);
      task['ready_at'] = now
          .subtract(const Duration(seconds: 1))
          .toIso8601String();
      inventory = quintalInventory(h);
      expect(inventory['wheat']!.available, 16);
      expect(inventory['wheat']!.reserved, 0);
      expect(inventory['ration:garden']!.ready, 3);
      expect(inventory['ration:garden']!.available, 0);
      task['status'] = 'collected';
      h.production['stock'] = {'wheat': 16, 'ration:garden': 3};
      inventory = quintalInventory(h);
      expect(inventory['ration:garden']!.ready, 0);
      expect(inventory['ration:garden']!.available, 3);
      task['status'] = 'cancelled';
      h.production['stock'] = {'wheat': 18};
      expect(quintalInventory(h)['wheat']!.reserved, 0);
      expect(quintalInventory(h)['wheat']!.available, 18);
    },
  );

  testWidgets(
    'resource details fit the tray and open destinations without spending',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.runAsync(
        () => (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load(),
      );
      final captures = <String>[];
      final destinations = <String>[];
      h.production['stock'] = {...h.productionStock, 'apple': 3};
      final before = jsonEncode(h.production);
      for (final width in [390.0, 320.0]) {
        tester.view.physicalSize = Size(width, 568);
        for (final tab in [1, 2, 3]) {
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 568),
                  textScaler: const TextScaler.linear(1.5),
                ),
                child: Scaffold(
                  backgroundColor: const Color(0xffA2BF78),
                  body: RepaintBoundary(
                    key: key,
                    child: Container(
                      color: const Color(0xffA2BF78),
                      alignment: Alignment.bottomCenter,
                      child: QuintalInventoryTray(
                        key: ValueKey('$width/$tab'),
                        habitat: h,
                        initialTab: tab == 3 ? 2 : tab,
                        decorations: const SizedBox(),
                        onClose: () {},
                        onKitchen: () {},
                        onDestination: (space, target) =>
                            destinations.add('$space:$target'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(() async {
            final context = tester.element(find.byType(QuintalInventoryTray));
            await Future.wait(
              tester
                  .widgetList<Image>(find.byType(Image))
                  .map((w) => precacheImage(w.image, context)),
            );
            await GoogleFonts.pendingFonts();
          });
          await tester.pump();
          expect(
            tester.getSize(find.text('Ingredientes')).height,
            lessThan(35),
            reason: 'Tab label must remain on one line with large text',
          );
          final selected = tab == 1
              ? 'Mistura da horta'
              : tab == 2
              ? 'Milho'
              : 'Maçã';
          await tester.scrollUntilVisible(
            find.text(selected),
            100,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pump();
          await tester.tap(find.text(selected));
          await tester.pump();
          expect(
            find.text(
              tab == 1
                  ? '1 porção servida nos potes'
                  : tab == 2
                  ? '12 disponíveis'
                  : '3 disponíveis',
            ),
            findsOneWidget,
          );
          final tray = tester.getRect(find.byType(QuintalInventoryTray));
          expect(tray.height, 258);
          expect(tray.top, greaterThan(300));
          final name = 'quintal_inventory_detail_${tab}_${width.toInt()}';
          await tester.runAsync(() async {
            await GoogleFonts.pendingFonts();
          });
          await tester.pump();
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('$visualGalleryDirectory/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          captures.add(name);
          if (tab == 3) {
            final recipe = find.textContaining('Mistura com maçã');
            await tester.scrollUntilVisible(
              recipe,
              60,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pump();
            expect(recipe, findsOneWidget);
          }
          final link = tab == 1
              ? find.textContaining('Ver pote de')
              : find.text('Ver trocas');
          await tester.scrollUntilVisible(
            link,
            100,
            scrollable: find.byType(Scrollable).last,
          );
          await Scrollable.ensureVisible(
            tester.element(link.first),
            alignment: .5,
          );
          await tester.pump();
          expect(link.first.hitTestable(), findsOneWidget);
          if (tab == 3) {
            expect(
              find.textContaining('Trocas no Mercadinho:'),
              findsOneWidget,
            );
          }
          await tester.tap(link.first);
          await tester.pump();
          expect(destinations.last, startsWith(tab == 1 ? 'cat:' : 'market:'));
          expect(jsonEncode(h.production), before);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      }
      await tester.runAsync(() => updateVisualGallery(captures));
    },
  );
}
