part of 'habitat_game.dart';

// Mature crowns occupy roughly one soil bed, with room between neighbours.
// Keep the factor constant across growth stages and confirmed extraction.
double _quintalCropScale(String crop) => switch (crop) {
  'corn' => 1.5,
  'wheat' => 1.45,
  'carrot' => 1.75,
  'turnip' => 1.8,
  'pumpkin' || 'melon' => 1.18,
  _ => 1,
};

extension _QuintalProductionScene on HabitatGame {
  void _gardenClearingProps(
    List<_SceneSprite> scene,
    double x,
    double y,
    double opacity,
  ) {
    for (final prop in [
      ('log_large_NE', -.22, -.12, .46),
      ('rock_smallA_NE', .23, .13, .25),
      ('grass_NE', -.14, .22, .28),
    ]) {
      scene.add(
        _SceneSprite(
          prop.$1,
          _productionGround(x + prop.$2, y + prop.$3),
          tileWidth * prop.$4 / sprites.bounds(prop.$1).width,
          castsShadow: opacity >= 1,
          tint: opacity >= 1 ? null : Colors.white.withValues(alpha: opacity),
        ),
      );
    }
  }

  String _cropSpriteName(Map<String, dynamic> p) {
    final start = DateTime.parse(p['started_at']);
    final end = DateTime.parse(p['ready_at']);
    final fraction =
        (habitat.serverNow.difference(start).inSeconds /
                math.max(1, end.difference(start).inSeconds))
            .clamp(0, 1);
    final stage = fraction >= 1
        ? 3
        : fraction >= .60
        ? 2
        : fraction >= .25
        ? 1
        : 0;
    return 'crafted-crop-${p['crop']}-$stage';
  }

  String _mealBowlKey(HabitatItem bowl, int amount) {
    final color = ((bowl.careState['color_index'] as num?)?.toInt() ?? 0) % 6;
    return sprites.keyFor(
      'production:crafted-cat-food-$color-$amount',
      bowl.rotation,
    );
  }

  double? _mealAmount(String id) {
    final visit = _catMeals[id];
    if (visit == null ||
        editing ||
        reducedMotion ||
        !visit.meal.canShowPortions(habitat.productionCat(id))) {
      return null;
    }
    final walk = _catWalks[id];
    if (visit.started && walk?.targetItemId != visit.bowlId) return null;
    final fraction =
        walk?.visiting == true && walk?.awaitingConsumption == false
        ? (walk!.visitElapsed / walk.visitDuration).clamp(0.0, 1.0)
        : 0.0;
    return visit.meal.before! +
        (visit.meal.after! - visit.meal.before!) * fraction;
  }

  bool _mealVisitValid(String id, _QuintalMealVisit visit) =>
      !_removed &&
      !editing &&
      !reducedMotion &&
      id != _activityCatId &&
      habitat.selectedCatIds.contains(id) &&
      QuintalCatMeal.fromCare(habitat.productionCat(id))?.eventId ==
          visit.meal.eventId &&
      habitat.productionCat(id)['food_bowl'] == visit.bowlId &&
      habitat.productionCat(id)['recipe'] == visit.meal.recipe &&
      !(DateTime.tryParse(
            habitat.productionCat(id)['served_at']?.toString() ?? '',
          )?.isAfter(visit.meal.at) ??
          false) &&
      habitat.items.any(
        (i) =>
            i.id == visit.bowlId &&
            i.isPlaced &&
            (i.x!, i.y!, i.rotation) == visit.placement,
      );

  void _updateCatMeals() {
    _catMeals.removeWhere((id, visit) {
      final walk = _catWalks[id];
      if (!_mealVisitValid(id, visit)) {
        if (visit.started &&
            walk?.targetItemId == visit.bowlId &&
            walk!.isBowlVisit) {
          walk.cancelVisit();
        }
        return true;
      }
      return visit.started && walk?.targetItemId != visit.bowlId;
    });
    _waterVisitsAfter.removeWhere(
      (id, _) => !habitat.selectedCatIds.contains(id),
    );
  }

  Future<void> _showProductionMeal(
    String id,
    Map<String, dynamic> care,
    QuintalCatMeal meal,
  ) async {
    final walk = _catWalks[id];
    final cat = habitat.cats.where((c) => c.id == id).firstOrNull;
    if (walk == null ||
        cat == null ||
        editing ||
        reducedMotion ||
        id == _activityCatId) {
      return;
    }
    final bowl = habitat.items
        .where(
          (i) =>
              i.id == care['food_bowl'] &&
              i.sku == 'food_bowl' &&
              i.careState['cat_id'] == id &&
              i.isPlaced,
        )
        .firstOrNull;
    if (bowl == null) return;
    final visit = _QuintalMealVisit(meal, bowl.id, (
      bowl.x!,
      bowl.y!,
      bowl.rotation,
    ));
    _catMeals[id] = visit;
    final reaction = meal.refused
        ? null
        : switch (meal.preference) {
            1 => HabitatCatClip.upset,
            4 || 5 => HabitatCatClip.happy,
            6 => HabitatCatClip.dance,
            _ => null,
          };
    final animations = sprites.catCoat(_catCoat(cat));
    await Future.wait([
      animations.preload(
        meal.refused ? HabitatCatClip.upset : HabitatCatClip.eat,
      ),
      if (reaction != null) animations.preload(reaction),
      sprites.preloadReady([
        for (var i = 0; i <= 2; i++) _mealBowlKey(bowl, i),
      ]),
    ]);
    if (!identical(_catMeals[id], visit) || !_mealVisitValid(id, visit)) return;
    final path = habitat.routeTo(walk.next, habitat.accessCells(bowl));
    if (path == null) {
      _catMeals.remove(id);
      return;
    }
    visit.started = true;
    final arrival = walk.goTo(
      bowl.id,
      path,
      meal.refused ? 'refuse' : 'feed',
      placement: visit.placement,
    );
    // The serving tool finishes before the cat starts approaching its bowl.
    walk.pause = 1.35;
    final arrived = await arrival;
    if (arrived &&
        identical(_catMeals[id], visit) &&
        _mealVisitValid(id, visit)) {
      walk.finishFeeding(reaction: reaction);
    }
  }

