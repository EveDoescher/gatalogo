import 'dart:math' as math;
import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../services/habitat_service.dart';
import 'habitat_path_style.dart';
import 'habitat_sprites.dart';

class HabitatGame extends FlameGame {
  HabitatGame(this.habitat, this.sprites) {
    habitat.addListener(_preloadVisible);
  }

  final HabitatService habitat;
  final HabitatSprites sprites;
  double zoom = 1;
  Offset pan = Offset.zero;
  int? previewX;
  int? previewY;
  String? previewSku;
  bool previewCat = false;
  int previewRotation = 0;
  bool previewValid = true;
  bool editing = false;
  String? selectedItemId;
  double _elapsed = 0;
  final math.Random _random = math.Random();
  final Map<String, _CatWalk> _catWalks = {};

  @override
  Future<void> onLoad() async {
    await sprites.initialize();
    await sprites.preloadReady([
      'animal-cat',
      'tree_default_NE',
      'tree_pineDefaultA_NE',
      'tree_oak_NE',
      'tree_detailed_NE',
      'grass_NE',
      'plant_bushSmall_NE',
      'plant_flatShort_NE',
      'flower_yellowA_NE',
      for (final direction in ['NE', 'SE', 'SW', 'NW'])
        'fence_simple_$direction',
    ]);
    _preloadVisible();
  }

  void _preloadVisible() {
    final placed = habitat.items.where((item) => item.isPlaced).toList();
    final paths = {
      for (final item in placed.where(
        (item) => habitat.definition(item.sku).isPath,
      ))
        (item.x!, item.y!): item.sku,
    };
    final keys = placed.map((item) {
      final type = habitat.definition(item.sku);
      if (!type.isPath) return sprites.keyFor(type.sprite, item.rotation);
      return _pathKey(item, paths);
    });
    unawaited(sprites.preloadReady(keys));
  }

  String _pathKey(HabitatItem item, Map<(int, int), String> cells) {
    final (variant, rotation) = pathSprite(
      habitat.definition(item.sku).sprite,
      [
        cells[(item.x! - 1, item.y!)] == item.sku,
        cells[(item.x! + 1, item.y!)] == item.sku,
        cells[(item.x!, item.y! - 1)] == item.sku,
        cells[(item.x!, item.y! + 1)] == item.sku,
      ],
    );
    return sprites.keyFor(variant, rotation);
  }

  @override
  void onRemove() {
    habitat.removeListener(_preloadVisible);
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    _catWalks.removeWhere((id, _) => !habitat.selectedCatIds.contains(id));
    for (final id in habitat.selectedCatIds) {
      final anchor = habitat.catAnchors[id];
      if (anchor == null) continue;
      final walk = _catWalks.putIfAbsent(id, () => _CatWalk(anchor));
      if (walk.anchor != anchor) walk.reset(anchor);
      if (!habitat.isFreeForCat(walk.current.$1, walk.current.$2) ||
          !habitat.isFreeForCat(walk.next.$1, walk.next.$2)) {
        walk.reset(anchor);
      }
      walk.advance(dt, _random, habitat.isFreeForCat);
    }
  }

  double get tileWidth => math.min(size.x / 8.7, size.y / 5.7) * zoom;
  // The source artwork uses a 30-degree orthographic camera (2:1 ground tiles).
  double get tileHeight => tileWidth * 0.5;
  double get boardTop => (size.y - 8 * tileHeight) / 2 + pan.dy;

  Offset cellTop(int x, int y) => Offset(
    size.x / 2 + (x - y) * tileWidth / 2 + pan.dx,
    boardTop + (x + y) * tileHeight / 2,
  );

  Offset _itemAnchor(int x, int y, int width, int height) =>
      cellTop(x, y) +
      Offset(
        (width - height) * tileWidth / 4,
        (width + height) * tileHeight / 4,
      );

  Offset itemFocus(HabitatItem item) {
    final type = habitat.definition(item.sku);
    final width = item.rotation.isOdd ? type.height : type.width;
    final height = item.rotation.isOdd ? type.width : type.height;
    return _itemAnchor(item.x!, item.y!, width, height);
  }

