import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/habitat_sprites.dart';
import '../game/habitat_palette.dart';
import '../theme/app_theme.dart';

class HabitatSpritePreview extends StatelessWidget {
  const HabitatSpritePreview({
    super.key,
    required this.sprites,
    required this.keyName,
    required this.size,
  });

  final HabitatSprites sprites;
  final String keyName;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<(ui.Image, ui.Rect)>(
        future: sprites.preview(keyName),
        builder: (context, snapshot) => snapshot.hasData
            ? CustomPaint(
                painter: _HabitatSpritePainter(
                  snapshot.data!.$1,
                  snapshot.data!.$2,
                  HabitatPalette.forSprite(keyName),
                ),
              )
            : const Center(
                child: Icon(LucideIcons.leaf, color: AppColors.green),
              ),
      ),
    );
  }
}

class _HabitatSpritePainter extends CustomPainter {
  const _HabitatSpritePainter(this.image, this.source, this.palette);
  final ColorFilter? palette;
  final ui.Image image;
  final Rect source;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / source.width).clamp(
      0.0,
      size.height / source.height,
    );
    final width = source.width * scale;
    final height = source.height * scale;
    canvas.drawImageRect(
      image,
      source,
      Rect.fromLTWH(
        (size.width - width) / 2,
        (size.height - height) / 2,
        width,
        height,
      ),
      Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = palette,
    );
  }

  @override
  bool shouldRepaint(covariant _HabitatSpritePainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.source != source ||
      oldDelegate.palette != palette;
}
