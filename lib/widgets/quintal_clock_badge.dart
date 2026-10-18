import 'package:flutter/material.dart';

/// The same warm clock is used in the world and in the preparation tray.
class QuintalClockBadge extends StatelessWidget {
  const QuintalClockBadge({super.key, this.size = 38});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Em andamento',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: const QuintalClockPainter()),
    ),
  );
}

class QuintalClockPainter extends CustomPainter {
  const QuintalClockPainter();
  static void draw(Canvas canvas, Rect bounds) {
    canvas.save();
    canvas.translate(bounds.left, bounds.top);
    canvas.scale(bounds.width / 40, bounds.height / 40);
    final silhouette = Path.combine(
      PathOperation.union,
      Path()..addOval(const Rect.fromLTWH(3, 1, 34, 34)),
      Path()
        ..moveTo(15, 32)
        ..lineTo(20, 39)
        ..lineTo(25, 32)
        ..close(),
    );
    canvas.drawShadow(silhouette, const Color(0x503B291B), 2, false);
    canvas.drawPath(silhouette, Paint()..color = const Color(0xFFFFF6DB));
    canvas.drawPath(
      silhouette,
      Paint()
        ..color = const Color(0xFF795238)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      const Offset(20, 18),
      12,
      Paint()..color = const Color(0xFFE7CB89),
    );
    final hands = Paint()
      ..color = const Color(0xFF64452E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(20, 9)
        ..lineTo(20, 18)
        ..lineTo(26, 21),
      hands,
    );
    canvas.drawCircle(
      const Offset(20, 18),
      1.8,
      Paint()..color = const Color(0xFF64452E),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) => draw(canvas, Offset.zero & size);
  @override
  bool shouldRepaint(QuintalClockPainter oldDelegate) => false;
}