  Future<void> _visitCatWater(String id, HabitatCatMotion walk) async {
    final cat = habitat.cats.where((c) => c.id == id).firstOrNull;
    if (cat == null) return;
    await sprites.catCoat(_catCoat(cat)).preload(HabitatCatClip.eat);
    final care = habitat.productionCat(id);
    if (_removed ||
        editing ||
        reducedMotion ||
        id == _activityCatId ||
        !habitat.selectedCatIds.contains(id) ||
        walk.targetItemId != null ||
        walk.reaction != null ||
        _catMeals.containsKey(id) ||
        care['water_available'] != true) {
      return;
    }
    final bowl = habitat.items
        .where(
          (i) =>
              i.id == care['water_bowl'] &&
              i.sku == 'water_bowl' &&
              i.careState['cat_id'] == id &&
              i.isPlaced,
        )
        .firstOrNull;
    if (bowl == null) return;
    final path = habitat.routeTo(walk.next, habitat.accessCells(bowl));
    if (path == null) return;
    final arrived = await walk.goTo(
      bowl.id,
      path,
      'drink',
      placement: (bowl.x!, bowl.y!, bowl.rotation),
    );
    if (arrived &&
        !_removed &&
        !editing &&
        !reducedMotion &&
        habitat.productionCat(id)['water_available'] == true) {
      walk.finishFeeding();
    }
  }

  Map<String, dynamic> _residentState(String kind) =>
      habitat
          .productionRows('residents')
          .where((r) => r['kind'] == kind)
          .firstOrNull ??
      {};
  Map<String, dynamic> _residentForTarget(QuintalSceneTarget t) {
    final slot = t.kind == 'orchard'
        ? (t.target == 'apple' ? 0 : 1)
        : int.tryParse(t.target);
    return Map<String, dynamic>.from(
      ((_residentState(t.kind)['animals'] as List?) ?? [])
              .where((a) => a['slot'] == slot)
              .firstOrNull ??
          {},
    );
  }

  QuintalResidentPose _residentPose(String kind, int slot) {
    final state = _residentState(kind);
    final animal = (state['animals'] as List? ?? [])
        .where((a) => a['slot'] == slot)
        .firstOrNull;
    final milking = _productionEffects.any(
      (effect) =>
          effect.isMilking &&
          kind == 'pasture' &&
          effect.target.target == slot.toString(),
    );
    final pose = quintalResidentPose(
      kind,
      slot,
      _residentTimelines['$kind:$slot']?.time(_elapsed) ?? _elapsed,
      fed:
          DateTime.tryParse(animal?['food_until']?.toString() ?? '')
              ?.isAfter(habitat.serverNow) ==
          true,
      still: reducedMotion || editing,
      level: habitat.facilityLevel(kind),
      watered:
          DateTime.tryParse(state['water_until']?.toString() ?? '')
              ?.isAfter(habitat.serverNow) ==
          true,
    );
    if (!milking && pose.clip == 'idle') {
      final scheduled = quintalResidentPose(
        kind,
        slot,
        _elapsed,
        level: habitat.facilityLevel(kind),
      );
      final home = quintalResidentHomes(kind)[slot];
      if (pose.x == home.$1 &&
          pose.y == home.$2 &&
          scheduled.x == home.$1 &&
          scheduled.y == home.$2 &&
          scheduled.clip == 'idle') {
        _residentTimelines['$kind:$slot']?.synchronizeAtRest();
      }
    }
    return milking
        ? QuintalResidentPose(
            pose.x,
            pose.y,
            pose.direction,
            'idle',
            elevation: pose.elevation,
            sheltered: pose.sheltered,
            gatePassage: pose.gatePassage,
            actionTime: pose.actionTime,
          )
        : pose;
  }

  List<QuintalSceneTarget> get _productionTargets {
    final targets = <QuintalSceneTarget>[];
    for (final e in _ambientWorld.productionAreas.entries) {
      final k = e.key, r = e.value;
      final origin = quintalBuildingOrigin(k, r.$1, r.$2);
      void add(String role, double x, double y, [String? id]) =>
          targets.add(QuintalSceneTarget(k, id ?? k, role, x, y));
      if (k == 'pier') {
        add(
          habitat.facilityLevel(k) > 0 ? 'fish' : 'build',
          origin.$1,
          origin.$2,
        );
        continue;
      }
      if (habitat.facilityLevel(k) == 0) {
        add('build', origin.$1, origin.$2);
        continue;
      }
      if (k == 'garden') {
        for (final p in habitat.productionRows('plots')) {
          final slot = (p['slot'] as num).toInt();
          add(
            'plot',
            r.$1 + .2 + (slot % 4) * 1.35,
            r.$2 + .2 + (slot ~/ 4) * 1.35,
            slot.toString(),
          );
        }
      } else if (k == 'coop' || k == 'pasture') {
        add('food', r.$1 + r.$3 - 1.5, r.$2 + 1.0);
        add('water', r.$1 + r.$3 - 1.5, r.$2 + 4.6);
        if (k == 'coop') add('collect', origin.$1, origin.$2);
        for (var i = 0; i < (_residentState(k)['count'] as num? ?? 0); i++) {
          final p = _residentPose(k, i);
          add('resident', r.$1 + p.x, r.$2 + p.y, i.toString());
        }
      } else if (k == 'orchard') {
        add('collect', r.$1 + 1, r.$2 + 1.3, 'apple');
        add('collect', r.$1 + 3, r.$2 + 3.3, 'pear');
      } else {
        add(k, r.$1 + 1.5, r.$2 + 1.5);
      }
    }
    for (final f in habitat.productionRows('facilities')) {
      final kind = f['kind'].toString();
      final area = _ambientWorld.productionAreas[kind];
      final level = habitat.facilityLevel(kind);
      if (area == null ||
          level == 0 ||
          (f['target_level'] as num? ?? 0) <= level) {
        continue;
      }
      final origin = kind == 'garden'
          ? (area.$1 + .2 + 1.5 * 1.35, area.$2 + .2 + level * 1.35)
          : quintalBuildingOrigin(kind, area.$1, area.$2);
      // Separate badge: existing production remains available during works.
      targets.add(
        QuintalSceneTarget(kind, kind, 'build', origin.$1, origin.$2),
      );
    }
    return targets;
  }

