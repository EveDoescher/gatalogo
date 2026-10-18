import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/game/quintal_play_motion.dart';

void main() {
  test('stationary wand does not trigger automatic play', () {
    final cat = QuintalPlayMotion()..advance(.5, 20);
    expect(cat.phase, QuintalPlayPhase.watching);
    expect(cat.position, .5);
    expect(cat.lift, 0);
  });
  test('movement leads to approach, reach and rest without repeated jumps', () {
    final cat = QuintalPlayMotion();
    final phases = <QuintalPlayPhase>{};
    var reaches = 0;
    var previous = cat.phase;
    for (var i = 0; i < 600; i++) {
      cat.advance(.9, 1 / 60);
      phases.add(cat.phase);
      if (cat.phase == QuintalPlayPhase.reaching && previous != cat.phase) {
        reaches++;
      }
      previous = cat.phase;
      expect(cat.lift, inInclusiveRange(0, 16));
    }
    expect(phases, containsAll(QuintalPlayPhase.values));
    expect(reaches, 1);
    expect(cat.position, closeTo(.9, .035));
    cat.advance(.1, .5);
    expect(cat.phase, QuintalPlayPhase.chasing);
    expect(cat.direction, 1);
    cat.reset();
    expect(cat.position, .5);
    expect(cat.phase, QuintalPlayPhase.watching);
  });
}
