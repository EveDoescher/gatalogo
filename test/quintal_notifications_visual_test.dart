import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catlogue/pages/settings_page.dart';
import 'package:catlogue/stores/session_store.dart';

import 'screen_corrections_test.dart';
import 'support/visual_gallery.dart';

import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/widgets/quintal_return_dialog.dart';

import 'visual_validation_capture_test.dart' show ValidationDatabase;

void main() {
  testWidgets('return links acknowledge only the selected event', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(() async {
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = SessionStore();
    final store = ScreenStore(session);
    final habitat = HabitatService(
      session,
      store,
      database: ValidationDatabase(),
    );
    habitat.production = Map<String, dynamic>.from(
      jsonDecode(
            File('test/fixtures/quintal_production.json').readAsStringSync(),
          )['production']
          as Map,
    );
    const updates = <Map<String, dynamic>>[
      {
        'event_id': 'crop1',
        'kind': 'harvest',
        'target': 'wheat',
        'slot': 0,
        'quantity': 3,
      },
      {
        'event_id': 'cook1',
        'kind': 'cook',
        'target': 'garden',
        'outputs': {'meal:garden': 3},
      },
      {
        'event_id': 'eggs1',
        'kind': 'resident',
        'target': 'coop',
        'quantity': 2,
      },
    ];
    QuintalReturnSelection? result;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: screenApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await showDialog<QuintalReturnSelection>(
                      context: context,
                      builder: (_) => QuintalReturnDialog(
                        habitat: habitat,
                        updates: updates,
                      ),
                    ),
                child: const Text('Abrir'),
              ),
            ),
          ),
          store,
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(QuintalReturnDialog));
    await tester.runAsync(() async {
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(image.image, context);
      }
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$visualGalleryDirectory/quintal_return_summary.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      final html = File('$visualGalleryDirectory/galeria.html')
          .readAsStringSync();
      final names = RegExp(r'src="([^"/]+)\.png')
          .allMatches(html)
          .map((m) => m[1]!)
          .toSet();
      await updateVisualGallery({...names, 'quintal_return_summary'});
    });
    tester.view.physicalSize = const Size(320, 568);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Trigo pronto para colher'));
    await tester.pumpAndSettle();
    expect(result?.eventIds, ['crop1']);
    expect(result?.destination, 'garden');
    await tester.pumpWidget(const SizedBox());
    habitat.dispose();
  });
  testWidgets('Quintal notification preference remains readable', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = SessionStore();
    final store = ScreenStore(session);
    final key = GlobalKey();
    await tester.runAsync(() async {
      final font = FontLoader('packages/lucide_icons_flutter/Lucide');
      font.addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
      await font.load();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: screenApp(
          SettingsPage(sessionStore: session, catStore: store),
          store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Notificações & Avisos'));
    await tester.pumpAndSettle();
    expect(find.text('Produção e presentes do Quintal'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$visualGalleryDirectory/quintal_notification_settings.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      final html = File('$visualGalleryDirectory/galeria.html')
          .readAsStringSync();
      final names = RegExp(r'src="([^"/]+)\.png')
          .allMatches(html)
          .map((m) => m[1]!)
          .toSet();
      await updateVisualGallery({...names, 'quintal_notification_settings'});
    });
    tester.view.physicalSize = const Size(320, 568);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
