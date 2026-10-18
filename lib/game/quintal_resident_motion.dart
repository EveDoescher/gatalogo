import 'dart:collection';
import 'dart:math' as math;

/// Pauses one resident without jumping ahead on its route after the action.
class QuintalResidentTimeline {
  double _paused = 0;
  double? _start;
  double _duration = 0;

  void synchronizeAtRest() {
    if (_start == null) _paused = 0;
  }

  void pause(double now, double duration) {
    time(now);
    if (_start != null) return;
    _start = now;
    _duration = duration;
  }

  double time(double now) {
    final start = _start;
    if (start == null) return now - _paused;
    final elapsed = (now - start).clamp(0.0, _duration);
    if (elapsed >= _duration) {
      _paused += _duration;
      _start = null;
      return now - _paused;
    }
    return now - _paused - elapsed;
  }
}

/// Routes use the paddock and its gate, clear of shelter, nest and troughs.
/// Every path is closed. Rest/eat phases hold the previous endpoint.
class QuintalResidentPose {
  const QuintalResidentPose(
    this.x,
    this.y,
    this.direction,
    this.clip, {
    this.elevation = 0,
    this.sheltered = false,
    this.gatePassage = false,
    this.actionTime = 0,
  });
  final double x, y;
  final int direction;
  final String clip;
  final double elevation;
  final bool sheltered;
  final bool gatePassage;
  final double actionTime;
}

typedef _Cell = (int, int);
typedef _Stop = ({double x, double y, String activity});

// Coordinates are relative to the production area, in the same world units
// as the building, nest, ramp and trough meshes (including body clearance).
List<(double, double)> quintalResidentHomes(String kind) => kind == 'pasture'
    ? [(2.2, 2.8), (1.6, 4.4)]
    : [(1.8, 2.4), (1.2, 4.6), (2.6, 4.4), (3.8, 2.6)];

double quintalShelterDoor(String kind, int level) =>
    .55 + (kind == 'pasture' ? .7 : .56 + (level.clamp(1, 2) - 1) * .54);

double quintalShelterElevation(String kind, int level, double x, double y) {
  if ((x - .8).abs() > .01) return 0;
  final front = quintalShelterDoor(kind, level);
  final ramp = kind == 'pasture' ? .22 : .73;
  final floor = kind == 'pasture' ? .15 : .36;
  return ((front + ramp - y) / ramp).clamp(0, 1) * floor;
}

bool quintalResidentGroundClear(
  String kind,
  double x,
  double y, {
  int level = 2,
}) {
  final front = quintalShelterDoor(kind, level);
  // The door is the only traversable column through the building footprint.
  if ((x - .8).abs() < .01 && y >= front - .55 && y <= 2.8) return true;
  final cow = kind == 'pasture';
  // A single straight exit crosses the NW gate at x=-.5, y=3.
  // The wider inside approach gives the body clearance before the turn.
  if (x < .6) {
    return x >= -1.2 && (y - 3).abs() <= (x >= 0 ? .800001 : .01);
  }
  if (x > (cow ? 5.4 : 4.6) || y < .6 || y > 4.6) return false;
  if (x < (cow ? 2.5 : 2.65) && y < (cow ? 2.1 : 2.0)) return false;
  if (!cow && x < 1.4 && y < 2.65) return false; // Coop ramp.
  final troughX = cow ? 5.5 : 4.5;
  final clearance = cow ? .9 : .65;
  for (final troughY in [1.0, 4.6]) {
    if (math.sqrt(math.pow(x - troughX, 2) + math.pow(y - troughY, 2)) <
        clearance) {
      return false;
    }
  }
  return true;
}

const quintalResidentSlotSeconds = 240;

/// Open before the body reaches the gate and hold it until the body clears it.
double quintalGateOpening(Iterable<QuintalResidentPose> residents) {
  var opening = 0.0;
  for (final pose in residents) {
    if (!pose.gatePassage || (pose.y - 3).abs() > .8) continue;
    opening = math.max(opening, ((1.5 - (pose.x + .5).abs()) / .6).clamp(0, 1));
  }
  return opening;
}

