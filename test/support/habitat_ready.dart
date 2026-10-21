import 'package:catlogue/game/habitat_game.dart';
import 'package:catlogue/pages/habitat_page.dart';
import 'package:catlogue/widgets/app_loading_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// The game can finish loading before the page synchronizes its visible assets.
/// Continuous Flame frames make pumpAndSettle unsuitable for this condition.
Future<HabitatGame> waitForHabitatReady(WidgetTester tester) async {
  final page = find.byType(HabitatPage, skipOffstage: false);
  expect(page, findsOneWidget);
  final loading = find.descendant(
    of: page,
    matching: find.byType(AppLoadingScreen, skipOffstage: false),
    skipOffstage: false,
  );
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (loading.evaluate().isEmpty) {
      final gameWidget = find.descendant(
        of: page,
        matching: find.byWidgetPredicate(
          (widget) => widget is GameWidget,
          skipOffstage: false,
        ),
        skipOffstage: false,
      );
      expect(gameWidget, findsOneWidget);
      return (tester.widget(gameWidget) as GameWidget).game as HabitatGame;
    }
  }
  fail('HabitatPage did not finish loading and synchronizing its scene.');
}