  Future<void> _preloadProduction() async {
    await sprites.preloadReady([
      'ui:ready',
      for (final piece in [
        'post-left',
        'post-right',
        for (var i = 0; i < 5; i++) 'leaf-$i',
      ])
        sprites.keyFor('production:crafted-gate-$piece', 3),
      for (final stem in [
        'path_stone',
        'path_stoneCorner',
        'path_stoneEnd',
        'path_stoneCircle',
      ])
        for (var rotation = 0; rotation < 4; rotation++)
          sprites.keyFor(stem, rotation),
      'crate_NE',
      sprites.keyFor('production:crafted-cat-food-0-0', 0),
      sprites.keyFor('production:crafted-cat-water-0-0', 0),
      ...sprites.productionKeys.where(
        (key) =>
            !key.contains('crafted-') ||
            (key.endsWith('-NE') && !key.contains('crafted-cat-')),
      ),
      for (var eggs = 0; eggs <= 2; eggs++)
        sprites.keyFor('production:crafted-nest-$eggs', 3),
    ]);
    for (final a in _residentAnimations.values) {
      await a.initialize();
      await Future.wait([
        a.preload(HabitatCatClip.walk),
        a.preload(HabitatCatClip.eat),
        a.preload(HabitatCatClip.idle),
      ]);
    }
  }

  Offset _productionGround(double x, double y) =>
      groundAnchor(x.floor(), y.floor()) +
      Offset(
        (x - x.floor() - y + y.floor()) * tileWidth / 2,
        (x - x.floor() + y - y.floor()) * tileHeight / 2,
      );
  String? _productionAt(Offset point) => productionObjectAt(point)?.kind;

  void _productionPaths(Canvas canvas) {
    final cells = _ambientWorld.productionPaths;
    // Original stone meshes supply irregular edges and shallow relief.
    // Paint before scenery so feet, fences and buildings always remain above.
    for (final (x, y) in cells) {
      final (stem, rotation) = pathSprite('path_stone', [
        cells.contains((x - 1, y)),
        cells.contains((x + 1, y)),
        cells.contains((x, y - 1)),
        cells.contains((x, y + 1)),
      ]);
      final key = sprites.keyFor(stem, rotation);
      _drawSprite(
        canvas,
        key,
        sprites.placedBounds(key, groundAnchor(x, y), tileWidth / 128),
        colorFilter: HabitatPalette.stone,
      );
    }
  }

  void _abandonedGround(
    Canvas canvas,
    List<_SceneSprite> scene,
    (int, int, int, int) r, {
    required bool repairing,
  }) {
    // Sparse pockets of rubble and weeds fill the future building footprint.
    // Every prop keeps its own ground depth; no giant flattened background image.
    const pockets = [
      (.12, .18),
      (.62, .10),
      (.87, .26),
      (.12, .72),
      (.72, .84),
      (.89, .65),
      (.39, .83),
      (.49, .52),
      (.10, .45),
      (.61, .70),
    ];
    const props = [
      'grass_large_NE',
      'rock_smallA_NE',
      'plant_bushSmall_NE',
      'log_large_NE',
      'grass_leafs_NE',
      'rock_smallB_NE',
      'plant_flatTall_NE',
      'grass_NE',
      'rock_smallFlatA_NE',
      'plant_bushSmall_NE',
    ];
    if (!repairing) {
      // Regrowth occupies the back corners of the future footprint. The
      // central ruins and the entrance remain readable and reachable.
      for (final tree in [
        ('tree_default_dark_NE', .16, .14, 1.05),
        if (r.$3 >= 5) ('tree_small_NE', .82, .20, .78),
      ]) {
        scene.add(
          _SceneSprite(
            tree.$1,
            _productionGround(
              r.$1 + tree.$2 * (r.$3 - 1),
              r.$2 + tree.$3 * (r.$4 - 1),
            ),
            tileWidth * tree.$4 / sprites.bounds(tree.$1).width,
          ),
        );
      }
      for (final piece in [
        ('ruin-fence-a', .14, .34),
        ('ruin-fence-b', .72, .76),
        ('ruin-timber', .80, .20),
      ]) {
        final key = 'production:${piece.$1}';
        scene.add(
          _SceneSprite(
            key,
            _productionGround(
              r.$1 + piece.$2 * (r.$3 - 1),
              r.$2 + piece.$3 * (r.$4 - 1),
            ),
            sprites.worldScale(key, tileWidth),
          ),
        );
      }
    }
    for (var i = 0; i < pockets.length; i++) {
      if (repairing && i != 0 && i != 2 && i != 5) continue;
      final x = r.$1 + pockets[i].$1 * (r.$3 - 1),
          y = r.$2 + pockets[i].$2 * (r.$4 - 1),
          key = props[i],
          ground = _productionGround(x, y);
      scene.add(
        _SceneSprite(
          key,
          ground,
          tileWidth *
              (key.startsWith('plant')
                  ? .42
                  : key.startsWith('log')
                  ? .55
                  : .32) /
              sprites.bounds(key).width,
        ),
      );
    }
  }

  int _constructionTargetLevel(String kind) {
    final row = habitat
        .productionRows('facilities')
        .where((f) => f['kind'] == kind)
        .firstOrNull;
    final active = (row?['target_level'] as num? ?? 0).toInt();
    if (active > 0) return active;
    if (constructionPreviewKind != kind) return 0;
    final offer = habitat
        .productionRows('offers')
        .where((o) => o['id'].toString().startsWith('$kind:'))
        .firstOrNull;
    return int.tryParse(offer?['id'].toString().split(':').last ?? '') ?? 0;
  }

