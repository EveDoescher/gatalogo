import 'dart:ui' show SemanticsAction;

import 'package:catlogue/widgets/milestone_widgets.dart';
import 'package:catlogue/widgets/quintal_game_action.dart';
import 'package:catlogue/widgets/quintal_hold_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Widget app(Widget child, bool reduced) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final reduced in [false, true]) {
    testWidgets('ACC05/06 yard action reduced=$reduced', (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      var calls = 0;
      await tester.pumpWidget(
        app(
          QuintalGameAction(
            artwork: const SizedBox(),
            label: 'Coletar',
            onPressed: () => calls++,
          ),
          reduced,
        ),
      );
      final animation = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(
        animation.duration,
        reduced ? Duration.zero : const Duration(milliseconds: 90),
      );
      final node = tester.getSemantics(find.byType(QuintalGameAction));
      expect(node.getSemanticsData().label, 'Coletar');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(calls, 1);
    });
    testWidgets('ACC05/06 hold toggle reduced=$reduced', (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      bool? changed;
      await tester.pumpWidget(
        app(
          QuintalHoldControl(
            held: false,
            onChanged: (value) => changed = value,
          ),
          reduced,
        ),
      );
      final animation = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(
        animation.duration,
        reduced ? Duration.zero : const Duration(milliseconds: 90),
      );
      final node = tester.getSemantics(find.byType(QuintalHoldControl));
      expect(node.getSemanticsData().value, 'Descendo');
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(changed, isTrue);
    });
    testWidgets('ACC06 celebration preserves content reduced=$reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const AchievementPresentation(
            celebration: true,
            goal: {
              'title': 'Primeiro encontro',
              'completed': true,
              'xp_reward': 10,
              'coin_reward': 5,
            },
          ),
          reduced,
        ),
      );
      final animation = tester.widget<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>),
      );
      expect(
        animation.duration,
        reduced ? Duration.zero : const Duration(milliseconds: 1100),
      );
      await tester.pumpAndSettle();
      expect(find.text('Uma conquista para guardar!'), findsOneWidget);
      expect(find.text('Primeiro encontro'), findsOneWidget);
      expect(find.byTooltip('Fechar conquista'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
