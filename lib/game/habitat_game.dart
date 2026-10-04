import 'dart:math' as math;
import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../services/habitat_service.dart';
import 'habitat_path_style.dart';
import 'habitat_sprites.dart';
import 'habitat_cat_animations.dart';
import 'habitat_cat_motion.dart';
import '../services/product_api_service.dart';

part 'habitat_interactions.dart';

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
  bool reducedMotion = false;
  String? selectedItemId;
  double _elapsed = 0;
  final math.Random _random = math.Random();
  final Map<String, HabitatCatMotion> _catWalks = {};
  bool _removed = false;
  bool _feeding = false;

  String _itemKey(HabitatItem item) => sprites.keyFor(
    _catWalks.values.any(
          (walk) => walk.targetItemId == item.id && walk.activity == 'feed',
        )
        ? 'bowl-cereal'
        : habitat.spriteFor(item),
    item.rotation,
  );

  @override
  Future<void> onLoad() async {
    await sprites.initialize();
    await Future.wait([
      for (final clip in [
        HabitatCatClip.idle,
        HabitatCatClip.walk,
        HabitatCatClip.run,
      ])
        sprites.catAnimations.preload(clip),
    ]);
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
      'tree_pineRoundC_NE',
      'tree_small_fall_NE',
      'plant_bushLarge_NE',
      'mushroom_tanGroup_NE',
      'flower_purpleA_NE',
      'animal-bee_NE',
      'bowl-cereal_NE',
      'water',
      'dirt',
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
      if (!type.isPath) return _itemKey(item);
      return _pathKey(item, paths);
    });
    unawaited(sprites.preloadReady(keys));
    unawaited(
      sprites.preloadReady([
        for (final item in placed.where(habitat.isGrowingPlant))
          sprites.keyFor(
            habitat.definition(item.sku).sprite.replaceAll('StageA', 'StageB'),
            item.rotation,
          ),
      ]),
    );
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
    _removed = true;
    for (final walk in _catWalks.values) {
      walk.cancelVisit();
    }
    habitat.removeListener(_preloadVisible);
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    final freeCells = habitat.walkableCells();
    bool free(int x, int y) => freeCells.contains((x, y));
    _catWalks.removeWhere((id, walk) {
      if (habitat.selectedCatIds.contains(id)) return false;
      walk.cancelVisit();
      return true;
    });
    for (final id in habitat.selectedCatIds) {
      final anchor = habitat.catAnchors[id];
      if (anchor == null) continue;
      final walk = _catWalks.putIfAbsent(id, () => HabitatCatMotion(anchor));
      if (walk.anchor != anchor) walk.reset(anchor);
      if (walk.targetItemId != null &&
          !habitat.items.any(
            (item) =>
                item.id == walk.targetItemId &&
                item.isPlaced &&
                (walk.targetPlacement == null ||
                    walk.targetPlacement == (item.x!, item.y!, item.rotation)),
          )) {
        walk.cancelVisit();
      }
      if (!free(walk.current.$1, walk.current.$2) ||
          !free(walk.next.$1, walk.next.$2)) {
        walk.reset(anchor);
      }
      if (editing) walk.cancelVisit();
      if (!editing && (!reducedMotion || walk.targetItemId != null)) {
        walk.advance(
          dt,
          _random,
          (x, y) => free(x, y) && habitat.canTraverse(walk.current, (x, y)),
        );
        if (walk.targetItemId == null &&
            walk.current == walk.next &&
            _random.nextDouble() < dt * 0.10) {
          _visitFurniture(id, walk);
        }
      }
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
    if (definition.layer == 'terrain') {
      return _cellDiamond(item.x!, item.y!).getBounds();
    }
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
              (item) => item.isPlaced && !habitat.definition(item.sku).isGround,
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
    final point = walk == null
        ? groundAnchor(cell.$1, cell.$2)
        : Offset.lerp(
            groundAnchor(walk.current.$1, walk.current.$2),
            groundAnchor(walk.next.$1, walk.next.$2),
            walk.progress,
          )!;
    final target = habitat.items
        .where((item) => item.id == walk?.targetItemId && item.isPlaced)
        .firstOrNull;
    if (walk != null &&
        target != null &&
        walk.visiting &&
        walk.activity != 'feed') {
      final amount = math.min(
        (walk.visitElapsed / 0.5).clamp(0.0, 1.0),
        ((walk.visitDuration - walk.visitElapsed) / 0.5).clamp(0.0, 1.0),
      );
      return Offset.lerp(point, itemFocus(target), amount)!;
    }
    return point;
  }

  Rect _catBounds(int index, (int, int) cell) {
    final point =
        _catGroundPosition(index, cell) - Offset(0, _catElevation(index));
    return _catFrame(index)?.bounds(point, _animatedCatScale) ??
        sprites.placedBounds('animal-cat', point, _catScale);
  }

  double _catElevation(int index) {
    final walk = _catWalks[habitat.selectedCatIds[index]];
    if (walk == null) return 0;
    final target = habitat.items
        .where((item) => item.id == walk.targetItemId && item.isPlaced)
        .firstOrNull;
    if (target != null && walk.visiting && walk.activity != 'feed') {
      final height =
          target.sku.contains('tent') || target.sku.startsWith('canvas_')
          ? 0.0
          : target.sku.contains('log') || target.sku.contains('stump')
          ? 0.3
          : 0.12;
      return tileHeight *
          height *
          math.min(
            (walk.visitElapsed / 0.5).clamp(0.0, 1.0),
            ((walk.visitDuration - walk.visitElapsed) / 0.5).clamp(0.0, 1.0),
          );
    }
    double elevation((int, int) cell) =>
        habitat.items.any(
          (item) =>
              item.isPlaced &&
              habitat.definition(item.sku).isBridge &&
              habitat.occupiedCells(item).contains(cell),
        )
        ? tileHeight * 0.08
        : 0;
    return elevation(walk.current) * (1 - walk.progress) +
        elevation(walk.next) * walk.progress;
  }

  double get _animatedCatScale =>
      tileWidth * 0.86 / sprites.catAnimations.restHeight;

  HabitatCatFrame? _catFrame(int index) {
    if (reducedMotion) {
      return sprites.catAnimations.frame(HabitatCatClip.idle, 0, 0);
    }
    final walk = _catWalks[habitat.selectedCatIds[index]];
    final clip = editing
        ? HabitatCatClip.idle
        : walk?.clip ?? HabitatCatClip.idle;
    return sprites.catAnimations.frame(
          clip,
          walk?.animationTime ?? _elapsed,
          walk?.direction ?? 0,
        ) ??
        sprites.catAnimations.frame(
          HabitatCatClip.idle,
          _elapsed,
          walk?.direction ?? 0,
        );
  }

  Future<void> greetCat(String id) async {
    if (editing || reducedMotion || !habitat.selectedCatIds.contains(id)) {
      return;
    }
    final clip = _random.nextBool()
        ? HabitatCatClip.happy
        : HabitatCatClip.dance;
    await sprites.catAnimations.preload(clip);
    if (editing || !habitat.selectedCatIds.contains(id)) return;
    _catWalks[id]?.react(clip);
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
      (-6, -5, 'tree_pineRoundC_NE', 1.9),
      (2, -7, 'tree_oak_NE', 1.8),
      (8, 16, 'tree_small_fall_NE', 2.5),
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
      (13, 8, 'plant_bushLarge_NE', 1.1),
      (-4, 8, 'mushroom_tanGroup_NE', 2.0),
      (7, -5, 'flower_purpleA_NE', 2.0),
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
      if (type.isGround) continue;
      scene.add(
        _SceneSprite(
          _itemKey(item),
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
          _animatedCatScale,
          destination: _catBounds(index, cells[index]),
          tint: _coatTint(cat.primaryColor),
          catFrame: _catFrame(index),
          elevation: _catElevation(index),
          depthOffset: _catWalks[cat.id]?.visiting == true ? 0.5 : 0,
        ),
      );
    }
    _addFence(scene);
    final grown = habitat.items
        .where(
          (item) =>
              item.isPlaced &&
              habitat.isGrowingPlant(item) &&
              habitat.isMature(item),
        )
        .firstOrNull;
    if (grown != null && !reducedMotion && _elapsed % 30 < 12) {
      final point =
          itemFocus(grown) +
          Offset(
            math.sin(_elapsed * 1.2) * tileWidth * 0.5,
            math.cos(_elapsed) * tileHeight * 0.2,
          );
      scene.add(
        _SceneSprite(
          'animal-bee_NE',
          point,
          tileWidth * 0.23 / sprites.bounds('animal-bee_NE').height,
          destination: sprites.placedBounds(
            'animal-bee_NE',
            point - Offset(0, tileWidth * 0.55),
            tileWidth * 0.23 / sprites.bounds('animal-bee_NE').height,
          ),
        ),
      );
    }

    // Every shadow belongs to the ground layer, never the sprite in front of it.
    for (final entry in scene) {
      if (entry.catFrame case final frame?) {
        frame.paint(
          canvas,
          entry.ground +
              Offset(-entry.elevation * 0.62, -entry.elevation * 0.18),
          entry.scale,
          groundShadow: true,
        );
        continue;
      }
      if (sprites.cached(entry.key) == null) continue;
      sprites.drawShadow(canvas, entry.key, entry.ground, entry.scale);
    }
    scene.sort((a, b) => a.depth.compareTo(b.depth));
    for (final entry in scene) {
      if (entry.catFrame case final frame?) {
        frame.paint(
          canvas,
          entry.ground - Offset(0, entry.elevation),
          entry.scale,
          tint: entry.tint,
        );
        continue;
      }
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
    _drawTerrain(canvas);
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

  void _drawTerrain(Canvas canvas) {
    final terrain = habitat.items.where(
      (item) =>
          item.isPlaced && habitat.definition(item.sku).layer == 'terrain',
    );
    final water = {
      for (final item in terrain.where((item) => item.sku == 'water_tile'))
        (item.x!, item.y!),
    };
    for (final item in terrain) {
      final diamond = _cellDiamond(item.x!, item.y!);
      canvas.save();
      canvas.clipPath(diamond);
      _drawSprite(
        canvas,
        habitat.definition(item.sku).sprite,
        diamond.getBounds(),
      );
      canvas.restore();
      if (item.sku != 'water_tile') continue;
      final top = cellTop(item.x!, item.y!);
      final corners = [
        top,
        top + Offset(tileWidth / 2, tileHeight / 2),
        top + Offset(0, tileHeight),
        top + Offset(-tileWidth / 2, tileHeight / 2),
      ];
      final neighbors = [
        (item.x!, item.y! - 1),
        (item.x! + 1, item.y!),
        (item.x!, item.y! + 1),
        (item.x! - 1, item.y!),
      ];
      for (var i = 0; i < 4; i++) {
        if (!water.contains(neighbors[i])) {
          canvas.drawLine(
            corners[i],
            corners[(i + 1) % 4],
            Paint()
              ..color = const Color(0xFF85AD62)
              ..strokeWidth = tileWidth * 0.06
              ..strokeCap = StrokeCap.round,
          );
        }
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
    if (type?.layer == 'terrain') {
      final diamond = _cellDiamond(previewX!, previewY!);
      canvas.save();
      canvas.clipPath(diamond);
      _drawSprite(canvas, key, diamond.getBounds());
      canvas.restore();
      return;
    }
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
      final key = sprites.keyFor(sprite, 0);
      final preferred =
          tileWidth *
          (item.width + item.height) /
          2 *
          0.84 /
          sprites.bounds(key).width;
      return sprites.fitScale(
        key,
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
        : sprite.startsWith('flower_') ||
              sprite.startsWith('crops_') ||
              sprite.startsWith('pot_') ||
              sprite.startsWith('mushroom_')
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
    this.catFrame,
    this.elevation = 0,
  });
  final String key;
  final Offset ground;
  final double scale;
  final double depthOffset;
  final Rect? destination;
  final Color? tint;
  final bool selected;
  final HabitatCatFrame? catFrame;
  final double elevation;
  double get depth => ground.dy + depthOffset;
}
