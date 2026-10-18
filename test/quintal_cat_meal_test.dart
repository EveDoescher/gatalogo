import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/services/quintal_cat_meal.dart';
import 'package:catlogue/game/habitat_cat_motion.dart';
import 'package:catlogue/game/habitat_cat_animations.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);
  Map<String, dynamic> care({String kind = 'meal', int level = 3, int? next}) =>
      {
        'recipe': 'garden',
        'portions': 1,
        'served_at': now.toIso8601String(),
        'last_reaction': {
          'kind': kind,
          'at': now.toIso8601String(),
          'event_id': 'meal-1',
          'recipe': 'garden',
          'portions_before': 2,
          'portions_after': 1,
          'preference': level,
          'next_preference': next ?? level,
          'lost': 2,
        },
      };
  test('only recent confirmed quantities can drive the bowl presentation', () {
    final state = care();
    final meal = QuintalCatMeal.fromCare(state)!;
    expect(meal.recent(now), isTrue);
    expect(meal.recent(now.subtract(const Duration(milliseconds: 1))), isFalse);
    expect(meal.recent(now.add(const Duration(seconds: 90))), isFalse);
    expect(meal.canShowPortions(state), isTrue);
    expect(meal.canShowPortions({...state, 'portions': 2}), isFalse);
    expect(meal.canShowPortions({...state, 'recipe': 'basic'}), isFalse);
    expect(
      meal.canShowPortions({
        ...state,
        'served_at': now.add(const Duration(seconds: 1)).toIso8601String(),
      }),
      isFalse,
    );
    (state['last_reaction'] as Map).remove('portions_before');
    expect(QuintalCatMeal.fromCare(state)!.canShowPortions(state), isFalse);
  });
  test('preference and taste change describe the actual reaction', () {
    expect(
      QuintalCatMeal.fromCare(care(level: 1))!.reactionText,
      'Comeu, mas não é fã.',
    );
    expect(
      QuintalCatMeal.fromCare(care(level: 2))!.reactionText,
      'Aceitou a refeição.',
    );
    expect(
      QuintalCatMeal.fromCare(care(level: 3))!.reactionText,
      'Comeu a refeição.',
    );
    expect(
      QuintalCatMeal.fromCare(care(level: 6))!.reactionText,
      'É a favorita!',
    );
    expect(
      QuintalCatMeal.fromCare(care(level: 3, next: 4))!.tasteChange,
      'Gosto mudou de Normal para Gosta.',
    );
    expect(QuintalCatMeal.fromCare(care(level: 5))!.tasteChange, isNull);
    expect(
      QuintalCatMeal.fromCare(care(kind: 'refused'))!.reactionText,
      'Recusou · 2 porções perdidas.',
    );
  });
  test('appetite uses the deadline, including older API fallback, never 90% hunger', () {
    final state = {'last_meal_at': now.toIso8601String(), 'hunger': .95};
    expect(quintalNextAppetite(state), now.add(const Duration(hours: 12)));
    expect(
      quintalAppetiteText(state, now.add(const Duration(hours: 11))),
      startsWith('Próximo apetite às'),
    );
    expect(
      quintalAppetiteText(state, now.add(const Duration(hours: 12))),
      'Pronto para uma refeição',
    );
    expect(quintalAppetiteText({}, now), 'Pronto para uma refeição');
  });
  test('bowl visits face the bowl, keep the anchor and finish with the right reaction', () async {
    for (final action in ['feed', 'drink', 'refuse']) {
      final walk = HabitatCatMotion((2, 4));
      final arrival = walk.goTo('own-bowl', [], action, placement: (4, 4, 0));
      walk.advance(0, Random(1), (_, _) => true);
      expect(await arrival, isTrue);
      expect(walk.direction, 3);
      expect(walk.awaitingConsumption, isTrue);
      walk.finishFeeding(
        reaction: action == 'feed' ? HabitatCatClip.happy : null,
      );
      expect(
        walk.clip,
        action == 'refuse' ? HabitatCatClip.upset : HabitatCatClip.eat,
      );
      walk.advance(3.1, Random(1), (_, _) => true);
      expect(walk.targetItemId, isNull);
      expect(walk.reaction, action == 'feed' ? HabitatCatClip.happy : isNull);
      expect(walk.current, (2, 4));
      expect(walk.anchor, (2, 4));
    }
  });
  test('four atlas orientations face their world directions', () {
    expect(HabitatCatMotion.facing(1, 0), 3);
    expect(HabitatCatMotion.facing(-1, 0), 1);
    expect(HabitatCatMotion.facing(0, 1), 0);
    expect(HabitatCatMotion.facing(0, -1), 2);
  });
  test('interrupting the visit discards the queued celebration', () async {
    final walk = HabitatCatMotion((2, 4));
    final arrival = walk.goTo('own-bowl', [], 'feed');
    walk.advance(0, Random(1), (_, _) => true);
    await arrival;
    walk.finishFeeding(reaction: HabitatCatClip.dance);
    walk.cancelVisit();
    walk.advance(4, Random(1), (_, _) => false);
    expect(walk.reaction, isNull);
  });
}
