import 'package:catlogue/game/quintal_timed_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 9, 12);
  QuintalTimedProgress resident({String? pause, int supplySeconds = 60}) =>
      QuintalTimedProgress.fromRow({
        'production_progress': {
          'observed_at': now.toIso8601String(),
          'cycle_seconds': 600,
          'elapsed_seconds': 300,
          'pause_reason': pause,
          'active_until': now
              .add(Duration(seconds: supplySeconds))
              .toIso8601String(),
          'expires_reason': 'needs_water',
        },
      })!;
  test('paused progress remains frozen across time spent away', () {
    final p = resident(pause: 'needs_food');
    expect(p.fraction(now), .5);
    expect(p.fraction(now.add(const Duration(days: 2))), .5);
    expect(p.label(now.add(const Duration(days: 2))), 'Sem comida');
  });
  test('supplies expiring stop the bar before a network refresh', () {
    final p = resident();
    expect(p.label(now), '00:05:00');
    expect(p.fraction(now.add(const Duration(seconds: 30))), .55);
    expect(p.fraction(now.add(const Duration(hours: 1))), .6);
    expect(p.label(now.add(const Duration(minutes: 1))), 'Sem água');
    expect(resident(supplySeconds: 600).label(now), '00:05:00');
  });
  test('uses the complete server interval and rounds remaining seconds up', () {
    final progress = QuintalTimedProgress(
      start: now.subtract(const Duration(hours: 1)),
      end: now.add(const Duration(hours: 1, milliseconds: 1)),
    );
    expect(progress.fraction(now), closeTo(.5, .00001));
    expect(progress.label(now), '01:00:01');
    expect(progress.fraction(now.add(const Duration(hours: 3))), 1);
    expect(progress.label(now.add(const Duration(hours: 3))), '00:00:00');
  });
  test('queued recipes count down to their start without fake production', () {
    final progress = QuintalTimedProgress(
      start: now.add(const Duration(minutes: 5)),
      end: now.add(const Duration(minutes: 10)),
    );
    expect(progress.fraction(now), 0);
    expect(progress.label(now), 'Fila · 00:05:00');
    expect(progress.label(now.add(const Duration(minutes: 5))), '00:05:00');
  });
  test('missing or invalid starts do not fabricate percentages', () {
    final progress = QuintalTimedProgress.fromRow({
      'next_ready_at': now.add(const Duration(hours: 27)).toIso8601String(),
    })!;
    expect(progress.fraction(now), isNull);
    expect(progress.label(now), '27:00:00');
    expect(QuintalTimedProgress(end: now, start: now).fraction(now), isNull);
    expect(QuintalTimedProgress.fromRow({}), isNull);
  });
}
