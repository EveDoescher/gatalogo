import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/widgets/quintal_fishing_arena.dart';

void main() {
  testWidgets('catch zone and fish use the same center at both extremes', (
    tester,
  ) async {
    for (final position in [0.0, .5, 1.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 250,
              height: 320,
              child: QuintalFishingArena(
                fish: position,
                position: position,
                zone: .3,
              ),
            ),
          ),
        ),
      );
      final fish = tester.getCenter(find.byKey(const ValueKey('fishing-fish')));
      final zone = tester.getCenter(find.byKey(const ValueKey('fishing-zone')));
      expect(fish.dy, closeTo(zone.dy, .001));
      expect(find.text('Na faixa!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          height: 320,
          child: QuintalFishingArena(fish: .9, position: .1, zone: .3),
        ),
      ),
    );
    expect(find.text('Aproxime a faixa do peixe'), findsOneWidget);
  });
}
