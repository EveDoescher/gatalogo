import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/game/quintal_garden_motion.dart';

void main() {
  test('saved beds do not animate; confirmed new rows clear once and preserve previous beds', () {
    final motion = QuintalGardenMotion();
    motion.observe({0, 1, 2, 3}, 0);
    expect(motion.clearingOpacity(0, 0, still: false), 0);
    motion.observe({0, 1, 2, 3, 4, 5, 6, 7}, 1);
    expect(motion.clearingOpacity(0, 1, still: false), 0);
    expect(motion.clearingOpacity(4, 1, still: false), 1);
    final halfway = motion.clearingOpacity(4, 1.6, still: false);
    expect(halfway, inExclusiveRange(0, 1));
    motion.observe({0, 1, 2, 3, 4, 5, 6, 7}, 1.6);
    expect(motion.clearingOpacity(4, 1.6, still: false), halfway);
    expect(motion.clearingOpacity(4, 1.6, still: true), 0);
    motion.observe({0, 1, 2, 3, 4, 5, 6, 7}, 2.5);
    expect(motion.clearingOpacity(4, 2.5, still: false), 0);
    motion.observe({0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}, 3);
    expect(motion.clearingOpacity(8, 3, still: false), 1);
    expect(motion.clearingOpacity(7, 3, still: false), 0);
  });
  test('foliage remains subtle and stops for seeds and reduced motion', () {
    final samples = <double>[];
    for (var frame = 0; frame < 360; frame++) {
      final angle = quintalFoliageAngle(
        frame / 60,
        2,
        still: false,
        sprouted: true,
      );
      samples.add(angle);
      expect(angle.abs(), lessThanOrEqualTo(.015));
      expect(
        quintalFoliageAngle(frame / 60, 2, still: true, sprouted: true),
        0,
      );
      expect(
        quintalFoliageAngle(frame / 60, 2, still: false, sprouted: false),
        0,
      );
    }
    expect(samples.any((v) => v > .005), isTrue);
    expect(samples.any((v) => v < -.005), isTrue);
  });
}
