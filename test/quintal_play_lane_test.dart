import 'package:catlogue/game/quintal_play_lane.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'play only uses contiguous free cells and respects traversal barriers',
    () {
      final free = {(0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (1, 1)};
      final lane = QuintalPlayLane.build(
        current: (1, 0),
        next: (2, 0),
        progress: .3,
        free: free,
        canTraverse: (a, b) => a != (2, 0) || b != (3, 0),
      );
      expect(lane.position(.5), const Offset(1.3, 0));
      expect(lane.cells, [(0, 0), (1, 0), (2, 0)]);
      for (var i = 0; i <= 100; i++) {
        final sample = lane.sample(i / 100);
        expect(free, contains(sample.from));
        expect(free, contains(sample.to));
        expect(
          (sample.from.$1 - sample.to.$1).abs() +
              (sample.from.$2 - sample.to.$2).abs(),
          lessThanOrEqualTo(1),
        );
      }
    },
  );
  test(
    'reversed walks preserve their exact initial position and screen direction',
    () {
      final free = {for (var x = 0; x < 5; x++) (x, 0)};
      final lane = QuintalPlayLane.build(
        current: (3, 0),
        next: (2, 0),
        progress: .4,
        free: free,
        canTraverse: (_, _) => true,
      );
      expect(lane.position(.5).dx, closeTo(2.6, .0001));
      expect(lane.position(0).dx, lessThan(lane.position(1).dx));
    },
  );
  test('an enclosed cat stays in place instead of entering blocked cells', () {
    final lane = QuintalPlayLane.build(
      current: (1, 1),
      next: (1, 1),
      progress: 0,
      free: {(1, 1)},
      canTraverse: (_, _) => true,
    );
    for (final position in [0.0, .5, 1.0]) {
      expect(lane.position(position), const Offset(1, 1));
    }
  });
}
