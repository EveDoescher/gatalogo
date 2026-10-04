import 'package:catlogue/widgets/botanical_scene.dart';
import 'package:catlogue/widgets/illustrated_home_components.dart';
import 'package:catlogue/theme/app_theme.dart';
import 'package:flutter/material.dart';
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
    for (var index = 0; index < 5; index++) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: IllustratedNavigationScaffold(
            index: index,
            onSelect: (_) {},
            body: const BotanicalScaffold(
              body: SafeArea(child: SizedBox.expand(key: ValueKey('content'))),
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
      expect(tester.takeException(), isNull);
    }
  });
}
