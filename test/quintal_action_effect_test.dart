import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/game/quintal_action_effect.dart';
import 'package:catlogue/game/quintal_scene_target.dart';

void main() {
  test('water and food tools match the recipient and return before expiry', () {
    for (final (kind, action, tool) in [
      ('cat', 'water_cat', 'watering-can'),
      ('garden', 'water_crop', 'watering-can'),
      ('coop', 'water_residents', 'watering-can'),
      ('cat', 'serve', 'feed-scoop'),
      ('coop', 'feed_residents', 'feed-scoop'),
      ('pasture', 'feed_residents', 'hay-fork'),
    ]) {
      final effect = QuintalActionEffect(
        QuintalSceneTarget(kind, '0', 'food', 0, 0),
        action,
        10,
      );
      expect(effect.toolKind, tool);
      expect(effect.toolStage(10, reducedMotion: false), 0);
      expect(effect.toolStage(10.5, reducedMotion: false), 4);
      expect(effect.toolStage(11.34, reducedMotion: false), 0);
      expect(effect.toolOpacity(10), 0);
      expect(effect.toolOpacity(10.5), 1);
      expect(effect.toolOpacity(11.36), 0);
      for (var i = 0; i < 135; i++) {
        final now = 10 + i / 100;
        expect(
          effect.toolStage(now, reducedMotion: false),
          inInclusiveRange(0, 4),
        );
        expect(effect.toolStage(now, reducedMotion: true), 0);
      }
    }
    expect(
      QuintalActionEffect(
        const QuintalSceneTarget('coop', '0', 'collect', 0, 0),
        'collect_residents',
        0,
      ).toolKind,
      isNull,
    );
  });

  test('harvest lifts above the soil continuously, fades and expires', () {
    final effect = QuintalActionEffect(
      const QuintalSceneTarget('garden', '0', 'plot', 2, 3, crop: 'carrot'),
      'harvest',
      10,
    );
    expect(effect.isHarvest, isTrue);
    expect(effect.harvestLift(10, reducedMotion: false), 0);
    var previous = 0.0;
    for (var i = 0; i <= 135; i++) {
      final now = 10 + i / 100;
      final lift = effect.harvestLift(now, reducedMotion: false);
      expect(lift, inInclusiveRange(previous, .75));
      expect(lift - previous, lessThan(.03));
      expect(effect.harvestLift(now, reducedMotion: true), 0);
      expect(effect.harvestOpacity(now), inInclusiveRange(0, 1));
      previous = lift;
    }
    expect(effect.harvestLift(10.85, reducedMotion: false), greaterThan(.53));
    expect(effect.harvestOpacity(10.85), 1);
    expect(effect.harvestOpacity(11.35), closeTo(0, .00001));
    expect(effect.expired(11.36), isTrue);
  });
  test('only a known crop snapshot creates a harvested plant', () {
    for (final crop in [
      'corn',
      'wheat',
      'carrot',
      'turnip',
      'pumpkin',
      'melon',
    ]) {
      expect(
        QuintalActionEffect(
          QuintalSceneTarget('garden', '0', 'plot', 0, 0, crop: crop),
          'harvest',
          0,
        ).isHarvest,
        isTrue,
      );
    }
    expect(
      QuintalActionEffect(
        const QuintalSceneTarget('garden', '0', 'plot', 0, 0),
        'harvest',
        0,
      ).isHarvest,
      isFalse,
    );
  });
}
