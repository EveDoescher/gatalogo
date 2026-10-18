import 'dart:math' as math;
import 'dart:ui';

/// World-unit motion keeps the pan seated and scales with the scene camera.
double quintalLidLift(double elapsed, {required bool still}) => still
    ? 0
    : math.pow(math.max(0, math.sin(elapsed * 5)), 3).toDouble() * .025;

void paintQuintalSteam(
  Canvas canvas,
  Offset origin,
  double tileWidth,
  double elapsed, {
  required bool still,
}) {
  if (still) return;
  for (var i = 0; i < 3; i++) {
    final phase = (elapsed * .42 + i / 3) % 1;
    final opacity = math.sin(phase * math.pi) * .52;
    final x = origin.dx + (i - 1) * tileWidth * .055;
    final y = origin.dy - phase * tileWidth * .32;
    final drift = math.sin(phase * math.pi * 2 + i) * tileWidth * .025;
    final path = Path()
      ..moveTo(x, y)
      ..cubicTo(
        x + drift,
        y - tileWidth * .045,
        x - drift,
        y - tileWidth * .08,
        x + drift,
        y - tileWidth * .13,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFF9E6).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = tileWidth * .026,
    );
  }
}
