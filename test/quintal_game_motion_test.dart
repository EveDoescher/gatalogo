import 'package:catlogue/game/quintal_game_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'same hold/release sequence has the same result at 5, 30 and 60 FPS',
    () {
      double simulate(int fps) {
        var position = .5;
        for (var i = 0; i < fps; i++) {
          position = QuintalGameMotion.fishing(position, true, 1 / fps);
        }
        for (var i = 0; i < fps; i++) {
          position = QuintalGameMotion.fishing(position, false, 1 / fps);
        }
        return position;
      }

      expect(simulate(5), closeTo(simulate(60), 1e-10));
      expect(simulate(30), closeTo(simulate(60), 1e-10));
      expect(QuintalGameMotion.fishing(.5, true, 10), 0);
      expect(QuintalGameMotion.fishing(.5, false, 10), 1);
    },
  );
  test('cat approach has the same duration across frame rates', () {
    double simulate(int fps) {
      var position = .2;
      for (var i = 0; i < fps * 2; i++) {
        position = QuintalGameMotion.follow(position, .8, 1 / fps);
      }
      return position;
    }

    expect(simulate(5), closeTo(simulate(60), 1e-10));
    expect(simulate(30), closeTo(simulate(60), 1e-10));
    expect(QuintalGameMotion.follow(.2, .8, 0), .2);
    expect(simulate(5), inExclusiveRange(.2, .8));
  });
}
