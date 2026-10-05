import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/game/habitat_world.dart';
import 'package:catlogue/services/habitat_service.dart';

void main() {
  test('river bends share at least two cells in every expansion', () {
    for (var level = 0; level <= 3; level++) {
      final world = HabitatWorld(HabitatService.yardCells(level));
      for (var y = -60; y < 60; y++) {
        final previous = world.riverColumns(y - 1).toSet();
        final current = world.riverColumns(y).toSet();
        expect(current.intersection(previous).length, greaterThanOrEqualTo(2));
        if (world.riverX(y) != world.riverX(y - 1)) {
          // Two complete transition rows must share the widened elbow.
          expect(current.length, greaterThanOrEqualTo(3));
          expect(previous.length, greaterThanOrEqualTo(3));
          expect(
            current.intersection(previous).length,
            greaterThanOrEqualTo(3),
          );
        }

        expect(current.every((x) => !world.editable.contains((x, y))), true);
      }
    }
  });
  test('camera outskirts have stable varied scenery without occupying the expanded yard', () {
    for (var level = 0; level <= 3; level++) {
      final cells = HabitatService.yardCells(level);
      final world = HabitatWorld(cells);
      for (final area in [
        (-45, -45, -25, -25),
        (25, 25, 45, 45),
        (-45, 25, -25, 45),
        (25, -45, 45, -25),
      ]) {
        final first = world
            .decorationsWithin(area.$1, area.$2, area.$3, area.$4)
            .toList();
        expect(first.length, greaterThan(70));
        expect(first.map((p) => p.$3).toSet().length, greaterThan(12));
        expect(first.map((p) => p.$4).toSet().length, greaterThan(40));
        expect(first.any((p) => cells.contains((p.$1, p.$2))), false);
        expect(
          world.decorationsWithin(area.$1, area.$2, area.$3, area.$4).toList(),
          first,
        );
      }
    }
  });
  test('all provided cozy visitor species have timed routines outside the editable yard', () {
    final seen = <String>{};
    for (var level = 0; level <= 3; level++) {
      final cells = HabitatService.yardCells(level);
      final world = HabitatWorld(cells);
      for (var second = 0; second < 1500; second++) {
        for (final visitor in world.visitors(second.toDouble())) {
          seen.add(visitor.species);
          if (!visitor.flying &&
              visitor.species != 'bee' &&
              visitor.species != 'parrot') {
            expect(
              cells.contains((visitor.x.round(), visitor.y.round())),
              false,
            );
          }
        }
      }
    }
    expect(seen, {
      'dog',
      'bunny',
      'chick',
      'deer',
      'fox',
      'beaver',
      'parrot',
      'fish',
      'bee',
    });
  });
  test('scenery and gifts stay outside every expansion and leave playable land clear', () {
    for (var level = 0; level <= 3; level++) {
      final cells = HabitatService.yardCells(level);
      final world = HabitatWorld(cells);
      expect(cells.contains(world.giftCell), false);
      expect(world.decorations.any((d) => cells.contains((d.$1, d.$2))), false);
      expect(world.river.any(cells.contains), false);
      expect(
        world.decorations.any((d) => (d.$1, d.$2) == world.giftCell),
        false,
      );
    }
  });
  test('visitors enter offscreen, use both banks and several routines simultaneously', () {
    const bounds = (-12.0, -13.0, 20.0, 22.0);
    final ids = <String>{}, routines = <String>{}, banks = <bool>{};
    var simultaneous = false;
    for (var seed = 0; seed < 6; seed++) {
      final world = HabitatWorld(HabitatService.yardCells(0), seed: seed);
      final previous = <String, HabitatVisitorPose>{};
      for (var tick = 0; tick < 3600; tick++) {
        final time = tick * .5;
        final poses = world.visitors(time, bounds: bounds).toList();
        simultaneous |=
            poses.where((v) => !v.flying && v.species != 'fish').length > 1;
        for (final pose in poses) {
          final key = '$seed:${pose.id}';
          if (ids.add(key)) {
            expect(
              pose.x < bounds.$1 ||
                  pose.x > bounds.$3 ||
                  pose.y < bounds.$2 ||
                  pose.y > bounds.$4,
              true,
              reason: '$key must enter offscreen',
            );
          }
          routines.add(pose.routine);
          final old = previous[pose.id];
          if (old != null) {
            expect(
              (pose.x - old.x).abs() + (pose.y - old.y).abs(),
              lessThan(1.6),
              reason: '$key must not teleport at a routine transition',
            );
            expect((pose.elevation - old.elevation).abs(), lessThan(.8));
          }
          previous[pose.id] = pose;
          if (!pose.flying &&
              pose.species != 'fish' &&
              pose.species != 'parrot' &&
              pose.species != 'bee') {
            expect(
              world.editable.contains((pose.x.round(), pose.y.round())),
              false,
            );
            expect(world.isRiverCell(pose.x.round(), pose.y.round()), false);
            banks.add(pose.x < world.riverX(pose.y.floor()));
          }
        }
        for (final id in previous.keys.toList()) {
          if (!poses.any((v) => v.id == id)) {
            final last = previous.remove(id)!;
            expect(
              last.x < bounds.$1 ||
                  last.x > bounds.$3 ||
                  last.y < bounds.$2 ||
                  last.y > bounds.$4,
              true,
              reason: '$id must leave offscreen',
            );
          }
        }
      }
    }
    expect(simultaneous, true);
    expect(banks, {true, false});
    expect(
      routines,
      containsAll([
        'drink',
        'forage',
        'wander',
        'rest',
        'watch_cats',
        'pollinate',
        'land_and_watch',
        'swim',
      ]),
    );
  });

  test('panning never replans an animal already walking', () {
    final world = HabitatWorld(HabitatService.yardCells(0));
    final first = world.visitors(0, bounds: (-12, -13, 20, 22)).first;
    final next = world.visitors(.1, bounds: (-60, -60, 60, 60)).first;
    expect(first.id, next.id);
    expect((first.x - next.x).abs() + (first.y - next.y).abs(), lessThan(.2));
  });

  test('whole scenery footprints keep clear of water, fences and visitor corridors', () {
    for (var level = 0; level <= 3; level++) {
      final world = HabitatWorld(HabitatService.yardCells(level));
      for (final prop in world.decorationsWithin(-30, -30, 30, 30)) {
        expect(world.decorationFits(prop.$1, prop.$2, prop.$3, prop.$4), true);
      }
    }
  });

  test('solid roots do not intersect, including scenery chunk boundaries', () {
    final world = HabitatWorld(HabitatService.yardCells(0));
    final props = world
        .decorationsWithin(-24, -24, 24, 24)
        .where((p) => world.isSolidDecoration(p.$3))
        .toList();
    for (var i = 0; i < props.length; i++) {
      final a = props[i], aj = world.decorationOffset(a.$1, a.$2);
      for (var j = i + 1; j < props.length; j++) {
        final b = props[j], bj = world.decorationOffset(b.$1, b.$2);
        final dx = a.$1 + aj.$1 - b.$1 - bj.$1,
            dy = a.$2 + aj.$2 - b.$2 - bj.$2;
        final radius =
            world.decorationRadius(a.$3, a.$4) +
            world.decorationRadius(b.$3, b.$4);
        expect(
          dx * dx + dy * dy,
          greaterThanOrEqualTo(radius * radius),
          reason: '${a.$3} and ${b.$3} have intersecting roots',
        );
      }
    }
  });

  test(
    'gift couriers arrive and depart outside the viewport on either side',
    () {
      final world = HabitatWorld(HabitatService.yardCells(0));
      const bounds = (-12.0, -13.0, 20.0, 22.0);
      for (final species in ['bee', 'bunny', 'chick', 'fox', 'parrot']) {
        for (final seed in [0, 1]) {
          final entry = world.deliveryVisit(bounds, species, seed);
          final exit = world.departureVisit(bounds, species, seed);
          final first = entry.poseAt(0)!;
          expect(first.y < bounds.$2 || first.y > bounds.$4, true);
          final last = entry.poseAt(entry.duration - .001)!;
          expect(
            (last.x - world.giftCell.$1).abs() +
                (last.y - world.giftCell.$2).abs(),
            lessThan(.01),
          );
          final departing = exit.poseAt(exit.duration - .001)!;
          expect(departing.y < bounds.$2 || departing.y > bounds.$4, true);
          expect(entry.duration, closeTo(22, .001));
        }
      }
    },
  );
}