  void _drawConstructionPerimeter(
    Canvas canvas,
    String kind,
    (int, int, int, int) area,
    int current,
    int target,
  ) {
    if (target <= current) return;
    final paths = <Path>[];
    if (kind == 'garden') {
      for (var slot = current * 4; slot < target.clamp(1, 3) * 4; slot++) {
        final x = area.$1 + .2 + slot % 4 * 1.35;
        final y = area.$2 + .2 + slot ~/ 4 * 1.35;
        paths.add(
          Path()..addPolygon([
            for (final corner in [
              (-.56, -.56),
              (.56, -.56),
              (.56, .56),
              (-.56, .56),
            ])
              _productionGround(x + corner.$1, y + corner.$2),
          ], true),
        );
      }
    } else {
      final stem = switch (kind) {
        'coop' => 'coop',
        'pasture' => 'barn',
        'kitchen' => 'kitchen',
        _ => null,
      };
      if (stem == null) return;
      final key = sprites.keyFor(
        'production:crafted-$stem-${target.clamp(1, 2)}-ready',
        0,
      );
      if (!sprites.productionKeys.contains(key)) return;
      final origin = quintalBuildingOrigin(kind, area.$1, area.$2);
      final path = sprites.groundFootprint(
        key,
        _productionGround(origin.$1, origin.$2),
        sprites.worldScale(key, tileWidth),
      );
      if (path != null) paths.add(path);
    }
    for (final path in paths) {
      canvas.drawPath(path, Paint()..color = const Color(0x267b5935));
      final border = Paint()
        ..color = const Color(0xfff3dfa6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final outline = Paint()
        ..color = const Color(0xff795b3c)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      for (final metric in path.computeMetrics()) {
        for (var distance = 0.0; distance < metric.length; distance += 11) {
          final dash = metric.extractPath(
            distance,
            math.min(distance + 7, metric.length),
          );
          canvas.drawPath(dash, outline);
          canvas.drawPath(dash, border);
        }
      }
    }
  }

  void _addProductionScene(Canvas canvas, List<_SceneSprite> scene) {
    if (habitat.production.isEmpty) return;
    _productionPaths(canvas);
    void add(
      String name,
      double x,
      double y,
      double width, {
      bool composed = false,
      double depth = 0,
      double height = 0,
      double modelScale = 1,
      double angle = 0,
      int direction = 0,
      double opacity = 1,
    }) {
      final crafted = name.startsWith('crafted-');
      final key = crafted
          ? sprites.keyFor('production:$name', direction)
          : 'production:$name';
      final lift = height * tileWidth * math.sqrt(3 / 8);
      scene.add(
        _SceneSprite(
          key,
          _productionGround(x, y) - Offset(0, lift),
          (composed || crafted
                  ? sprites.worldScale(key, tileWidth)
                  : tileWidth * width / 320) *
              modelScale,
          depthOffset: depth + lift,
          angle: angle,
          tint: Colors.white.withValues(alpha: opacity),
          selected:
              selectedProduction != null &&
              opacity == 1 &&
              !name.contains('fence') &&
              !name.contains('path') &&
              !name.contains('ground') &&
              (_productionGround(x, y) - productionFocus(selectedProduction!))
                      .distance <
                  tileWidth * .3,
          castsShadow: opacity == 1,
        ),
      );
    }

    void fence(String kind, (int, int, int, int) r) {
      final cells = {
        for (var x = r.$1; x < r.$1 + r.$3; x++)
          for (var y = r.$2; y < r.$2 + r.$4; y++) (x, y),
      };
      for (final (x, y) in cells) {
        for (final edge in [
          (x - 1, y, 'NW'),
          (x, y - 1, 'NE'),
          (x + 1, y, 'SE'),
          (x, y + 1, 'SW'),
        ]) {
          if (cells.contains((edge.$1, edge.$2))) continue;
          // Opening onto the outside path; all remaining segments meet at their mesh feet.
          final entrance = x == r.$1 && edge.$3 == 'NW' && y == r.$2 + 3;
          if (entrance) {
            final count = (_residentState(kind)['count'] as num? ?? 0).toInt();
            final opening = quintalGateOpening([
              for (var slot = 0; slot < count; slot++)
                _residentPose(kind, slot),
            ]);
            final step = (opening * 4).round();
            for (final piece in ['post-left', 'post-right', 'leaf-$step']) {
              final key = sprites.keyFor('production:crafted-gate-$piece', 3);
              final scale = sprites.worldScale(key, tileWidth);
              scene.add(
                _SceneSprite(
                  key,
                  groundAnchor(x, y),
                  scale,
                  depthOffset: sprites.depthCenter(key).dy * scale,
                ),
              );
            }
            continue;
          }
          final key = 'fence_simple_${edge.$3}';
          scene.add(
            _SceneSprite(
              key,
              groundAnchor(x, y),
              tileWidth / 128,
              depthOffset: sprites.depthCenter(key).dy * tileWidth / 128,
            ),
          );
        }
      }
    }

    for (final e in _ambientWorld.productionAreas.entries) {
      final kind = e.key, r = e.value, level = habitat.facilityLevel(e.key);
      final origin = quintalBuildingOrigin(kind, r.$1, r.$2);
      final upgrading =
          level > 0 &&
          habitat
              .productionRows('facilities')
              .any(
                (f) =>
                    f['kind'] == kind &&
                    (f['target_level'] as num? ?? 0) > level,
              );
      _drawConstructionPerimeter(
        canvas,
        kind,
        r,
        level,
        _constructionTargetLevel(kind),
      );
      if (kind == 'pier') {
        add(
          level > 0 ? 'pier-ready' : 'pier-broken',
          origin.$1,
          origin.$2,
          1,
          composed: true,
        );
        continue;
      }
      if (level == 0) {
        final repairing = habitat
            .productionRows('facilities')
            .any(
              (f) => f['kind'] == kind && (f['target_level'] as num? ?? 0) > 0,
            );
        if (kind == 'orchard') {
          for (final offset in [(1.0, 1.0), (3.0, 3.0), (1.0, 3.2)]) {
            add(
              'crafted-orchard-${repairing ? 'clearing' : 'abandoned'}',
              r.$1 + offset.$1,
              r.$2 + offset.$2,
              1,
            );
          }
          continue;
        }
        _abandonedGround(canvas, scene, r, repairing: repairing);
        final custom = switch (kind) {
          'coop' => 'coop-1',
          'pasture' => 'barn-1',
          'kitchen' => 'kitchen-1',
          'market' => 'post',
          _ => null,
        };
        add(
          custom != null
              ? 'crafted-$custom-${repairing ? 'building' : 'abandoned'}'
              : repairing
              ? 'construction-site'
              : '$kind-ruins',
          origin.$1,
          origin.$2,
          1,
          composed: true,
        );
        continue;
      }
      if (kind == 'garden') {
        // Future beds are visibly being cleared, but have no planting target
        // until the server completes the expansion and publishes their rows.
        final targetLevel =
            habitat
                .productionRows('facilities')
                .where((f) => f['kind'] == kind)
                .map((f) => (f['target_level'] as num? ?? 0).toInt())
                .firstOrNull ??
            0;
        final existingSlots = habitat
            .productionRows('plots')
            .map((p) => (p['slot'] as num).toInt())
            .toSet();
        if (upgrading) {
          for (var slot = 0; slot < targetLevel.clamp(0, 3) * 4; slot++) {
            if (existingSlots.contains(slot)) continue;
            final x = r.$1 + .2 + slot % 4 * 1.35;
            final y = r.$2 + .2 + slot ~/ 4 * 1.35;
            final key = sprites.keyFor(
              'production:crafted-garden-bed-dry-empty',
              0,
            );
            _drawSprite(
              canvas,
              key,
              sprites.placedBounds(
                key,
                _productionGround(x, y),
                sprites.worldScale(key, tileWidth),
              ),
            );
            _gardenClearingProps(scene, x, y, 1);
          }
        }
        for (final p in habitat.productionRows('plots')) {
          final slot = (p['slot'] as num).toInt(),
              x = r.$1 + .2 + slot % 4 * 1.35,
              y = r.$2 + .2 + slot ~/ 4 * 1.35;
          final soilKey = sprites.keyFor(
            'production:crafted-garden-bed-${p['watered'] == true ? 'wet' : 'dry'}-${p['crop'] == null ? 'empty' : 'planted'}',
            0,
          );
          _drawSprite(
            canvas,
            soilKey,
            sprites.placedBounds(
              soilKey,
              _productionGround(x, y),
              sprites.worldScale(soilKey, tileWidth),
            ),
          );
          final clearing = _gardenMotion.clearingOpacity(
            slot,
            _elapsed,
            still: reducedMotion || editing,
          );
          if (clearing > 0) _gardenClearingProps(scene, x, y, clearing);
          if (p['crop'] == null) continue;
          final crop = _cropSpriteName(p);
          add(
            crop,
            x,
            y,
            1,
            height: .055,
            modelScale: _quintalCropScale(p['crop']),
            angle: quintalFoliageAngle(
              _elapsed,
              slot,
              still: reducedMotion || editing,
              sprouted: !crop.endsWith('-0'),
            ),
          );
        }
        // The server has already emptied the plot. Keep only a visual snapshot
        // in world depth order, independent of the currently selected object.
        for (final effect in _productionEffects.where((e) => e.isHarvest)) {
          final t = effect.target;
          final root =
              !reducedMotion && const {'carrot', 'turnip'}.contains(t.crop);
          final key = sprites.keyFor(
            'production:crafted-crop-${t.crop}-${root ? 'harvest' : '3'}',
            0,
          );
          final ground = _productionGround(t.x, t.y);
          final lift =
              (.055 +
                  effect.harvestLift(_elapsed, reducedMotion: reducedMotion) *
                      _quintalCropScale(t.crop!)) *
              tileWidth *
              math.sqrt(3 / 8);
          scene.add(
            _SceneSprite(
              key,
              ground - Offset(0, lift),
              sprites.worldScale(key, tileWidth) * _quintalCropScale(t.crop!),
              depthOffset: lift,
              castsShadow: false,
              clipBottom: root
                  ? ground.dy - .055 * tileWidth * math.sqrt(3 / 8)
                  : null,
              tint: Colors.white.withValues(
                alpha: effect.harvestOpacity(_elapsed),
              ),
            ),
          );
        }
      } else if (kind == 'coop' || kind == 'pasture') {
        final state = _residentState(kind), cow = kind == 'pasture';
        final stem =
            'crafted-${cow ? 'barn' : 'coop'}-${upgrading ? 'upgrading' : '${level.clamp(1, 2)}-ready'}';
        final halfDepth = quintalShelterDoor(kind, level) - .55;
        add(
          '$stem-back',
          origin.$1,
          origin.$2,
          1,
          depth: -halfDepth * tileHeight / 2,
          composed: true,
        );
        add(
          '$stem-front',
          origin.$1,
          origin.$2,
          1,
          depth: halfDepth * tileHeight / 2 + tileWidth * .015,
          composed: true,
        );
        fence(kind, r);
        for (var i = 0; i < (state['count'] as num? ?? 0); i++) {
          final pose = _residentPose(kind, i);
          final animation =
              _residentAnimations[cow
                  ? 'cow'
                  : i.isEven
                  ? 'hen-white'
                  : 'hen-brown']!;
          final scratching = pose.clip == 'scratch';
          final frame = animation.frame(
            pose.clip == 'walk' || scratching && pose.actionTime % 1 < .3
                ? HabitatCatClip.walk
                : pose.clip == 'eat' || scratching
                ? HabitatCatClip.eat
                : HabitatCatClip.idle,
            reducedMotion
                ? 0
                : scratching
                ? pose.actionTime
                : _elapsed,
            pose.direction,
          );
          if (scratching) {
            final ground = _productionGround(r.$1 + pose.x, r.$2 + pose.y);
            final phase = pose.actionTime % 1;
            for (var speck = 0; speck < 3; speck++) {
              final t = (phase - speck * .07).clamp(0.0, 1.0);
              if (t <= 0 || t >= .55) continue;
              canvas.drawCircle(
                ground +
                    Offset(
                      -tileWidth * (.04 + t * .2),
                      tileHeight * (speck - 1) * .08 -
                          math.sin(t / .55 * math.pi) * tileWidth * .04,
                    ),
                tileWidth * .016 * (1 - t / .55),
                Paint()
                  ..color = const Color(0xffb49b6b)
                      .withValues(alpha: 1 - t / .55),
              );
            }
          }
          if (frame != null) {
            scene.add(
              _SceneSprite(
                'animal-cat',
                _productionGround(r.$1 + pose.x, r.$2 + pose.y),
                tileWidth * (cow ? .86 : .40) / animation.restHeight,
                selected:
                    selectedProduction?.kind == kind &&
                    selectedProduction?.role == 'resident' &&
                    selectedProduction?.target == i.toString(),
                catFrame: frame,
                elevation: pose.elevation * tileWidth * math.sqrt(3 / 8),
                depthOffset:
                    -pose.elevation * tileWidth * math.sqrt(3 / 8) * .58,
              ),
            );
          }
        }
        if (!cow) {
          final residents = state['animals'] as List? ?? [];
          final count = (state['count'] as num? ?? 0).toInt();
          final w = 1.50 + (level - 1) * .60;
          for (var slot = 0; slot < count; slot++) {
            final animal = residents
                .where((a) => a['slot'] == slot)
                .firstOrNull;
            final eggs = ((animal?['ready'] as num?)?.toInt() ?? 0).clamp(0, 2);
            add(
              'crafted-nest-$eggs',
              r.$1 + .8 + w / 2 + .24,
              r.$2 + .55 + (slot - (count - 1) / 2) * .50,
              1,
              height: .46,
              direction: 3,
              depth: tileWidth * .03,
            );
          }
        }
        if (cow) {
          for (final effect in _productionEffects.where((e) => e.isMilking)) {
            final slot = int.tryParse(effect.target.target);
            if (slot == null || slot >= (state['count'] as num? ?? 0)) continue;
            final pose = _residentPose(kind, slot);
            final pickup = reducedMotion
                ? 0.0
                : ((_elapsed - effect.startedAt - 1.85) / .25).clamp(0.0, 1.0);
            add(
              'crafted-bucket-${effect.milkStage(_elapsed)}',
              r.$1 + pose.x + .40,
              r.$2 + pose.y + .25,
              1,
              height: pose.elevation + pickup * .25,
            );
          }
        }
        final fed = (state['fed_count'] as num? ?? 0).toInt();
        final count = (state['count'] as num? ?? 0).toInt();
        final amount = fed == 0
            ? 0
            : fed < count
            ? 1
            : 2;
        final prefix = cow ? 'cow' : 'coop';
        add('crafted-$prefix-food-$amount', r.$1 + r.$3 - 1.5, r.$2 + 1, 1);
        final water =
            DateTime.tryParse(state['water_until']?.toString() ?? '')
                ?.isAfter(habitat.serverNow) ==
            true;
        add(
          'crafted-$prefix-water-${water ? 2 : 0}',
          r.$1 + r.$3 - 1.5,
          r.$2 + 4.6,
          1,
        );
      } else if (kind == 'kitchen' || kind == 'market') {
        final x = r.$1 + 1.5, y = r.$2 + 1.5;
        final tasks = habitat
            .productionRows('tasks')
            .where((t) => t['kind'] == (kind == 'kitchen' ? 'cook' : 'order'))
            .toList();
        bool done(Map t) =>
            t['status'] == 'ready' ||
            DateTime.tryParse(t['ready_at']?.toString() ?? '')
                    ?.isAfter(habitat.serverNow) ==
                false;
        final ready = tasks.where(done).length;
        final active = tasks.any(
          (t) =>
              !done(t) &&
              DateTime.tryParse(t['started_at']?.toString() ?? '')
                      ?.isAfter(habitat.serverNow) ==
                  false,
        );
        final queued = tasks.any(
          (t) =>
              DateTime.tryParse(t['started_at']?.toString() ?? '')
                  ?.isAfter(habitat.serverNow) ==
              true,
        );
        if (kind == 'kitchen') {
          add(
            'crafted-kitchen-${upgrading ? 'upgrading' : '${level.clamp(1, 2)}-ready'}',
            x,
            y,
            1,
          );
          add(
            active ? 'crafted-pot-base' : 'crafted-pot-0',
            x - .64,
            y,
            1,
            height: .88,
            // The pan rests on the stove: its negative X offset must not
            // sort it behind the single sprite containing the stove top.
            depth: tileHeight * .32 + tileWidth * .01,
          );
          if (active) {
            add(
              'crafted-pot-lid',
              x - .64,
              y,
              1,
              height:
                  .88 +
                  quintalLidLift(_elapsed, still: reducedMotion || editing),
              depth: tileHeight * .32 + tileWidth * .012,
            );
          }
          if (ready > 0) {
            add(
              'crafted-portions-${ready == 1 ? 1 : 3}',
              x + .55,
              y + .12,
              1,
              height: .875,
              depth: tileWidth * .04,
            );
          }
          if (queued) {
            add(
              'crafted-queue-1',
              x + .65,
              y - .30,
              1,
              height: .875,
              depth: tileWidth * .10,
            );
          }
        } else {
          final recovery = _productionEffects
              .where((e) => e.isMarketRecovery)
              .lastOrNull;
          final progress =
              recovery?.transitionProgress(
                _elapsed,
                reducedMotion: reducedMotion || editing,
              ) ??
              1.0;
          if (progress < 1) {
            add('crafted-post-building', x, y, 1, opacity: 1 - progress);
          }
          add('crafted-post-ready', x, y, 1, opacity: progress);
          // Only confirmed operations leave this transient snapshot behind.
          // Pending/failed requests keep the server's ready crate in place.
          final pickup = _productionEffects
              .where((e) => e.isMarketPickup)
              .lastOrNull;
          if (pickup != null && ready == 0) {
            final p = pickup.transitionProgress(
              _elapsed,
              reducedMotion: reducedMotion || editing,
            );
            if (p < 1) {
              add(
                'crafted-parcel',
                x + .30 + .4 * p,
                y + .30 + .1 * p,
                1,
                height: .825 + .15 * p,
                depth: tileWidth * .04,
                opacity: 1 - p,
              );
            }
          }
          if (ready > 0) {
            add(
              'crafted-parcel',
              x + .30,
              y + .30,
              1,
              height: .825,
              depth: tileWidth * .04,
            );
          }
        }
      } else if (kind == 'orchard') {
        // Recovered undergrowth stays at the back edge, outside both trees'
        // collection targets and the path through the orchard.
        for (final edge in [(.7, .1), (3.3, .1)]) {
          add('crafted-orchard-ready', r.$1 + edge.$1, r.$2 + edge.$2, 1);
        }
        final state = _residentState(kind),
            animals = state['animals'] as List? ?? [];
        for (var i = 0; i < 2; i++) {
          final tree = animals.where((a) => a['slot'] == i).firstOrNull;
          final ready = tree?['ready'] as num? ?? 0;
          final fruit = i == 0 ? 'apple' : 'pear';
          final x = r.$1 + 1 + i * 2.0, y = r.$2 + 1.3 + i * 2.0;
          add('crafted-$fruit-tree-empty', x, y, 1);
          if (ready > 0) {
            add('crafted-$fruit-fruits-ready', x, y, 1, depth: tileWidth * .04);
          } else {
            final progress = tree == null
                ? 0.0
                : QuintalTimedProgress.fromRow(Map<String, dynamic>.from(tree))
                          ?.fraction(habitat.serverNow) ??
                      ((tree['progress'] as num? ?? 0) / 28800).clamp(0.0, 1.0);
            // Interpolate green fruit sizes using server-projected progress.
            // Even a locally elapsed deadline never invents mature fruit.
            final phase = (progress * 3).clamp(0.0, 3.0);
            final step = phase.floor().clamp(0, 2);
            const stages = ['bud', 'growing', 'full'];
            if (step > 0) {
              add(
                'crafted-$fruit-fruits-${stages[step - 1]}',
                x,
                y,
                1,
                depth: tileWidth * .04,
                opacity: 1 - (phase - step),
              );
            }
            add(
              'crafted-$fruit-fruits-${stages[step]}',
              x,
              y,
              1,
              depth: tileWidth * .04,
              opacity: phase - step,
            );
            final pickup = _productionEffects
                .where((e) => e.isFruitPickup && e.target.target == fruit)
                .lastOrNull;
            if (pickup != null) {
              final p = pickup.transitionProgress(
                _elapsed,
                reducedMotion: reducedMotion || editing,
              );
              if (p < 1) {
                add(
                  'crafted-$fruit-fruits-ready',
                  x + .25 * p,
                  y + .25 * p,
                  1,
                  height: -.65 * p,
                  depth: tileWidth * .04,
                  opacity: 1 - p,
                );
              }
            }
          }
        }
      }
    }
  }

  bool _targetReady(QuintalSceneTarget t) {
    if ((t.role == 'resident' && t.kind == 'pasture') ||
        (t.role == 'collect' && t.kind == 'orchard')) {
      return (_residentForTarget(t)['ready'] as num? ?? 0) > 0;
    }
    if (t.role == 'plot') {
      final p = habitat
          .productionRows('plots')
          .where((p) => p['slot'].toString() == t.target)
          .firstOrNull;
      return p?['crop'] != null &&
          DateTime.tryParse(p?['ready_at']?.toString() ?? '')
                  ?.isAfter(habitat.serverNow) ==
              false;
    }
    if (t.role == 'collect') {
      return (_residentState(t.kind)['ready'] as num? ?? 0) > 0;
    }
    if (t.role != 'build' && (t.kind == 'kitchen' || t.kind == 'market')) {
      return habitat
          .productionRows('tasks')
          .any(
            (task) =>
                task['kind'] == (t.kind == 'kitchen' ? 'cook' : 'order') &&
                (task['status'] == 'ready' ||
                    DateTime.tryParse(task['ready_at']?.toString() ?? '')
                            ?.isAfter(habitat.serverNow) ==
                        false),
          );
    }
    if (t.role == 'build') {
      return habitat
          .productionRows('facilities')
          .any(
            (f) =>
                f['kind'] == t.kind &&
                (f['target_level'] as num? ?? 0) > 0 &&
                DateTime.tryParse(f['ready_at']?.toString() ?? '')
                        ?.isAfter(habitat.serverNow) ==
                    false,
          );
    }
    return false;
  }

  bool _targetWaiting(QuintalSceneTarget t) {
    bool future(dynamic at) =>
        DateTime.tryParse(at?.toString() ?? '')?.isAfter(habitat.serverNow) ==
        true;
    if ((t.role == 'resident' && t.kind == 'pasture') ||
        (t.role == 'collect' && t.kind == 'orchard')) {
      return future(_residentForTarget(t)['next_ready_at']);
    }
    if (t.role == 'plot') {
      return habitat
          .productionRows('plots')
          .any(
            (p) =>
                p['slot'].toString() == t.target &&
                p['crop'] != null &&
                future(p['ready_at']),
          );
    }
    if (t.role == 'collect') {
      final state = _residentState(t.kind);
      return state['production_status'] == 'producing' &&
          state['next_ready_at'] != null;
    }
    if (t.role == 'build') {
      return habitat
          .productionRows('facilities')
          .any(
            (f) =>
                f['kind'] == t.kind &&
                (f['target_level'] as num? ?? 0) > 0 &&
                future(f['ready_at']),
          );
    }
    if (t.kind == 'kitchen' || t.kind == 'market') {
      return habitat
          .productionRows('tasks')
          .any(
            (task) =>
                task['kind'] == (t.kind == 'kitchen' ? 'cook' : 'order') &&
                future(task['ready_at']),
          );
    }
    return false;
  }

  Rect _productionBadgeRect(QuintalSceneTarget t) => Rect.fromCenter(
    center: productionFocus(t) - Offset(0, productionObjectHeight(t) + 54),
    width: 42,
    height: 42,
  );

  bool _hasPendingProduction(QuintalTimedProgress? progress) {
    if (progress == null) return false;
    final pause = progress.pauseAt(habitat.serverNow);
    return pause != 'full' &&
        (pause != null || progress.end.isAfter(habitat.serverNow));
  }

  Rect _productionBadgeHitRect(QuintalSceneTarget target) {
    final rect = _productionBadgeRect(target);
    if (!_targetReady(target) ||
        !_hasPendingProduction(_targetProgress(target))) {
      return rect;
    }
    return Rect.fromLTRB(
      rect.left - 24,
      rect.top,
      rect.right + 24,
      rect.bottom,
    );
  }

  QuintalTimedProgress? _targetProgress(QuintalSceneTarget t) {
    Map<String, dynamic>? row;
    if ((t.role == 'resident' && t.kind == 'pasture') ||
        (t.role == 'collect' && t.kind == 'orchard')) {
      row = _residentForTarget(t);
    } else if (t.role == 'plot') {
      row = habitat
          .productionRows('plots')
          .where((p) => p['slot'].toString() == t.target)
          .firstOrNull;
    } else if (t.role == 'collect') {
      row = _residentState(t.kind);
    } else if (t.role == 'build') {
      row = habitat
          .productionRows('facilities')
          .where(
            (f) => f['kind'] == t.kind && (f['target_level'] as num? ?? 0) > 0,
          )
          .firstOrNull;
    } else if (t.kind == 'kitchen' || t.kind == 'market') {
      final tasks =
          habitat
              .productionRows('tasks')
              .where(
                (task) =>
                    task['kind'] == (t.kind == 'kitchen' ? 'cook' : 'order'),
              )
              .map(QuintalTimedProgress.fromRow)
              .whereType<QuintalTimedProgress>()
              .where((task) => task.end.isAfter(habitat.serverNow))
              .toList()
            ..sort((a, b) => a.end.compareTo(b.end));
      return tasks.firstOrNull;
    }
    return row == null ? null : QuintalTimedProgress.fromRow(row);
  }

  void _drawProductionProgress(
    Canvas canvas,
    Rect badge,
    QuintalTimedProgress progress,
  ) {
    final now = habitat.serverNow;
    final text = TextPainter(
      text: TextSpan(
        text: progress.label(now),
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xfffff9ec),
          shadows: [Shadow(color: Color(0xff263d22), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final bounds = Rect.fromCenter(
      center: Offset(badge.center.dx, badge.bottom + 11),
      width: math.max(96, text.width + 16),
      height: 24,
    );
    final outline = RRect.fromRectAndRadius(bounds, const Radius.circular(8));
    canvas.drawRRect(outline, Paint()..color = const Color(0xff425139));
    final fraction = progress.fraction(now);
    if (fraction != null) {
      canvas.save();
      canvas.clipRRect(outline);
      canvas.drawRect(
        Rect.fromLTWH(
          bounds.left,
          bounds.top,
          bounds.width * fraction,
          bounds.height,
        ),
        Paint()..color = const Color(0xff52783c),
      );
      canvas.restore();
    }
    canvas.drawRRect(
      outline,
      Paint()
        ..color = const Color(0xffdfc79c)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    text.paint(canvas, bounds.center - Offset(text.width / 2, text.height / 2));
    text.dispose();
  }

  List<Rect> get _productionToolClearances {
    final areas = <Rect>[];
    for (final effect in _productionEffects.where((e) => e.toolKind != null)) {
      final anchor =
          productionFocus(effect.target) -
          Offset(0, productionObjectHeight(effect.target) * .35);
      var area = Rect.fromCircle(center: anchor, radius: tileWidth * .22);
      // Reserve the entire tilt cycle so nearby indicators never flicker.
      for (var stage = 0; stage < 5; stage++) {
        final key = sprites.keyFor(
          'production:crafted-tool-${effect.toolKind}-$stage',
          0,
        );
        if (!sprites.productionKeys.contains(key)) continue;
        area = area.expandToInclude(
          sprites.placedBounds(
            key,
            effect.toolOutlet(anchor, tileWidth),
            sprites.worldScale(key, tileWidth) * .8,
          ),
        );
      }
      areas.add(area.inflate(5));
    }
    return areas;
  }

  bool _productionIndicatorVisible(
    QuintalSceneTarget target,
    List<Rect> tools,
  ) {
    if (productionToolActive(target)) return false;
    if (tools.isEmpty) return true;
    var rect = _productionBadgeHitRect(target);
    if (_targetProgress(target) != null) {
      rect = rect.expandToInclude(
        Rect.fromCenter(
          center: Offset(rect.center.dx, rect.bottom + 11),
          width: 112,
          height: 24,
        ),
      );
    }
    return !tools.any((tool) => tool.overlaps(rect));
  }

  void _drawProductionLabels(Canvas canvas) {
    if (habitat.production.isEmpty || editing || activityInProgress) return;
    final toolAreas = _productionToolClearances;
    for (final target in productionTargets) {
      if (!_productionIndicatorVisible(target, toolAreas)) continue;
      final ready = _targetReady(target);
      final progress = _targetProgress(target);
      if (!ready && !_targetWaiting(target) && progress == null) continue;
      final rect = _productionBadgeRect(target);
      if (!ready) {
        QuintalClockPainter.draw(canvas, rect);
        if (progress != null) _drawProductionProgress(canvas, rect, progress);
        continue;
      }
      final simultaneous = _hasPendingProduction(progress);
      if (simultaneous) {
        QuintalClockPainter.draw(canvas, rect.shift(const Offset(-24, 0)));
        _drawProductionProgress(canvas, rect, progress!);
      }
      final readyRect = simultaneous ? rect.shift(const Offset(24, 0)) : rect;
      final badge = sprites.cached('ui:ready');
      if (badge != null) {
        canvas.drawImageRect(
          badge,
          Rect.fromLTWH(0, 0, badge.width.toDouble(), badge.height.toDouble()),
          readyRect,
          Paint()..filterQuality = FilterQuality.high,
        );
      }
    }
  }
}

class _QuintalMealVisit {
  _QuintalMealVisit(this.meal, this.bowlId, this.placement);
  final QuintalCatMeal meal;
  final String bowlId;
  final (int, int, int) placement;
  bool started = false;
}
