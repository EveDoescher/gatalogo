import 'dart:math' as math;

import 'quintal_game_motion.dart';

enum QuintalPlayPhase { watching, chasing, reaching, resting }

/// A short response to the player's movement, never a source of rewards.
class QuintalPlayMotion {
  double position = .5;
  int direction = 3;
  QuintalPlayPhase phase = QuintalPlayPhase.watching;
  double _phaseTime = 0, _movement = 0, _lastTarget = .5;

  double get lift => phase == QuintalPlayPhase.reaching
      ? math.sin((_phaseTime / .48).clamp(0, 1) * math.pi) * 16
      : 0;

  void settle() {
    phase = QuintalPlayPhase.watching;
    _phaseTime = _movement = 0;
  }

  void reset() {
    position = _lastTarget = .5;
    direction = 3;
    phase = QuintalPlayPhase.watching;
    _phaseTime = _movement = 0;
  }

  void advance(double target, double seconds) {
    target = target.clamp(0, 1);
    _movement += (target - _lastTarget).abs();
    _lastTarget = target;
    var remaining = seconds;
    while (remaining > 0) {
      final step = math.min(remaining, 1 / 60);
      remaining -= step;
      _phaseTime += step;
      if (phase == QuintalPlayPhase.reaching) {
        if (_phaseTime >= .48) {
          phase = QuintalPlayPhase.resting;
          _phaseTime = 0;
        }
        continue;
      }
      if (phase == QuintalPlayPhase.resting) {
        if (_phaseTime >= .7) {
          phase = QuintalPlayPhase.watching;
          _phaseTime = 0;
        }
        continue;
      }
      final gap = target - position;
      if (gap.abs() > .035) {
        phase = QuintalPlayPhase.chasing;
        direction = gap > 0 ? 3 : 1;
        position = QuintalGameMotion.follow(position, target, step);
      } else if (_movement >= .12) {
        phase = QuintalPlayPhase.reaching;
        _phaseTime = _movement = 0;
      } else {
        phase = QuintalPlayPhase.watching;
      }
    }
  }
}
