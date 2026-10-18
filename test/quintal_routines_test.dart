import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catlogue/theme/app_theme.dart';
import 'package:catlogue/widgets/progress_components.dart';

import 'support/visual_gallery.dart';

void main() {
  testWidgets(
    'optional community mission preserves its original continuation',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GoalCard(
                goal: const {
                  'id': 'start_community',
                  'title': 'Encontre sua comunidade',
                  'optional': true,
                  'destination': 'social',
                  'target': 1,
                  'progress': 0,
                },
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Continuar'), findsOneWidget);
      expect(find.text('Visitar o Quintal'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'optional routines show unlocked alternatives and work with large text',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.runAsync(
        () => (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load(),
      );
      final fixture = jsonDecode(
        File('test/fixtures/quintal_routines.json').readAsStringSync(),
      ) as Map;
      final captures = <String>[];
      var visits = 0;
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 844);
        for (final kind in ['daily', 'weekly']) {
          final goal = Map<String, dynamic>.from(fixture[kind] as Map);
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 844),
                  textScaler: const TextScaler.linear(1.5),
                ),
                child: RepaintBoundary(
                  key: key,
                  child: Scaffold(
                    body: SafeArea(
                      child: SingleChildScrollView(
                        key: ValueKey('$width/$kind'),
                        padding: const EdgeInsets.all(16),
                        child: GoalCard(goal: goal, onTap: () => visits++),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(() async {
            final context = tester.element(find.byType(GoalCard));
            await Future.wait(
              tester
                  .widgetList<Image>(find.byType(Image))
                  .map((w) => precacheImage(w.image, context)),
            );
            await GoogleFonts.pendingFonts();
          });
          await tester.pump();
          expect(find.text('Opcional · no seu ritmo'), findsOneWidget);
          for (final option in goal['alternatives'] as List) {
            expect(find.text('• ${option['title']}'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          final name = 'quintal_routine_${kind}_${width.toInt()}';
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(visualGalleryDirectory).create(recursive: true);
            await File('$visualGalleryDirectory/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          captures.add(name);
          await Scrollable.ensureVisible(
            tester.element(find.text('Visitar o Quintal')),
            alignment: .8,
          );
          await tester.pump();
          await tester.tap(find.text('Visitar o Quintal'));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      }
      expect(visits, 4);
      await tester.runAsync(() => updateVisualGallery(captures));
    },
  );
}
