import 'dart:math' as math;

/// Cosmetic wind; the soil anchor, growth stage and harvest remain authoritative.
double quintalFoliageAngle(
  double elapsed,
  int slot, {
  required bool still,
  required bool sprouted,
}) => still || !sprouted
    ? 0
    : math.sin(elapsed * 1.3 + slot * 1.7) * .012 +
          math.sin(elapsed * .7 + slot) * .003;

/// Only newly published plots clear their remaining construction props.
/// Loading a saved garden or refreshing the same response never replays it.
class QuintalGardenMotion {
  Set<int>? _known;
  final Map<int, double> _started = {};
  void observe(Set<int> slots, double now) {
    if (_known != null) {
      for (final slot in slots.difference(_known!)) {
        _started[slot] = now;
      }
    }
    _known = Set.of(slots);
    _started.removeWhere(
      (slot, at) => !slots.contains(slot) || now - at >= 1.4,
    );
  }

  double clearingOpacity(int slot, double now, {required bool still}) {
    final at = _started[slot];
    if (still || at == null) return 0;
    final t = ((now - at - slot % 4 * .06) / 1.15).clamp(0.0, 1.0);
    return 1 - t * t * (3 - 2 * t);
  }
}
