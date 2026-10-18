import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/game/quintal_cooking_motion.dart';

void main() {
  test('lid stays seated in reduced motion and never sinks into the pan', () {
    var moved = false;
    for (var i = 0; i < 600; i++) {
      final t = i / 60;
      final lift = quintalLidLift(t, still: false);
      expect(lift, inInclusiveRange(0, .025));
      expect(quintalLidLift(t, still: true), 0);
      moved |= lift > .02;
    }
    expect(moved, isTrue);
  });
}
