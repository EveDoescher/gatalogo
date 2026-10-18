import 'dart:math' as math;

part 'habitat_visits.dart';

/// Environmental layout is derived from today's boundary, including future plots.
class HabitatWorld {
  HabitatWorld(
    Set<(int, int)> cells, {
    this.seed = 0,
    this.productionEnabled = false,
  }) : left = cells.map((cell) => cell.$1).reduce(math.min),
       right = cells.map((cell) => cell.$1).reduce(math.max),
       top = cells.map((cell) => cell.$2).reduce(math.min),
       bottom = cells.map((cell) => cell.$2).reduce(math.max),
       editable = cells;
  final int left, right, top, bottom;
  final int seed;
  final bool productionEnabled;
  final Map<(int, int), HabitatVisit> _visits = {};
  final Set<(int, int)> editable;
  (int, int) get giftCell => (right + 2, bottom - 2);
  int riverX(int y) => left - 4 + ((y - top).abs() ~/ 6 % 2);
  Iterable<(int, int)> get river => riverBetween(top - 8, bottom + 8);

  Iterable<(int, int)> riverBetween(int first, int last) sync* {
    for (var y = first; y <= last; y++) {
      for (final x in riverColumns(y)) {
        yield (x, y);
      }
    }
  }

  /// Fill both rows around a bend: a broad elbow, not a single-cell diagonal neck.
  Iterable<int> riverColumns(int y) sync* {
    final current = riverX(y), previous = riverX(y - 1), next = riverX(y + 1);
    for (
      var x = math.min(math.min(current, previous), next) - 1;
      x <= math.max(math.max(current, previous), next);
      x++
    ) {
      yield x;
    }
  }

  bool isRiverCell(int x, int y) => riverColumns(y).contains(x);
  Map<String, (int, int, int, int)> get productionAreas => {
    'garden': (right + 3, top, 6, 5),
    'coop': (right + 3, top + 6, 6, 6),
    'pasture': (right + 3, top + 14, 7, 6),
    'kitchen': (right + 10, top, 4, 4),
    'market': (right + 11, top + 6, 4, 4),
    'orchard': (right + 12, top + 12, 5, 6),
    'pier': (riverX(top + 4), top + 4, 2, 2),
  };

  /// Connected service paths. Entrances share their coordinates with the gates.
  late final Set<(int, int)> productionPaths = {
    for (var y = top; y <= top + 18; y++) (right + 2, y),
    for (var x = right + 2; x <= right + 11; x++) (x, top + 5),
    for (var y = top + 3; y <= top + 5; y++) (right + 11, y),
    for (var x = right + 2; x <= right + 11; x++) (x, top + 12),
    for (var y = top + 10; y <= top + 12; y++) (right + 11, y),
    for (var x = right + 2; x <= right + 13; x++) (x, top + 21),
    for (var y = top + 18; y <= top + 21; y++) (right + 2, y),
    for (var y = top + 18; y <= top + 21; y++) (right + 13, y),
    (right + 3, top + 9),
    (right + 3, top + 17),
  };
  bool isProductionCell(int x, int y) =>
      productionEnabled &&
      (productionPaths.any(
            (p) => (p.$1 - x).abs() <= 1 && (p.$2 - y).abs() <= 1,
          ) ||
          productionAreas.values.any(
            (r) =>
                x >= r.$1 - 1 &&
                x <= r.$1 + r.$3 &&
                y >= r.$2 - 1 &&
                y <= r.$2 + r.$4,
          ));

  static const scenerySprites = [
    'plant_bushSmall_NE',
    'plant_flatShort_NE',
    'plant_flatTall_NE',
    'plant_bushLarge_NE',
    'plant_bushDetailed_NE',
    'plant_bushTriangle_NE',
    'grass_NE',
    'grass_large_NE',
    'grass_leafs_NE',
    'flower_purpleA_NE',
    'flower_yellowA_NE',
    'flower_redA_NE',
    'mushroom_tanGroup_NE',
    'mushroom_redGroup_NE',
    'rock_smallA_NE',
    'rock_smallB_NE',
    'rock_smallC_NE',
    'rock_smallFlatA_NE',
    'rock_largeA_NE',
    'rock_largeC_NE',
    'rock_tallA_NE',
    'tree_default_NE',
    'tree_default_dark_NE',
    'tree_oak_NE',
    'tree_detailed_NE',
    'tree_pineDefaultA_NE',
    'tree_pineRoundC_NE',
    'tree_pineSmallA_NE',
    'tree_small_NE',
    'tree_small_fall_NE',
    'stump_roundDetailed_NE',
    'log_large_NE',
  ];

  // Generate only camera-visible chunks; revisiting a place preserves its layout.
  final Map<(int, int), List<(int, int, String, double)>> _chunks = {};
  Iterable<(int, int, String, double)> get decorations =>
      decorationsWithin(left - 8, top - 8, right + 8, bottom + 8);

