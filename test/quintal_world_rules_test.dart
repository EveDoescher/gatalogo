import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/game/habitat_world.dart';
import 'package:catlogue/game/quintal_resident_motion.dart';
import 'package:catlogue/services/habitat_service.dart';

void main() {
  test('milking pauses only one resident and resumes without a route jump', () {
    final first = QuintalResidentTimeline(), second = QuintalResidentTimeline();
    first.pause(7.7, 2.1);
    final before = quintalResidentPose('pasture', 0, first.time(7.7));
    for (final now in [8.0, 8.9, 9.79]) {
      final during = quintalResidentPose('pasture', 0, first.time(now));
      expect(during.x, before.x);
      expect(during.y, before.y);
      expect(second.time(now), now);
    }
    final after = quintalResidentPose('pasture', 0, first.time(9.81));
    expect(
      (after.x - before.x).abs() + (after.y - before.y).abs(),
      lessThan(.002),
    );
    first.pause(12, 2.1);
    expect(first.time(13), closeTo(9.9, .0001));
    expect(first.time(15), closeTo(10.8, .0001));
  });
  test(
    'service paths stay connected and reach both animal gates after expansion',
    () {
      for (var level = 0; level <= 3; level++) {
        final world = HabitatWorld(
          HabitatService.yardCells(level),
          productionEnabled: true,
        );
        final cells = world.productionPaths;
        final visited = <(int, int)>{cells.first};
        final queue = [cells.first];
        while (queue.isNotEmpty) {
          final (x, y) = queue.removeLast();
          for (final neighbor in [
            (x - 1, y),
            (x + 1, y),
            (x, y - 1),
            (x, y + 1),
          ]) {
            if (cells.contains(neighbor) && visited.add(neighbor)) {
              queue.add(neighbor);
            }
          }
        }
        expect(visited, cells, reason: 'No disconnected path fragments');
        for (final (x, y) in cells) {
          expect(world.editable.contains((x, y)), false);
          expect(world.isRiverCell(x, y), false);
        }
        for (final kind in ['coop', 'pasture']) {
          final area = world.productionAreas[kind]!;
          expect(cells.contains((area.$1, area.$2 + 3)), true);
          expect(cells.contains((area.$1 - 1, area.$2 + 3)), true);
        }
      }
    },
  );
  test(
    'residents stay separated and never teleport across their rest cycle',
    () {
      for (final kind in ['coop', 'pasture']) {
        final count = kind == 'coop' ? 4 : 2;
        for (
          var tick = 0;
          tick <= count * quintalResidentSlotSeconds * 10;
          tick++
        ) {
          final poses = [
            for (var slot = 0; slot < count; slot++)
              quintalResidentPose(
                kind,
                slot,
                tick / 10,
                fed: true,
                watered: true,
              ),
          ];
          for (var i = 0; i < count; i++) {
            final p = poses[i],
                next = quintalResidentPose(kind, i, tick / 10 + .1, fed: true);
            expect(
              math.sqrt(math.pow(p.x - next.x, 2) + math.pow(p.y - next.y, 2)),
              lessThan(.02),
              reason: 'No jump at walk/rest boundary',
            );
            expect(
              quintalResidentGroundClear(kind, p.x, p.y),
              isTrue,
              reason: '$kind/$i at ${tick / 10}: ${p.x},${p.y}',
            );
            for (var j = i + 1; j < count; j++) {
              expect(
                math.sqrt(
                  math.pow(p.x - poses[j].x, 2) + math.pow(p.y - poses[j].y, 2),
                ),
                greaterThan(kind == 'coop' ? .8 : 1.3),
              );
            }
          }
        }
      }
    },
  );
  test('residents enter, rest and leave both shelter levels without crossing walls or jumping', () {
    for (final kind in ['coop', 'pasture']) {
      for (final level in [1, 2]) {
        final count = kind == 'coop' ? level * 2 : level;
        for (var slot = 0; slot < count; slot++) {
          var entered = false, left = false;
          var rest = 0.0;
          for (var tick = 0; tick < quintalResidentSlotSeconds * 10; tick++) {
            final now = slot * quintalResidentSlotSeconds + tick / 10;
            final p = quintalResidentPose(kind, slot, now, level: level);
            final next = quintalResidentPose(
              kind,
              slot,
              now + .1,
              level: level,
            );
            expect(
              quintalResidentGroundClear(kind, p.x, p.y, level: level),
              isTrue,
            );
            expect(
              math.sqrt(math.pow(p.x - next.x, 2) + math.pow(p.y - next.y, 2)),
              lessThan(.02),
            );
            expect(
              (p.elevation - next.elevation).abs(),
              lessThan(.02),
              reason: 'Continuous ramp elevation',
            );
            if (p.sheltered) {
              entered = true;
              expect(
                p.x,
                .8,
                reason: 'Only the door column enters the building',
              );
              expect(p.elevation, closeTo(kind == 'coop' ? .36 : .15, .0001));
              if (p.clip == 'idle') rest += .1;
            }
            if (entered && p.y >= 2.8 && !p.sheltered) left = true;
          }
          expect(
            entered && left,
            isTrue,
            reason: '$kind level $level resident $slot returns outside',
          );
          expect(rest, greaterThanOrEqualTo(13.8));
        }
      }
    }
  });

  test('hens scratch briefly at home and the shelter approach never opens the gate', () {
    for (var slot = 0; slot < 4; slot++) {
      var scratched = false;
      for (var tick = 0; tick < quintalResidentSlotSeconds * 10; tick++) {
        final p = quintalResidentPose(
          'coop',
          slot,
          slot * quintalResidentSlotSeconds + tick / 10,
        );
        if (p.clip == 'scratch') {
          scratched = true;
          final home = quintalResidentHomes('coop')[slot];
          expect((p.x - home.$1).abs(), lessThanOrEqualTo(.02001));
          expect(p.y, home.$2);
          expect(p.sheltered, isFalse);
        }
        if (p.elevation > 0) {
          expect(p.gatePassage, isFalse);
          expect(quintalGateOpening([p]), 0);
        }
      }
      expect(scratched, isTrue);
    }
  });

  test('every resident exits and returns through a fully open gate', () {
    for (final kind in ['coop', 'pasture']) {
      final count = kind == 'coop' ? 4 : 2;
      for (var slot = 0; slot < count; slot++) {
        var exited = false, returned = false;
        for (var tick = 0; tick <= quintalResidentSlotSeconds * 10; tick++) {
          final time = slot * quintalResidentSlotSeconds + tick / 10;
          final poses = [
            for (var i = 0; i < count; i++) quintalResidentPose(kind, i, time),
          ];
          final p = poses[slot];
          if (p.x < -.5) {
            exited = true;
            expect(
              p.y,
              closeTo(3, .0001),
              reason: 'No crossing through a fence',
            );
          }
          if (exited && p.x > .6) returned = true;
          if ((p.x + .5).abs() < .8 && (p.y - 3).abs() < .01) {
            expect(
              quintalGateOpening(poses),
              1,
              reason: 'Gate clears the whole body',
            );
          }
        }
        expect(
          exited && returned,
          isTrue,
          reason: '$kind/$slot completes the gate visit',
        );
      }
      final still = [
        for (var i = 0; i < count; i++)
          quintalResidentPose(kind, i, 75, still: true),
      ];
      expect(
        quintalGateOpening(still),
        0,
        reason: 'Reduced motion keeps a closed, clear gate',
      );
    }
  });

  test(
    'residents reach actual food and water and face the walking direction',
    () {
      for (final kind in ['coop', 'pasture']) {
        for (var slot = 0; slot < (kind == 'coop' ? 4 : 2); slot++) {
          var ate = false, drank = false;
          for (
            var tick = 0;
            tick < 4 * quintalResidentSlotSeconds * 10;
            tick++
          ) {
            final now = tick / 10;
            final p = quintalResidentPose(
              kind,
              slot,
              now,
              fed: true,
              watered: true,
            );
            if (p.clip == 'eat') {
              expect(p.x, kind == 'coop' ? 3.8 : 4.4);
              expect(p.y, anyOf(1.0, 4.6));
              ate |= p.y == 1;
              drank |= p.y == 4.6;
              expect(quintalResidentPose(kind, slot, now).clip, 'idle');
            }
            final next = quintalResidentPose(kind, slot, now + .001);
            if (p.clip == 'walk' &&
                next.clip == 'walk' &&
                p.direction == next.direction) {
              final dx = next.x - p.x, dy = next.y - p.y;
              if (dx.abs() + dy.abs() > .00001) {
                expect(
                  p.direction,
                  dx.abs() > dy.abs() ? (dx > 0 ? 3 : 1) : (dy > 0 ? 0 : 2),
                );
              }
            }
          }
          expect(
            ate && drank,
            isTrue,
            reason: '$kind/$slot visits both supplies',
          );
        }
      }
    },
  );
  test('production spaces never consume cat cells or river, and retain courier access', () {
    for (var level = 0; level <= 3; level++) {
      final world = HabitatWorld(
        HabitatService.yardCells(level),
        productionEnabled: true,
      );
      for (final e in world.productionAreas.entries.where(
        (e) => e.key != 'pier',
      )) {
        final r = e.value;
        for (var x = r.$1; x < r.$1 + r.$3; x++) {
          for (var y = r.$2; y < r.$2 + r.$4; y++) {
            expect(world.editable.contains((x, y)), false);
            expect(world.isRiverCell(x, y), false);
          }
        }
      }
      for (final prop in world.decorationsWithin(-30, -30, 40, 40)) {
        expect(world.isProductionCell(prop.$1, prop.$2), false);
      }
      for (final species in ['bunny', 'chick', 'fox', 'bee']) {
        const bounds = (-20.0, -20.0, 40.0, 40.0);
        final route = world.deliveryVisit(bounds, species, 1);
        final end = route.poseAt(route.duration - .001)!;
        expect(
          (end.x - world.giftCell.$1).abs() + (end.y - world.giftCell.$2).abs(),
          lessThan(.01),
        );
      }
    }
  });
}
