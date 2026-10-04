part of 'habitat_service.dart';

extension HabitatLayout on HabitatService {
  bool canTraverse((int, int) start, (int, int) end) {
    for (final item in items.where(
      (item) => item.isPlaced && definition(item.sku).isBridge,
    )) {
      final cells = occupiedCells(item);
      if (cells.contains(start) != cells.contains(end)) {
        if (item.rotation.isEven && start.$1 == end.$1) return false;
        if (item.rotation.isOdd && start.$2 == end.$2) return false;
      }
    }
    return true;
  }

  Set<(int, int)> occupiedCells(HabitatItem item) {
    if (!item.isPlaced) return {};
    final type = definition(item.sku);
    final width = item.rotation.isOdd ? type.height : type.width;
    final height = item.rotation.isOdd ? type.width : type.height;
    return {
      for (var x = item.x!; x < item.x! + width; x++)
        for (var y = item.y!; y < item.y! + height; y++) (x, y),
    };
  }

  String? layoutProblem(List<HabitatItem> layout) {
    final solid = <(int, int)>{},
        paths = <(int, int)>{},
        terrain = <(int, int)>{};
    final water = <(int, int)>{},
        landObjects = <(int, int)>{},
        onWater = <(int, int)>{};
    var decorations = 0;
    for (final item in layout.where((item) => item.isPlaced)) {
      final type = definition(item.sku);
      if (!type.rotatable && item.rotation != 0) {
        return 'Este objeto não pode girar.';
      }
      final cells = occupiedCells(item);
      if (!buildableCells.containsAll(cells)) return 'Fora do quintal.';
      final layer = type.isPath
          ? paths
          : type.layer == 'terrain'
          ? terrain
          : solid;
      if (layer.intersection(cells).isNotEmpty) {
        return 'Esta posição já está ocupada.';
      }
      layer.addAll(cells);
      if (item.sku == 'water_tile') water.addAll(cells);
      if (type.layer == 'bridge' || type.layer == 'water_decor') {
        onWater.addAll(cells);
      }
      if (type.layer == 'solid') landObjects.addAll(cells);
      if (!type.isGround) decorations++;
    }
    if (decorations > decorationCapacity) {
      return 'Limite de decorações atingido.';
    }
    if ({...paths, ...landObjects}.intersection(water).isNotEmpty) {
      return 'Deixe caminhos e objetos de terra fora do lago.';
    }
    if (!water.containsAll(onWater)) {
      return 'Coloque pontes e nenúfares inteiramente sobre a água.';
    }
    final free = walkableCells(layout);
    if (catAnchors.values.any((cell) => !free.contains(cell))) {
      return 'Mova o gato antes de ocupar esta posição.';
    }
    return null;
  }

  Set<(int, int)> walkableCells([List<HabitatItem>? layout]) {
    final blocked = <(int, int)>{}, bridges = <(int, int)>{};
    for (final item in (layout ?? items).where((item) => item.isPlaced)) {
      final type = definition(item.sku);
      if (type.isBridge) {
        bridges.addAll(occupiedCells(item));
      } else if (!type.isGround || item.sku == 'water_tile') {
        blocked.addAll(occupiedCells(item));
      }
    }
    return buildableCells.difference(blocked).union(bridges);
  }

  List<(int, int)>? routeTo(
    (int, int) start,
    Set<(int, int)> goals, {
    Set<(int, int)> reserved = const {},
  }) {
    final free = walkableCells().difference(reserved)..add(start);
    final previous = <(int, int), (int, int)?>{start: null};
    final queue = [start];
    for (var index = 0; index < queue.length; index++) {
      final cell = queue[index];
      if (goals.contains(cell)) {
        final route = <(int, int)>[];
        (int, int)? cursor = cell;
        while (cursor != null && cursor != start) {
          route.add(cursor);
          cursor = previous[cursor];
        }
        return route.reversed.toList();
      }
      for (final next in [
        (cell.$1 + 1, cell.$2),
        (cell.$1 - 1, cell.$2),
        (cell.$1, cell.$2 + 1),
        (cell.$1, cell.$2 - 1),
      ]) {
        if (free.contains(next) &&
            !previous.containsKey(next) &&
            canTraverse(cell, next)) {
          previous[next] = cell;
          queue.add(next);
        }
      }
    }
    return null;
  }

  Set<(int, int)> accessCells(HabitatItem item) {
    final cells = occupiedCells(item);
    return {
      for (final (x, y) in cells) ...[
        (x + 1, y),
        (x - 1, y),
        (x, y + 1),
        (x, y - 1),
      ],
    }.difference(cells).intersection(walkableCells());
  }
}
