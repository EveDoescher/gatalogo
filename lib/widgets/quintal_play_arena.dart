import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'quintal_production_widgets.dart';

class QuintalPlayArena extends StatelessWidget {
  const QuintalPlayArena({
    super.key,
    required this.cat,
    required this.position,
    required this.target,
    required this.lift,
    required this.caption,
    this.onTarget,
    this.showGround = true,
  });
  final Widget cat;
  final double position, target, lift;
  final String caption;
  final ValueChanged<double>? onTarget;
  final bool showGround;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.greenLink,
            ),
          ),
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) {
            final base = showGround ? 12.0 : box.maxHeight * .22;
            final catHeight = math.min(
              140.0,
              math.max(1.0, box.maxHeight - base - 20),
            );
            final catWidth = catHeight * 120 / 140;
            final wandSize = math.min(64.0, catWidth * .6);
            final travel = math.max(1.0, box.maxWidth - catWidth);
            void point(Offset local) => onTarget?.call(
              ((local.dx - catWidth / 2) / travel).clamp(0, 1),
            );
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: onTarget == null
                  ? null
                  : (details) => point(details.localPosition),
              onPanUpdate: onTarget == null
                  ? null
                  : (details) => point(details.localPosition),
              onTapDown: onTarget == null
                  ? null
                  : (details) => point(details.localPosition),
              child: Stack(
                children: [
                  if (showGround)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 0,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xffe7edce),
                          borderRadius: BorderRadius.circular(60),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: base + lift,
                    left: position * travel,
                    child: SizedBox(
                      width: catWidth,
                      height: catHeight,
                      child: cat,
                    ),
                  ),
                  Positioned(
                    bottom: math.min(
                      base + catHeight * .85,
                      math.max(0, box.maxHeight - wandSize),
                    ),
                    left: target * travel + (catWidth - wandSize) / 2,
                    child: IgnorePointer(
                      child: QuintalArtwork('action_play', size: wandSize),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}
