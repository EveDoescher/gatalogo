import 'dart:ui';

/// A short contiguous lane, using the world's existing traversal rules.
class QuintalPlayLane {
  QuintalPlayLane._(this.cells, this.origin);
  final List<(int, int)> cells;
  final double origin;

  factory QuintalPlayLane.build({
    required (int, int) current,
    required (int, int) next,
    required double progress,
    required Set<(int, int)> free,
    required bool Function((int, int), (int, int)) canTraverse,
  }) {
    List<(int, int)> extend((int, int) start, (int, int) step) {
      final result = <(int, int)>[];
      var previous = start;
      for (var i = 0; i < 2; i++) {
        final candidate = (previous.$1 + step.$1, previous.$2 + step.$2);
        if (!free.contains(candidate) || !canTraverse(previous, candidate)) {
          break;
        }
        result.add(candidate);
        previous = candidate;
      }
      return result;
    }

    var step = (next.$1 - current.$1, next.$2 - current.$2);
    final moving =
        current != next && free.contains(next) && canTraverse(current, next);
    if (!moving) {
      final x =
          extend(current, (1, 0)).length + extend(current, (-1, 0)).length;
      final y =
          extend(current, (0, 1)).length + extend(current, (0, -1)).length;
      step = x >= y ? (1, 0) : (0, -1);
    }
    final left = extend(current, (-step.$1, -step.$2));
    final right = extend(moving ? next : current, step);
    var cells = [...left.reversed, current, if (moving) next, ...right];
    var origin = left.length + (moving ? progress.clamp(0.0, 1.0) : 0.0);
    if (step.$1 - step.$2 < 0) {
      cells = cells.reversed.toList();
      origin = cells.length - 1 - origin;
    }
    return QuintalPlayLane._(cells, origin);
  }

  ({(int, int) from, (int, int) to, double fraction}) sample(double value) {
    value = value.clamp(0, 1);
    final index = value <= .5
        ? origin * value * 2
        : origin + (cells.length - 1 - origin) * (value - .5) * 2;
    final lower = index.floor().clamp(0, cells.length - 1);
    final upper = (lower + 1).clamp(0, cells.length - 1);
    return (from: cells[lower], to: cells[upper], fraction: index - lower);
  }

  Offset position(double value) {
    final point = sample(value);
    return Offset.lerp(
      Offset(point.from.$1.toDouble(), point.from.$2.toDouble()),
      Offset(point.to.$1.toDouble(), point.to.$2.toDouble()),
      point.fraction,
    )!;
  }
}
