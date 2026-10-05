import 'dart:math';

import 'package:catlogue/game/habitat_cat_animations.dart';
import 'package:catlogue/game/habitat_cat_motion.dart';
import 'package:catlogue/game/habitat_game.dart';
import 'package:catlogue/game/habitat_sprites.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('moving a reserved item cancels its visit and releases the cat', () {
    final session = SessionStore();
    final store = CatStore(session);
    final habitat = HabitatService(session, store)
      ..items = [const HabitatItem(id: 'bed', sku: 'cat_bed', x: 3, y: 3)]
      ..selectedCatIds = ['cat']
      ..catAnchors = {'cat': (1, 1)};
    final sprites = HabitatSprites();
    final game = HabitatGame(habitat, sprites);
    game.update(0);
    expect(game.inviteToFurniture('bed'), isTrue);
    expect(game.inviteToFurniture('bed'), isFalse);
    habitat.items[0] = habitat.items[0].at(5, 3, 0);
    game.update(0);
    expect(game.inviteToFurniture('bed'), isTrue);
    game.onRemove();
    sprites.catAnimations.dispose();
    habitat.dispose();
    store.dispose();
    session.dispose();
  });
  test(
    'feeding waits for arrival and confirmation before playing eat',
    () async {
      final motion = HabitatCatMotion((1, 1));
      final arrived = motion.goTo('bowl', [(2, 1), (3, 1)], 'feed');
      var reached = false;
      arrived.then((value) => reached = value);
      final random = Random(1);
      motion.advance(0.5, random, (_, _) => true);
      expect(reached, isFalse);
      expect(motion.clip, HabitatCatClip.walk);
      for (var i = 0; i < 30; i++) {
        motion.advance(0.1, random, (_, _) => true);
      }
      expect(await arrived, isTrue);
      expect(motion.current, (3, 1));
      expect(motion.clip, HabitatCatClip.idle);
      motion.advance(30, random, (_, _) => true);
      expect(motion.awaitingConsumption, isTrue);
      motion.finishFeeding();
      expect(motion.clip, HabitatCatClip.eat);
      motion.advance(3.1, random, (_, _) => true);
      expect(motion.targetItemId, isNull);
      expect(motion.anchor, (1, 1));
    },
  );

  test(
    'blocked or removed furniture cancels arrival without consuming food',
    () async {
      final motion = HabitatCatMotion((1, 1));
      final blocked = motion.goTo('bowl', [(2, 1)], 'feed');
      motion.advance(0.1, Random(1), (_, _) => false);
      expect(await blocked, isFalse);
      expect(motion.current, (1, 1));
      final removed = motion.goTo('bed', [(2, 1)], 'rest');
      motion.cancelVisit();
      expect(await removed, isFalse);
      expect(motion.targetItemId, isNull);
    },
  );

  test('rest and play reserve furniture until the visit finishes', () async {
    final motion = HabitatCatMotion((1, 1));
    final arrival = motion.goTo('crate', [], 'play');
    motion.advance(0, Random(1), (_, _) => true);
    expect(await arrival, isTrue);
    expect(motion.clip, HabitatCatClip.play);
    expect(motion.targetItemId, 'crate');
    motion.advance(9, Random(1), (_, _) => true);
    expect(motion.visiting, isFalse);
    expect(motion.targetItemId, isNull);
  });

  test(
    'water blocks navigation and bridge rotation controls its entrances',
    () {
      final session = SessionStore();
      final store = CatStore(session);
      final habitat = HabitatService(session, store);
      habitat.items = [
        for (var x = 2; x <= 3; x++)
          for (var y = 2; y <= 3; y++)
            HabitatItem(id: 'water-$x-$y', sku: 'water_tile', x: x, y: y),
      ];
      expect(habitat.isFreeForCat(2, 2), isFalse);
      const bridge = HabitatItem(id: 'bridge', sku: 'wood_bridge', x: 2, y: 2);
      habitat.items.add(bridge);
      expect(habitat.layoutProblem(habitat.items), isNull);
      expect(habitat.isFreeForCat(2, 2), isTrue);
      expect(habitat.canTraverse((1, 2), (2, 2)), isTrue);
      expect(habitat.canTraverse((2, 1), (2, 2)), isFalse);
      habitat.items[4] = bridge.at(2, 2, 1);
      expect(habitat.canTraverse((1, 2), (2, 2)), isFalse);
      expect(habitat.canTraverse((2, 1), (2, 2)), isTrue);
      expect(habitat.layoutProblem(habitat.items.sublist(1)), isNotNull);
      expect(
        habitat.canPlace(
          const HabitatItem(id: 'path', sku: 'wood_path'),
          2,
          2,
          0,
        ),
        isFalse,
      );
      habitat.dispose();
      store.dispose();
      session.dispose();
    },
  );

  test(
    'growth survives layout moves and cached care is never client awarded',
    () {
      final session = SessionStore();
      final store = CatStore(session);
      final habitat = HabitatService(session, store);
      final plant = HabitatItem(
        id: 'plant',
        sku: 'leaf_garden',
        careState: {
          'grow_at': DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        },
      );
      expect(habitat.spriteFor(plant), 'crops_leafsStageB');
      expect(habitat.canWater(plant), isFalse);
      expect(plant.at(1, 1, 2).careState, plant.careState);
      expect(HabitatItem.fromMap(plant.toMap()).careState, plant.careState);
      expect(habitat.affinity('cat'), 0);
      expect(habitat.freePortions, 3);
      habitat.dispose();
      store.dispose();
      session.dispose();
    },
  );
}
