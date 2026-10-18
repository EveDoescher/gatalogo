import 'dart:math' as math;
import 'dart:ui';

import 'quintal_scene_target.dart';

/// Transient feedback for a confirmed operation. Never changes game resources.
class QuintalActionEffect {
  QuintalActionEffect(this.target, this.action, this.startedAt);
  final QuintalSceneTarget target;
  final String action;
  final double startedAt;
  static const duration = 1.35;
  bool get isMilking =>
      action == 'collect_residents' &&
      target.kind == 'pasture' &&
      target.role == 'resident';
  bool get isHarvest =>
      action == 'harvest' &&
      target.role == 'plot' &&
      const {
        'corn',
        'wheat',
        'carrot',
        'turnip',
        'pumpkin',
        'melon',
      }.contains(target.crop);
  bool get isFruitPickup =>
      action == 'collect_residents' &&
      target.kind == 'orchard' &&
      target.role == 'collect';
  bool get isMarketPickup => action == 'collect' && target.kind == 'market';
  bool get isMarketRecovery =>
      action == 'finish_build' && target.kind == 'market';

  double transitionProgress(double now, {required bool reducedMotion}) {
    if (reducedMotion) return 1;
    final t = ((now - startedAt) / duration).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  String? get toolKind => action.startsWith('water_')
      ? 'watering-can'
      : action == 'serve' || action == 'feed_residents'
      ? target.kind == 'pasture'
            ? 'hay-fork'
            : 'feed-scoop'
      : null;
  int toolStage(double now, {required bool reducedMotion}) {
    if (reducedMotion) return 0;
    final elapsed = now - startedAt;
    final tilt = elapsed < .3
        ? elapsed / .3
        : elapsed < .95
        ? 1.0
        : 1 - (elapsed - .95) / .4;
    return (tilt.clamp(0.0, 1.0) * 4).round();
  }

  double toolOpacity(double now) => math
      .min((now - startedAt) / .12, (duration - now + startedAt) / .18)
      .clamp(0.0, 1.0);
  Offset toolOutlet(Offset anchor, double unit) =>
      anchor + Offset(unit * .18, -unit * .42);

  double get lifetime => isMilking ? 2.1 : duration;
  double harvestLift(double now, {required bool reducedMotion}) {
    if (reducedMotion) return 0;
    final t = ((now - startedAt) / .85).clamp(0.0, 1.0);
    return .75 * (1 - math.pow(1 - t, 3));
  }

  double harvestOpacity(double now) =>
      1 - ((now - startedAt - .9) / (duration - .9)).clamp(0.0, 1.0);
  int milkStage(double now) => now - startedAt < .4
      ? 0
      : now - startedAt < 1.25
      ? 1
      : 2;

  static bool supports(String action) => const {
    'water_cat',
    'water_residents',
    'water_crop',
    'serve',
    'feed_residents',
    'plant',
    'harvest',
    'collect',
    'collect_residents',
    'finish_build',
  }.contains(action);

  bool expired(double now) => now - startedAt >= lifetime;

  void paint(
    Canvas canvas,
    Offset anchor,
    double unit,
    double now, {
    required bool reducedMotion,
  }) {
    if (isMilking ||
        isHarvest ||
        isMarketPickup ||
        isMarketRecovery ||
        isFruitPickup) {
      return; // The scene renders the actual meshes.
    }
    final t = ((now - startedAt) / duration).clamp(0.0, 1.0);
    final water = action.startsWith('water_');
    final feeding = action == 'serve' || action == 'feed_residents';
    final leaves = action == 'harvest' || action == 'plant';
    final color = water
        ? const Color(0xff92cbd2)
        : feeding
        ? const Color(0xffbf8a50)
        : leaves
        ? const Color(0xff80a554)
        : const Color(0xffe4c67d);
    final opacity = toolKind != null ? toolOpacity(now) * .9 : (1 - t) * .9;
    final paint = Paint()..color = color.withValues(alpha: opacity);
    if (reducedMotion) {
      canvas.drawOval(
        Rect.fromCenter(center: anchor, width: unit * .5, height: unit * .22),
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      return;
    }
    if (water) {
      final outlet = toolOutlet(anchor, unit);
      for (var i = 0; i < 7; i++) {
        final fall = (now - startedAt - .28 - i * .075) / .36;
        if (fall <= 0 || fall >= 1) continue;
        final p =
            Offset.lerp(outlet, anchor, fall)! +
            Offset((i % 2) * unit * .015, 0);
        canvas.drawOval(
          Rect.fromCenter(center: p, width: unit * .027, height: unit * .055),
          paint,
        );
      }
      for (var i = 0; i < 2; i++) {
        final ripple = (t - .27 - i * .18).clamp(0.0, .5) * 2;
        if (ripple == 0) continue;
        canvas.drawOval(
          Rect.fromCenter(
            center: anchor,
            width: unit * .5 * ripple,
            height: unit * .2 * ripple,
          ),
          Paint()
            ..color = color.withValues(alpha: opacity * (1 - ripple))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    } else if (feeding) {
      final outlet = toolOutlet(anchor, unit);
      final hay = target.kind == 'pasture';
      for (var i = 0; i < 8; i++) {
        final fall = (now - startedAt - .28 - i * .06) / .33;
        if (fall <= 0 || fall >= 1) continue;
        final p =
            Offset.lerp(outlet, anchor, fall)! +
            Offset((i % 3 - 1) * unit * .025 * fall, 0);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(i * .7 + fall);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: unit * (hay ? .12 : .045),
              height: unit * (hay ? .015 : .032),
            ),
            const Radius.circular(1),
          ),
          Paint()
            ..color = (hay ? const Color(0xffd1b975) : color).withValues(
              alpha: opacity,
            ),
        );
        canvas.restore();
      }
    } else {
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi * 2 / 8;
        final radius = unit * (.06 + t * .22);
        final x = math.cos(angle) * radius;
        final y = feeding ? -unit * .35 * (1 - t) : -unit * .22 * t;
        final p = anchor + Offset(x, y + math.sin(angle) * radius * .4);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(angle + t);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: unit * (leaves ? .08 : .045),
            height: unit * .03,
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }
}
