import 'package:catlogue/widgets/botanical_scene.dart';
import 'package:catlogue/widgets/illustrated_home_components.dart';
import 'package:catlogue/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('all tabs paint to screen edge and keep content above menu', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final theme = AppTheme.lightTheme;
    GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w900);
    await tester.runAsync(() async {
      final icons = FontLoader('packages/lucide_icons_flutter/Lucide');
      icons.addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
      await icons.load();
      await GoogleFonts.pendingFonts();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [(390.0, 1.0), (320.0, 1.5)]) {
      tester.view.physicalSize = Size(size.$1, 844);
      for (var index = 0; index < 5; index++) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(size.$2)),
              child: child!,
            ),
            home: IllustratedNavigationScaffold(
              index: index,
              onSelect: (_) {},
              body: const BotanicalScaffold(
                body: SafeArea(
                  child: SizedBox.expand(key: ValueKey('content')),
                ),
              ),
            ),
          ),
        );
        final background = tester.getRect(find.byType(BotanicalScene));
        final menu = tester.getRect(find.byType(IllustratedNavigationBar));
        final content = tester.getRect(find.byKey(const ValueKey('content')));
        expect(background.bottom, 844, reason: 'tab $index');
        expect(background.bottom, greaterThan(menu.top));
        expect(content.bottom, lessThanOrEqualTo(menu.top));
        for (final label in [
          'Início',
          'Social',
          'Gatalogar',
          'Coleção',
          'Quintal',
        ]) {
          final tab = find.byTooltip(label);
          expect(tab.hitTestable(), findsOneWidget);
          final rect = tester.getRect(tab);
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
        }
        final active = find.text(
          ['Início', 'Social', 'Gatalogar', 'Coleção', 'Quintal'][index],
        );
        final paragraph = tester.renderObject<RenderParagraph>(active);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.height, lessThan(30));
        expect(tester.takeException(), isNull);
      }
    }
  });
}