final _residentRoutes = <String, List<_Stop>>{};
List<_Stop> _residentRoute(String kind, int slot, int level) =>
    _residentRoutes.putIfAbsent('$kind:$slot:$level', () {
      final homes = quintalResidentHomes(kind), home = homes[slot];
      final cow = kind == 'pasture';
      final approachX = cow ? 4.4 : 3.8;
      final destinations = [
        home,
        (approachX, 1.0),
        (approachX, 4.6),
        (-1.2, 3.0),
        (.8, 2.8),
        home,
      ];
      final route = <_Stop>[(x: home.$1, y: home.$2, activity: 'rest')];
      for (var leg = 1; leg < destinations.length; leg++) {
        final start = (
          (destinations[leg - 1].$1 * 5).round(),
          (destinations[leg - 1].$2 * 5).round(),
        );
        final end = (
          (destinations[leg].$1 * 5).round(),
          (destinations[leg].$2 * 5).round(),
        );
        final previous = <_Cell, _Cell?>{start: null};
        final queue = Queue<_Cell>()..add(start);
        while (queue.isNotEmpty && !previous.containsKey(end)) {
          final p = queue.removeFirst();
          for (final next in [
            (p.$1 + 1, p.$2),
            (p.$1, p.$2 + 1),
            (p.$1 - 1, p.$2),
            (p.$1, p.$2 - 1),
          ]) {
            if (previous.containsKey(next)) continue;
            final x = next.$1 / 5, y = next.$2 / 5;
            if (!quintalResidentGroundClear(kind, x, y, level: level)) continue;
            if (homes.indexed.any(
              (h) =>
                  h.$1 != slot &&
                  math.sqrt(
                        math.pow(x - h.$2.$1, 2) + math.pow(y - h.$2.$2, 2),
                      ) <
                      (cow ? 1.4 : .9),
            )) {
              continue;
            }
            previous[next] = p;
            queue.add(next);
          }
        }
        if (!previous.containsKey(end)) {
          throw StateError('No resident route: $kind/$slot/$leg');
        }
        final path = <_Cell>[];
        for (_Cell? cell = end; cell != start; cell = previous[cell]) {
          path.add(cell!);
        }
        for (final cell in path.reversed) {
          route.add((
            x: cell.$1 / 5,
            y: cell.$2 / 5,
            activity: leg == 3 || leg == 4 ? 'walk_gate' : 'walk',
          ));
        }
        if (leg == 4) {
          final inside = quintalShelterDoor(kind, level) - .55;
          route.add((x: .8, y: inside, activity: 'walk'));
          route.add((x: .8, y: inside, activity: 'shelter'));
          route.add((x: .8, y: 2.8, activity: 'walk'));
        }
        final point = route.last;
        route.add((
          x: point.x,
          y: point.y,
          activity: leg == 1
              ? 'food'
              : leg == 2
              ? 'water'
              : leg == destinations.length - 1 && !cow
              ? 'scratch'
              : 'rest',
        ));
      }
      return route;
    });

QuintalResidentPose quintalResidentPose(
  String kind,
  int slot,
  double time, {
  bool fed = false,
  bool watered = false,
  bool still = false,
  int level = 2,
}) {
  final homes = quintalResidentHomes(kind), home = homes[slot];
  var elapsed =
      time % (homes.length * quintalResidentSlotSeconds) -
      slot * quintalResidentSlotSeconds;
  if (still || elapsed < 0 || elapsed >= quintalResidentSlotSeconds) {
    return QuintalResidentPose(home.$1, home.$2, 0, 'idle');
  }
  QuintalResidentPose pose(
    double x,
    double y,
    int direction,
    String clip, {
    bool gate = false,
    double actionTime = 0,
  }) => QuintalResidentPose(
    x,
    y,
    direction,
    clip,
    elevation: quintalShelterElevation(kind, level, x, y),
    sheltered: (x - .8).abs() < .01 && y < quintalShelterDoor(kind, level),
    gatePassage: gate,
    actionTime: actionTime,
  );
  final route = _residentRoute(kind, slot, level);
  for (var i = 1; i < route.length; i++) {
    final a = route[i - 1], b = route[i];
    final dx = b.x - a.x, dy = b.y - a.y;
    final walking = b.activity.startsWith('walk');
    final duration = walking
        ? math.sqrt(dx * dx + dy * dy) / .18
        : b.activity == 'shelter'
        ? 14.0
        : 6.0;
    if (elapsed < duration) {
      if (!walking) {
        return pose(
          b.x +
              (b.activity == 'scratch'
                  ? .02 * math.sin(elapsed * math.pi * 2)
                  : 0),
          b.y,
          b.activity == 'shelter' ? 0 : 3,
          (b.activity == 'food' && fed || b.activity == 'water' && watered)
              ? 'eat'
              : b.activity == 'scratch'
              ? 'scratch'
              : 'idle',
          gate: b.x < -.5 && (b.y - 3).abs() < .01,
          actionTime: elapsed,
        );
      }
      final f = elapsed / duration;
      return pose(
        a.x + dx * f,
        a.y + dy * f,
        dx.abs() > dy.abs() ? (dx > 0 ? 3 : 1) : (dy > 0 ? 0 : 2),
        'walk',
        gate: b.activity == 'walk_gate',
      );
    }
    elapsed -= duration;
  }
  return QuintalResidentPose(home.$1, home.$2, 0, 'idle');
}
