part of 'habitat_world.dart';

class HabitatVisitorPose {
  const HabitatVisitorPose(
    this.species,
    this.x,
    this.y,
    this.clip,
    this.direction,
    this.elevation, {
    this.id = '',
    this.routine = '',
    this.tint,
  });
  final String species, clip, id, routine;
  final double x, y, elevation;
  final int direction;
  final int? tint;
  bool get flying =>
      elevation > .3 && (species == 'bee' || species == 'parrot');
}

class _VisitStep {
  const _VisitStep(
    this.from,
    this.to,
    this.seconds,
    this.clip,
    this.fromHeight,
    this.toHeight,
    this.direction,
  );
  final (double, double) from, to;
  final double seconds, fromHeight, toHeight;
  final String clip;
  final int direction;
}

/// A fixed route with timed pauses. No animation or visit can grant a reward.
class HabitatVisit {
  HabitatVisit._(this.species, this.id, this.routine, this._steps, {this.tint});
  final String species, id, routine;
  final List<_VisitStep> _steps;
  final int? tint;
  double get duration => _steps.fold(0.0, (sum, step) => sum + step.seconds);
  HabitatVisitorPose? poseAt(double age) {
    if (age < 0) return null;
    for (final step in _steps) {
      if (age >= step.seconds) {
        age -= step.seconds;
        continue;
      }
      final t = age / step.seconds;
      return HabitatVisitorPose(
        species,
        step.from.$1 + (step.to.$1 - step.from.$1) * t,
        step.from.$2 + (step.to.$2 - step.from.$2) * t,
        step.clip,
        step.direction,
        step.fromHeight + (step.toHeight - step.fromHeight) * t,
        id: id,
        routine: routine,
        tint: tint,
      );
    }
    return null;
  }
}

int _visitDirection((double, double) a, (double, double) b) {
  final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
  return dy.abs() >= dx.abs() ? (dy >= 0 ? 0 : 2) : (dx < 0 ? 1 : 3);
}

extension _VisitPlanning on HabitatWorld {
  bool _clearForVisitor((int, int) cell) {
    if (editable.contains(cell) || isRiverCell(cell.$1, cell.$2)) return false;
    if (isVisitorCorridor(cell.$1, cell.$2)) return true;
    if (isProductionCell(cell.$1, cell.$2)) return false;
    for (final prop in decorationsWithin(
      cell.$1 - 2,
      cell.$2 - 2,
      cell.$1 + 2,
      cell.$2 + 2,
    )) {
      final jitter = decorationOffset(prop.$1, prop.$2);
      final radius = decorationRadius(prop.$3, prop.$4) + .32;
      if ((prop.$1 + jitter.$1 - cell.$1).abs() < radius &&
          (prop.$2 + jitter.$2 - cell.$2).abs() < radius) {
        return false;
      }
    }
    return true;
  }

  List<(double, double)> _walkPath((int, int) start, (int, int) end) {
    if (start == end) return [(start.$1.toDouble(), start.$2.toDouble())];
    final previous = <(int, int), (int, int)?>{start: null};
    final queue = [start];
    final minX = math.min(start.$1, end.$1) - 4,
        maxX = math.max(start.$1, end.$1) + 4;
    final minY = math.min(start.$2, end.$2) - 4,
        maxY = math.max(start.$2, end.$2) + 4;
    for (var index = 0; index < queue.length; index++) {
      final cell = queue[index];
      if (cell == end) break;
      final neighbors =
          [
            (cell.$1 + 1, cell.$2),
            (cell.$1 - 1, cell.$2),
            (cell.$1, cell.$2 + 1),
            (cell.$1, cell.$2 - 1),
          ]..sort(
            (a, b) => ((a.$1 - end.$1).abs() + (a.$2 - end.$2).abs()).compareTo(
              (b.$1 - end.$1).abs() + (b.$2 - end.$2).abs(),
            ),
          );
      for (final next in neighbors) {
        if (previous.containsKey(next) ||
            next.$1 < minX ||
            next.$1 > maxX ||
            next.$2 < minY ||
            next.$2 > maxY ||
            !_clearForVisitor(next)) {
          continue;
        }
        previous[next] = cell;
        queue.add(next);
      }
    }
    if (!previous.containsKey(end)) return [];
    final path = <(double, double)>[];
    (int, int)? current = end;
    while (current != null) {
      path.add((current.$1.toDouble(), current.$2.toDouble()));
      current = previous[current];
    }
    return path.reversed.toList();
  }