  Rect itemBounds(HabitatItem item) {
    final definition = habitat.definition(item.sku);
    final footprintWidth = item.rotation.isOdd
        ? definition.height
        : definition.width;
    final footprintHeight = item.rotation.isOdd
        ? definition.width
        : definition.height;
    final point = _itemAnchor(
      item.x!,
      item.y!,
      footprintWidth,
      footprintHeight,
    );
    return sprites.placedBounds(
      sprites.keyFor(definition.sprite, item.rotation),
      point,
      _itemScale(definition),
    );
  }

  HabitatItem? itemAtScreen(Offset position) {
    final visible =
        habitat.items
            .where(
              (item) => item.isPlaced && !habitat.definition(item.sku).isPath,
            )
            .toList()
          ..sort((a, b) {
            return itemFocus(a).dy.compareTo(itemFocus(b).dy);
          });
    for (final item in visible.reversed) {
      final key = sprites.keyFor(
        habitat.definition(item.sku).sprite,
        item.rotation,
      );
      if (sprites.cached(key) != null && itemBounds(item).contains(position)) {
        return item;
      }
    }
    return null;
  }

  List<(int, int)> get catCells => habitat.selectedCatIds
      .map((id) => _catWalks[id]?.current ?? habitat.catAnchors[id])
      .whereType<(int, int)>()
      .toList();

  Offset _catGroundPosition(int index, (int, int) cell) {
    final catId = habitat.selectedCatIds[index];
    final walk = _catWalks[catId];
    return walk == null
        ? groundAnchor(cell.$1, cell.$2)
        : Offset.lerp(
            groundAnchor(walk.current.$1, walk.current.$2),
            groundAnchor(walk.next.$1, walk.next.$2),
            walk.progress,
          )!;
  }

  Rect _catBounds(int index, (int, int) cell) {
    final walk = _catWalks[habitat.selectedCatIds[index]];
    final point = _catGroundPosition(index, cell);
    final bob =
        -(walk == null
            ? 0.0
            : math.sin(math.pi * walk.progress) * tileHeight * 0.24) +
        math.sin(_elapsed * 2.8 + index * 2) * tileHeight * 0.03;
    return sprites.placedBounds(
      'animal-cat',
      point + Offset(0, bob),
      _catScale,
    );
  }

  double get _catScale =>
      tileWidth * 0.86 / sprites.bounds('animal-cat').height;

  String? catAtScreen(Offset position) {
    final cells = catCells;
    for (var index = cells.length - 1; index >= 0; index--) {
      if (_catBounds(index, cells[index]).contains(position)) {
        return habitat.selectedCatIds[index];
      }
    }
    return null;
  }

  (int, int)? cellAt(Offset point) {
    final dx = (point.dx - size.x / 2 - pan.dx) / (tileWidth / 2);
    final dy = (point.dy - boardTop) / (tileHeight / 2);
    final x = ((dx + dy) / 2).floor();
    final y = ((dy - dx) / 2).floor();
    if (!habitat.buildableCells.contains((x, y))) return null;
    return (x, y);
  }

  void moveCamera(Offset delta) {
    pan += delta;
    pan = Offset(
      pan.dx.clamp(-size.x * 0.65, size.x * 0.65),
      pan.dy.clamp(-size.y * 0.65, size.y * 0.65),
    );
  }

  void scaleCamera(double value, Offset focus) {
    final ratio = value.clamp(0.65, 1.9) / zoom;
    zoom *= ratio;
    pan = Offset(
      focus.dx - size.x / 2 - (focus.dx - size.x / 2 - pan.dx) * ratio,
      focus.dy - size.y / 2 - (focus.dy - size.y / 2 - pan.dy) * ratio,
    );
  }

