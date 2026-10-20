import 'dart:math' as math;
import 'dart:ui';

/// Free directional chasing, with routes through the actual walkable garden.
class QuintalPlayField {
  QuintalPlayField(
    this.current,
    this.next,
    this.progress,
    this.free,
    this.canTraverse,
  );
  (int, int) current, next;
  double progress;
  final Set<(int, int)> free;
  final bool Function((int, int), (int, int)) canTraverse;
  List<(int, int)> _route = [];
  int direction = 0;
  Offset get position => Offset.lerp(
    Offset(current.$1.toDouble(), current.$2.toDouble()),
    Offset(next.$1.toDouble(), next.$2.toDouble()),
    progress,
  )!;

  void aim(Offset screen, Offset Function(int, int) project) {
    final origin = next;
    final parents = <(int, int), (int, int)?>{origin: null};
    final queue = [origin];
    var best = origin;
    var distance = (project(best.$1, best.$2) - screen).distanceSquared;
    for (var i = 0; i < queue.length; i++) {
      final cell = queue[i];
      final d = (project(cell.$1, cell.$2) - screen).distanceSquared;
      if (d < distance) {
        best = cell;
        distance = d;
      }
      for (final n in [
        (cell.$1 + 1, cell.$2),
        (cell.$1 - 1, cell.$2),
        (cell.$1, cell.$2 + 1),
        (cell.$1, cell.$2 - 1),
      ]) {
        if (free.contains(n) &&
            !parents.containsKey(n) &&
            canTraverse(cell, n)) {
          parents[n] = cell;
          queue.add(n);
        }
      }
    }
    final path = <(int, int)>[];
    for (var cell = best; cell != origin; cell = parents[cell]!) {
      path.add(cell);
    }
    _route = path.reversed.toList();
  }

  void advance(double seconds) {
    var remaining = seconds.clamp(0.0, .25);
    while (remaining > 0) {
      if (current == next) {
        if (_route.isEmpty) return;
        next = _route.removeAt(0);
        progress = 0;
      }
      final dx = next.$1 - current.$1, dy = next.$2 - current.$2;
      direction = dx.abs() >= dy.abs() ? (dx >= 0 ? 3 : 1) : (dy >= 0 ? 0 : 2);
      final used = math.min(remaining, (1 - progress) * .65);
      progress += used / .65;
      remaining -= used;
      if (progress >= .999999) {
        current = next;
        progress = 0;
      }
    }
  }
}