  HabitatVisit _makeVisit(
    int lane,
    int cycle,
    (double, double, double, double) bounds,
  ) {
    final roll = _random(lane + seed, cycle, 113);
    const species = ['dog', 'bunny', 'chick', 'deer', 'fox', 'beaver'];
    final kind = lane < 3
        ? species[(cycle * 3 + lane + seed) % species.length]
        : lane == 3
        ? 'bee'
        : lane == 4
        ? 'parrot'
        : 'fish';
    final id = '$lane:$cycle';
    if (lane == 1 && roll > .72 || lane == 2 && roll > .62) {
      return HabitatVisit._(kind, id, 'absent', []);
    }
    final north = roll < .5;
    final firstY = bounds.$2.floor() - 3, lastY = bounds.$4.ceil() + 3;
    final steps = <_VisitStep>[];
    void route(
      List<(double, double)> points,
      double speed, {
      double height = 0,
    }) {
      for (var i = 1; i < points.length; i++) {
        final a = points[i - 1], b = points[i];
        final distance = math.sqrt(
          math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2),
        );
        if (distance == 0) continue;
        steps.add(
          _VisitStep(
            a,
            b,
            distance / speed,
            'walk',
            height,
            height,
            _visitDirection(a, b),
          ),
        );
      }
    }

    if (lane == 5) {
      final ys = [for (var y = firstY; y <= lastY; y++) y];
      if (!north) ys.sort((a, b) => b.compareTo(a));
      route([
        for (final y in ys)
          (
            riverColumns(y).reduce((a, b) => a + b) / riverColumns(y).length,
            y.toDouble(),
          ),
      ], .8);
      return HabitatVisit._(kind, id, 'swim', steps);
    }
    if (lane >= 3) {
      final start = north
          ? (bounds.$1 - 4, top - 3.0)
          : (bounds.$3 + 4, bottom + 3.0);
      final end = north
          ? (bounds.$3 + 4, bottom + 3.0)
          : (bounds.$1 - 4, top - 3.0);
      final site = lane == 3
          ? (right + 2.0, top + 2.0)
          : (right + 2.0, bottom - 2.0);
      final cruise = lane == 3 ? 1.7 : 2.5;
      final perch = lane == 3 ? .65 : .08;
      final midpoint = ((start.$1 + site.$1) / 2, (start.$2 + site.$2) / 2);
      route([start, midpoint], 1.0, height: cruise);
      final approach = math.sqrt(
        math.pow(site.$1 - midpoint.$1, 2) + math.pow(site.$2 - midpoint.$2, 2),
      );
      steps.add(
        _VisitStep(
          midpoint,
          site,
          math.max(2, approach),
          'walk',
          cruise,
          perch,
          _visitDirection(midpoint, site),
        ),
      );
      steps.add(
        _VisitStep(
          site,
          site,
          lane == 3 ? 4 : 7,
          lane == 3 ? 'walk' : 'idle',
          perch,
          perch,
          1,
        ),
      );
      final away = ((end.$1 + site.$1) / 2, (end.$2 + site.$2) / 2);
      final leaving = math.sqrt(
        math.pow(away.$1 - site.$1, 2) + math.pow(away.$2 - site.$2, 2),
      );
      steps.add(
        _VisitStep(
          site,
          away,
          math.max(2, leaving),
          'walk',
          perch,
          cruise,
          _visitDirection(site, away),
        ),
      );
      route([away, end], 1.0, height: cruise);
      return HabitatVisit._(
        kind,
        id,
        lane == 3 ? 'pollinate' : 'land_and_watch',
        steps,
        tint: lane == 4 ? [null, 0xFFE5E8AC, 0xFFB4D8EA][cycle % 3] : null,
      );
    }
    final x = lane == 0
        ? left - 2
        : lane == 1
        ? left - 7
        : right + 2;
    final start = (x, north ? firstY : lastY),
        end = (x, north ? lastY : firstY);
    final site = (x, top + 2 + (cycle % 3));
    final speed = kind == 'bunny'
        ? .9
        : kind == 'deer'
        ? .62
        : .75;
    route(_walkPath(start, site), speed);
    final routine = lane == 2
        ? 'watch_cats'
        : kind == 'beaver'
        ? 'drink'
        : [
            'drink',
            'forage',
            'wander',
            'rest',
            'watch_cats',
          ][(cycle + lane + seed) % 5];
    var current = site;
    if (routine == 'drink') {
      final columns = riverColumns(site.$2).toList();
      final bank = (lane == 1 ? columns.first - 1 : columns.last + 1, site.$2);
      route(_walkPath(site, bank), speed);
      steps.add(
        _VisitStep(
          (bank.$1.toDouble(), bank.$2.toDouble()),
          (bank.$1.toDouble(), bank.$2.toDouble()),
          5,
          'eat',
          0,
          0,
          lane == 1 ? 3 : 1,
        ),
      );
      route(_walkPath(bank, site), speed);
    } else {
      final pos = (site.$1.toDouble(), site.$2.toDouble());
      steps.add(
        _VisitStep(
          pos,
          pos,
          6,
          routine == 'forage' ? 'eat' : 'idle',
          0,
          0,
          lane == 2 ? 1 : 3,
        ),
      );
      if (routine == 'wander' || kind == 'bunny' && routine == 'rest') {
        final turn = (x, site.$2 + 3);
        route(_walkPath(site, turn), speed);
        current = turn;
        final point = (turn.$1.toDouble(), turn.$2.toDouble());
        steps.add(
          _VisitStep(
            point,
            point,
            3,
            kind == 'bunny' ? 'play' : 'idle',
            0,
            0,
            2,
          ),
        );
      }
    }
    route(_walkPath(current, end), speed);
    return HabitatVisit._(kind, id, routine, steps);
  }
}

