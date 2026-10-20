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
    this.onTargetPoint,
    this.positionY = .5,
    this.targetY = .5,
    this.showGround = false,
  });
  final Widget cat;
  final double position, target, lift;
  final String caption;
  final ValueChanged<double>? onTarget;
  final bool showGround;
  final double positionY, targetY;
  final ValueChanged<Offset>? onTargetPoint;

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
            final verticalTravel = math.max(
              1.0,
              box.maxHeight - catHeight - 20,
            );
            void point(Offset local) {
              final value = Offset(
                ((local.dx - catWidth / 2) / travel).clamp(0, 1),
                ((local.dy - catHeight / 2) / verticalTravel).clamp(0, 1),
              );
              onTargetPoint?.call(value);
              onTarget?.call(value.dx);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: onTarget == null && onTargetPoint == null
                  ? null
                  : (details) => point(details.localPosition),
              onPanUpdate: onTarget == null && onTargetPoint == null
                  ? null
                  : (details) => point(details.localPosition),
              onTapDown: onTarget == null && onTargetPoint == null
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
                    top: positionY * verticalTravel - lift,
                    left: position * travel,
                    child: SizedBox(
                      width: catWidth,
                      height: catHeight,
                      child: cat,
                    ),
                  ),
                  Positioned(
                    top: targetY * verticalTravel + (catHeight - wandSize) / 2,
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
