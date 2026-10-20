import 'package:flutter/material.dart';

/// A real stroke follows each glyph, including large accessibility text.
class QuintalOutlinedText extends StatelessWidget {
  const QuintalOutlinedText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style
        .merge(style)
        .copyWith(fontWeight: FontWeight.w800);
    return CustomPaint(
      painter: _GlyphOutline(
        data,
        base,
        textAlign ?? TextAlign.start,
        Directionality.of(context),
        MediaQuery.textScalerOf(context),
        maxLines,
      ),
      child: Text(
        data,
        style: base.copyWith(color: const Color(0xfffff9ec)),
        textAlign: textAlign,
        maxLines: maxLines,
      ),
    );
  }
}

class _GlyphOutline extends CustomPainter {
  const _GlyphOutline(
    this.data,
    this.style,
    this.align,
    this.direction,
    this.scaler,
    this.maxLines,
  );
  final String data;
  final TextStyle style;
  final TextAlign align;
  final TextDirection direction;
  final TextScaler scaler;
  final int? maxLines;
  @override
  void paint(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: data,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xff493223),
        ),
      ),
      textAlign: align,
      textDirection: direction,
      textScaler: scaler,
      maxLines: maxLines,
    )..layout(minWidth: size.width, maxWidth: size.width);
    text.paint(canvas, Offset.zero);
    text.dispose();
  }

  @override
  bool shouldRepaint(_GlyphOutline old) =>
      data != old.data ||
      style != old.style ||
      align != old.align ||
      scaler != old.scaler ||
      direction != old.direction ||
      maxLines != old.maxLines;
}