extension HabitatDeliveryPlanning on HabitatWorld {
  HabitatVisit deliveryVisit(
    (double, double, double, double) bounds,
    String species,
    int seed,
  ) {
    final fromNorth = seed.isEven;
    final start = (
      right + 2,
      fromNorth ? bounds.$2.floor() - 3 : bounds.$4.ceil() + 3,
    );
    final site = (right + 2, giftCell.$2 + (fromNorth ? -3 : 3));
    final points =
        _walkPath(start, site) + _walkPath(site, giftCell).skip(1).toList();
    final height = species == 'bee'
        ? 1.3
        : species == 'parrot'
        ? 2.1
        : 0.0;
    final steps = <_VisitStep>[];
    if (points.length < 2) {
      return HabitatVisit._(species, 'courier', 'delivery', []);
    }
    final total = points.length - 1;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      steps.add(
        _VisitStep(
          a,
          b,
          18 / total,
          'walk',
          height,
          height,
          _visitDirection(a, b),
        ),
      );
      if (b.$1 == site.$1 && b.$2 == site.$2) {
        steps.add(
          _VisitStep(
            b,
            b,
            4,
            species == 'bee'
                ? 'walk'
                : species == 'parrot'
                ? 'idle'
                : 'eat',
            height,
            height,
            1,
          ),
        );
      }
    }
    return HabitatVisit._(species, 'courier', 'delivery', steps);
  }

  HabitatVisit departureVisit(
    (double, double, double, double) bounds,
    String species,
    int seed,
  ) {
    final end = (
      right + 2,
      seed.isEven ? bounds.$4.ceil() + 4 : bounds.$2.floor() - 4,
    );
    final points = _walkPath(giftCell, end);
    final height = species == 'bee'
        ? 1.3
        : species == 'parrot'
        ? 2.1
        : 0.0;
    return HabitatVisit._(species, 'courier', 'departure', [
      for (var i = 1; i < points.length; i++)
        _VisitStep(
          points[i - 1],
          points[i],
          1.15,
          'walk',
          height,
          height,
          _visitDirection(points[i - 1], points[i]),
        ),
    ]);
  }
}