  Iterable<(int, int, String, double)> decorationsWithin(
    int firstX,
    int firstY,
    int lastX,
    int lastY,
  ) sync* {
    for (var cx = (firstX / 8).floor(); cx <= (lastX / 8).floor(); cx++) {
      for (var cy = (firstY / 8).floor(); cy <= (lastY / 8).floor(); cy++) {
        final key = (cx, cy);
        final chunk = _chunks.putIfAbsent(key, () => _decorateChunk(cx, cy));
        for (final prop in chunk) {
          if (isProductionCell(prop.$1, prop.$2)) continue;
          if (prop.$1 >= firstX &&
              prop.$1 <= lastX &&
              prop.$2 >= firstY &&
              prop.$2 <= lastY) {
            yield prop;
          }
        }
      }
    }
    // Bound memory on very wide windows and repeated viewport resizing.
    while (_chunks.length > 256) {
      _chunks.remove(_chunks.keys.first);
    }
  }

  double _random(int x, int y, int salt) =>
      (((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) & 0x7fffffff) %
      10007 /
      10006;

  double _patch(double x, double y, int salt) {
    final ix = x.floor(), iy = y.floor();
    final fx = x - ix, fy = y - iy;
    final sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
    final a = _random(ix, iy, salt) * (1 - sx) + _random(ix + 1, iy, salt) * sx;
    final b =
        _random(ix, iy + 1, salt) * (1 - sx) +
        _random(ix + 1, iy + 1, salt) * sx;
    return a * (1 - sy) + b * sy;
  }

  (double, double) decorationOffset(int x, int y) =>
      ((_random(x, y, 13) - .5) * .58, (_random(x, y, 19) - .5) * .58);

  final Map<(int, int), List<(int, int, String, double)>> _proposals = {};
  bool isSolidDecoration(String key) =>
      ['tree_', 'rock_', 'stump_', 'log_'].any(key.startsWith);

  List<(int, int, String, double)> _decorateChunk(int cx, int cy) {
    final neighbors = <(int, int, String, double)>[];
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final key = (cx + dx, cy + dy);
        neighbors.addAll(
          _proposals.putIfAbsent(key, () => _candidatesInChunk(key.$1, key.$2)),
        );
      }
    }
    // Floor division is required on the negative half of the scene.
    final props = neighbors
        .where((p) => (p.$1 / 8).floor() == cx && (p.$2 / 8).floor() == cy)
        .toList();
    final result = props.where((p) {
      if (!isSolidDecoration(p.$3)) return true;
      final a = decorationOffset(p.$1, p.$2);
      final radius = decorationRadius(p.$3, p.$4);
      final priority = _random(p.$1, p.$2, 101);
      for (final other in neighbors) {
        if (identical(p, other) ||
            p.$1 == other.$1 && p.$2 == other.$2 ||
            !isSolidDecoration(other.$3)) {
          continue;
        }
        final rank = _random(other.$1, other.$2, 101);
        if (rank < priority ||
            rank == priority &&
                (other.$1 < p.$1 || other.$1 == p.$1 && other.$2 < p.$2)) {
          continue;
        }
        final b = decorationOffset(other.$1, other.$2);
        final dx = p.$1 + a.$1 - other.$1 - b.$1;
        final dy = p.$2 + a.$2 - other.$2 - b.$2;
        final clearance = radius + decorationRadius(other.$3, other.$4);
        if (dx * dx + dy * dy < clearance * clearance) return false;
      }
      return true;
    }).toList();
    while (_proposals.length > 384) {
      _proposals.remove(_proposals.keys.first);
    }
    return result;
  }

  List<(int, int, String, double)> _candidatesInChunk(int cx, int cy) {
    const trees = [
      'tree_default_NE',
      'tree_default_dark_NE',
      'tree_oak_NE',
      'tree_detailed_NE',
      'tree_pineDefaultA_NE',
      'tree_pineRoundC_NE',
      'tree_pineSmallA_NE',
      'tree_small_NE',
      'tree_small_fall_NE',
    ];
    const rocks = [
      'rock_smallA_NE',
      'rock_smallB_NE',
      'rock_smallC_NE',
      'rock_smallFlatA_NE',
      'rock_largeA_NE',
      'rock_largeC_NE',
      'rock_tallA_NE',
    ];
    const shrubs = [
      'plant_bushSmall_NE',
      'plant_bushLarge_NE',
      'plant_bushDetailed_NE',
      'plant_bushTriangle_NE',
      'plant_flatShort_NE',
    ];
    const grasses = [
      'grass_NE',
      'grass_large_NE',
      'grass_leafs_NE',
      'plant_flatTall_NE',
    ];
    const flowers = [
      'flower_purpleA_NE',
      'flower_yellowA_NE',
      'flower_redA_NE',
    ];
    final result = <(int, int, String, double)>[];
    for (var x = cx * 8; x < cx * 8 + 8; x++) {
      for (var y = cy * 8; y < cy * 8 + 8; y++) {
        final bank = riverX(y);
        final corridor = isVisitorCorridor(x, y);
        final deliveryClearing =
            (x - giftCell.$1).abs() <= 2 && (y - giftCell.$2).abs() <= 2;
        if (editable.contains((x, y)) ||
            x == left - 2 ||
            isRiverCell(x, y) ||
            corridor ||
            deliveryClearing ||
            x == riverX(top + 3) + 1 && (y - top - 3).abs() <= 1) {
          continue;
        }
        final nearYard = [
          for (var dx = -1; dx <= 1; dx++)
            for (var dy = -1; dy <= 1; dy++)
              editable.contains((x + dx, y + dy)),
        ].any((value) => value);
        final forest = _patch(x / 5, y / 5, 3);
        final rocky = _patch(x / 3.5, y / 3.5, 41);
        final blossom = _patch(x / 4, y / 4, 67);
        final waterside = (x - bank).abs() <= 2;
        final density = nearYard ? .38 : .24 + forest * .48;
        if (_random(x, y, 23) > density) continue;
        final pick = _random(x, y, 31);
        final variant = (_random(x, y, 37) * 997).floor();
        final size = _random(x, y, 43);
        String sprite;
        double scale;
        if (!nearYard && !waterside && forest > .45 && pick < .38) {
          sprite = trees[variant % trees.length];
          scale = 1.05 + size * .8;
        } else if (rocky > .62 && pick < .65 || waterside && pick < .25) {
          final choices = nearYard ? rocks.sublist(0, 4) : rocks;
          sprite = choices[variant % choices.length];
          scale = .75 + size * .95;
        } else if (blossom > .57 && pick > .45) {
          sprite = flowers[variant % flowers.length];
          scale = 1.05 + size * .55;
        } else if (forest > .6 && pick > .86 && !nearYard && !waterside) {
          sprite = variant.isEven ? 'stump_roundDetailed_NE' : 'log_large_NE';
          scale = .9 + size * .35;
        } else if (forest > .55 && pick > .75) {
          sprite = variant.isEven
              ? 'mushroom_tanGroup_NE'
              : 'mushroom_redGroup_NE';
          scale = .85 + size * .5;
        } else if (waterside || pick > .6) {
          sprite = grasses[variant % grasses.length];
          scale = .8 + size * .65;
        } else {
          sprite = shrubs[variant % shrubs.length];
          scale = .9 + size * .6;
        }
        // Test the whole footprint after jitter, not just its central tile.
        if (!decorationFits(x, y, sprite, scale)) continue;
        result.add((x, y, sprite, scale));
      }
    }
    return result;
  }

  bool isVisitorCorridor(int x, int y) =>
      x == left - 2 ||
      x == left - 7 ||
      x == left - 8 ||
      x == right + 2 ||
      x == right + 3 ||
      (y == top - 2 || y == bottom + 2) && x > riverX(y);

  double decorationRadius(String sprite, double scale) =>
      scale *
      (sprite.startsWith('rock_large') || sprite.startsWith('log_')
          ? .55
          : sprite.startsWith('tree_')
          ? .32
          : .27);

  bool decorationFits(int x, int y, String sprite, double scale) {
    final offset = decorationOffset(x, y);
    final px = x + offset.$1, py = y + offset.$2;
    final radius = decorationRadius(sprite, scale) + .18;
    for (
      var cx = (px - radius - .5).ceil();
      cx <= (px + radius + .5).floor();
      cx++
    ) {
      for (
        var cy = (py - radius - .5).ceil();
        cy <= (py + radius + .5).floor();
        cy++
      ) {
        if (editable.contains((cx, cy)) ||
            isRiverCell(cx, cy) ||
            isVisitorCorridor(cx, cy) ||
            (cx - giftCell.$1).abs() <= 1 && (cy - giftCell.$2).abs() <= 1) {
          return false;
        }
      }
    }
    return true;
  }

  Iterable<HabitatVisitorPose> visitors(
    double time, {
    (double, double, double, double)? bounds,
  }) sync* {
    // A plan captures the viewport when it begins. Panning cannot teleport it.
    final region =
        bounds ?? (left - 15.0, top - 15.0, right + 15.0, bottom + 15.0);
    const cycleLength = 360.0;
    for (var lane = 0; lane < 6; lane++) {
      final shifted = time - lane * 31;
      if (shifted < 0) continue;
      final cycle = (shifted / cycleLength).floor();
      final key = (lane, cycle);
      final plan = _visits.putIfAbsent(
        key,
        () => _makeVisit(lane, cycle, region),
      );
      final pose = plan.poseAt(shifted - cycle * cycleLength);
      if (pose != null) yield pose;
    }
    _visits.removeWhere((key, _) => key.$2 < (time / cycleLength).floor() - 1);
  }
}
