import 'dart:math' as math;

/// Positions depend on elapsed active time, not on timer callback frequency.
abstract final class QuintalGameMotion {
  static double fishing(double position, bool held, double seconds) =>
      (position + (held ? -.012 : .008) * seconds / .033).clamp(0, 1);

  static double follow(double position, double target, double seconds) =>
      position + (target - position) * (1 - math.pow(.955, seconds / .033));
}