  @override
  void render(Canvas canvas) {
    final viewport = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(
      viewport,
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFA3C47E), Color(0xFF9CBF78), Color(0xFF97B973)],
            ).createShader(
              Rect.fromCenter(
                center: groundAnchor(4, 4),
                width: tileWidth * 24,
                height: tileHeight * 32,
              ),
            ),
    );
    _drawGround(canvas);
    _drawPaths(canvas);

    final scene = <_SceneSprite>[];
    for (final tree in const [
      (-10, -5, 'tree_default_NE', 1.65),
      (-6, -5, 'tree_pineDefaultA_NE', 1.9),
      (2, -7, 'tree_oak_NE', 1.8),
      (8, 16, 'tree_detailed_NE', 1.85),
      (16, 9, 'tree_pineDefaultA_NE', 2.0),
    ]) {
      scene.add(
        _SceneSprite(
          tree.$3,
          groundAnchor(tree.$1, tree.$2),
          tileWidth / 128 * tree.$4,
        ),
      );
    }
    for (final decor in const [
      (-3, 5, 'grass_NE', 1.4),
      (-5, -4, 'plant_bushSmall_NE', 1.0),
      (2, -5, 'plant_flatShort_NE', 1.4),
      (10, 0, 'plant_flatShort_NE', 1.2),
      (6, 12, 'grass_NE', 1.5),
      (10, 10, 'flower_yellowA_NE', 1.3),
      (13, 8, 'plant_bushSmall_NE', 1.1),
    ]) {
      scene.add(
        _SceneSprite(
          decor.$3,
          groundAnchor(decor.$1, decor.$2),
          tileWidth / 128 * decor.$4,
        ),
      );
    }
    for (final item in habitat.items.where((item) => item.isPlaced)) {
      final type = habitat.definition(item.sku);
      if (type.isPath) continue;
      scene.add(
        _SceneSprite(
          sprites.keyFor(type.sprite, item.rotation),
          itemFocus(item),
          _itemScale(type),
          selected: editing && item.id == selectedItemId,
        ),
      );
    }
    final cells = catCells;
    for (var index = 0; index < cells.length; index++) {
      final cat = habitat.cats
          .where((cat) => cat.id == habitat.selectedCatIds[index])
          .firstOrNull;
      if (cat == null) continue;
      scene.add(
        _SceneSprite(
          'animal-cat',
          _catGroundPosition(index, cells[index]),
          _catScale,
          destination: _catBounds(index, cells[index]),
          tint: _coatTint(cat.primaryColor),
        ),
      );
    }
    _addFence(scene);

    // Every shadow belongs to the ground layer, never the sprite in front of it.
    for (final entry in scene) {
      if (sprites.cached(entry.key) == null) continue;
      sprites.drawShadow(canvas, entry.key, entry.ground, entry.scale);
    }
    scene.sort((a, b) => a.depth.compareTo(b.depth));
    for (final entry in scene) {
      if (sprites.cached(entry.key) == null) continue;
      final target =
          entry.destination ??
          sprites.placedBounds(entry.key, entry.ground, entry.scale);
      if (!target.overlaps(viewport)) continue;
      if (entry.selected) {
        _drawOutlinedSprite(canvas, entry.key, target);
      } else {
        _drawSprite(canvas, entry.key, target, tint: entry.tint);
      }
    }
    _drawPreview(canvas);
    super.render(canvas);
  }

  Path _cellDiamond(int x, int y) {
    final top = cellTop(x, y);
    return Path()
      ..moveTo(top.dx, top.dy)
      ..relativeLineTo(tileWidth / 2, tileHeight / 2)
      ..relativeLineTo(-tileWidth / 2, tileHeight / 2)
      ..relativeLineTo(-tileWidth / 2, -tileHeight / 2)
      ..close();
  }

  void _drawGround(Canvas canvas) {
    final mask = Path();
    for (final (x, y) in habitat.buildableCells) {
      final diamond = _cellDiamond(x, y);
      mask.addPath(diamond, Offset.zero);
      canvas.drawPath(
        diamond,
        Paint()
          ..color = const Color(0xFF6B9E59)
          ..isAntiAlias = false,
      );
    }
    canvas.save();
    canvas.clipPath(mask);
    final area = mask.getBounds();
    canvas.drawRect(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0x0EFFFFFF), Color(0x001F4A20), Color(0x111F4A20)],
        ).createShader(area),
    );
    canvas.restore();
    final selected = habitat.items
        .where((item) => item.id == selectedItemId && item.isPlaced)
        .firstOrNull;
    final previewType = previewSku == null
        ? null
        : habitat.definition(previewSku!);
    for (final (x, y) in habitat.buildableCells) {
      final diamond = _cellDiamond(x, y);
      if (editing) {
        canvas.drawPath(
          diamond,
          Paint()
            ..color = const Color(0x55E4F4D8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7,
        );
        if (selected != null) {
          final type = habitat.definition(selected.sku);
          if (_insideFootprint(
            x,
            y,
            selected.x!,
            selected.y!,
            type.width,
            type.height,
            selected.rotation,
          )) {
            canvas.drawPath(diamond, Paint()..color = const Color(0x668CE8B7));
            canvas.drawPath(
              diamond,
              Paint()
                ..color = Colors.white
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2,
            );
          }
        }
      }
      if (previewX != null &&
          previewY != null &&
          _insideFootprint(
            x,
            y,
            previewX!,
            previewY!,
            previewType?.width ?? 1,
            previewType?.height ?? 1,
            previewRotation,
          )) {
        canvas.drawPath(
          diamond,
          Paint()
            ..color = previewValid
                ? const Color(0x99C7F2AC)
                : const Color(0x99D4543C),
        );
      }
    }
  }

  bool _insideFootprint(
    int x,
    int y,
    int left,
    int top,
    int width,
    int height,
    int rotation,
  ) {
    final w = rotation.isOdd ? height : width;
    final h = rotation.isOdd ? width : height;
    return x >= left && x < left + w && y >= top && y < top + h;
  }

  void _drawPaths(Canvas canvas) {
    final paths = habitat.items.where(
      (item) => item.isPlaced && habitat.definition(item.sku).isPath,
    );
    final cells = {for (final item in paths) (item.x!, item.y!): item.sku};
    for (final item in paths) {
      final key = _pathKey(item, cells);
      if (sprites.cached(key) == null) continue;
      _drawSprite(
        canvas,
        key,
        sprites.placedBounds(
          key,
          groundAnchor(item.x!, item.y!),
          tileWidth / 128,
        ),
      );
    }
  }

  void _addFence(List<_SceneSprite> scene) {
    for (final (x, y) in habitat.buildableCells) {
      for (final edge in [
        (x - 1, y, 'NW', -1),
        (x, y - 1, 'NE', -1),
        (x + 1, y, 'SE', 1),
        (x, y + 1, 'SW', 1),
      ]) {
        if (habitat.buildableCells.contains((edge.$1, edge.$2))) continue;
        scene.add(
          _SceneSprite(
            'fence_simple_${edge.$3}',
            groundAnchor(x, y),
            tileWidth / 128,
            depthOffset: edge.$4 * tileHeight / 4,
            tint: const Color(0xFFCBEDFF),
          ),
        );
      }
    }
  }

  void _drawPreview(Canvas canvas) {
    if (previewX == null || previewY == null) return;
    final type = previewSku == null ? null : habitat.definition(previewSku!);
    final key = previewCat
        ? 'animal-cat'
        : type == null
        ? null
        : sprites.keyFor(type.sprite, previewRotation);
    if (key == null) return;
    final image = sprites.cached(key);
    if (image == null) return;
    final width = type == null
        ? 1
        : previewRotation.isOdd
        ? type.height
        : type.width;
    final height = type == null
        ? 1
        : previewRotation.isOdd
        ? type.width
        : type.height;
    final ground = _itemAnchor(previewX!, previewY!, width, height);
    final target = type?.isPath == true
        ? sprites.placedBounds(key, ground, tileWidth / 128)
        : sprites.placedBounds(
            key,
            ground - Offset(0, tileWidth * 0.12),
            previewCat ? _catScale : _itemScale(type!),
          );
    sprites.paintSprite(
      canvas,
      key,
      target,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  Offset groundAnchor(int x, int y) =>
      cellTop(x, y) + Offset(0, tileHeight / 2);

  double _itemScale(HabitatShopItem item) {
    final sprite = item.sprite;
    if (sprite.startsWith('building-type-')) {
      final preferred =
          tileWidth *
          (item.width + item.height) /
          2 *
          0.84 /
          sprites.bounds(sprite).width;
      return sprites.fitScale(
        sprite,
        preferred,
        tileWidth,
        item.width,
        item.height,
      );
    }
    final multiplier = sprite == 'bed'
        ? 2.5
        : sprite.startsWith('tent_')
        ? math.max(item.width, item.height) * 1.35
        : sprite.startsWith('tree_')
        ? (item.width == 1 ? 1.6 : 2.4)
        : sprite.startsWith('plant_')
        ? 2.1
        : sprite.startsWith('flower_')
        ? 2.7
        : math.max(item.width, item.height).toDouble();
    final preferred = tileWidth / 128 * multiplier;
    // Foliage may overhang its cell; furniture and rocks stay inside their plot.
    if (sprite.startsWith('tree_') ||
        sprite.startsWith('plant_') ||
        sprite.startsWith('flower_')) {
      return preferred;
    }
    return sprites.fitScale(
      sprites.keyFor(sprite, 0),
      preferred,
      tileWidth,
      item.width,
      item.height,
    );
  }

  Color? _coatTint(String? color) {
    final value = color?.toLowerCase() ?? '';
    if (value.contains('laranja') || value.contains('orange')) {
      return const Color(0xFFFFBA7A);
    }
    if (value.contains('preto') || value.contains('black')) {
      return const Color(0xFF68605E);
    }
    if (value.contains('branco') || value.contains('white')) {
      return const Color(0xFFFFF7E8);
    }
    if (value.contains('cinza') || value.contains('gray')) {
      return const Color(0xFFB6AFB7);
    }
    return null;
  }

  void _drawSprite(Canvas canvas, String key, Rect destination, {Color? tint}) {
    final image = sprites.cached(key);
    if (image == null) return;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
    sprites.paintSprite(canvas, key, destination, paint);
  }

  void _drawOutlinedSprite(Canvas canvas, String key, Rect destination) {
    final image = sprites.cached(key);
    if (image == null) return;
    final outline = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
    for (final offset in const [
      Offset(-2, 0),
      Offset(2, 0),
      Offset(0, -2),
      Offset(0, 2),
    ]) {
      sprites.paintSprite(canvas, key, destination.shift(offset), outline);
    }
    _drawSprite(canvas, key, destination);
  }
}

class _SceneSprite {
  const _SceneSprite(
    this.key,
    this.ground,
    this.scale, {
    this.depthOffset = 0,
    this.destination,
    this.tint,
    this.selected = false,
  });
  final String key;
  final Offset ground;
  final double scale;
  final double depthOffset;
  final Rect? destination;
  final Color? tint;
  final bool selected;
  double get depth => ground.dy + depthOffset;
}

class _CatWalk {
  _CatWalk(this.anchor) : current = anchor, next = anchor;

  (int, int) anchor;
  (int, int) current;
  (int, int) next;
  double progress = 0;
  double pause = 0.8;

  void reset((int, int) cell) {
    anchor = current = next = cell;
    progress = 0;
    pause = 0.8;
  }

  void advance(double dt, math.Random random, bool Function(int, int) free) {
    if (pause > 0) {
      pause -= dt;
      return;
    }
    if (current == next) {
      final neighbors = [
        (current.$1 + 1, current.$2),
        (current.$1 - 1, current.$2),
        (current.$1, current.$2 + 1),
        (current.$1, current.$2 - 1),
      ].where((cell) => free(cell.$1, cell.$2)).toList();
      if (neighbors.isEmpty) {
        pause = 1;
        return;
      }
      next = neighbors[random.nextInt(neighbors.length)];
    }
    progress += dt / 0.75;
    if (progress >= 1) {
      current = next;
      progress = 0;
      pause = 0.5 + random.nextDouble() * 1.3;
    }
  }
}
