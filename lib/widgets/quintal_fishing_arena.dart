import 'quintal_outlined_text.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/habitat_river_palette.dart';
import '../theme/app_theme.dart';
import 'quintal_production_widgets.dart';

/// Fish and catch zone share one coordinate system, including at the banks.
class QuintalFishingArena extends StatelessWidget {
  const QuintalFishingArena({
    super.key,
    required this.fish,
    required this.position,
    required this.zone,
  });
  final double fish, position, zone;
  bool get tracking => (position - fish).abs() <= zone / 2;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: tracking ? AppColors.greenLink : const Color(0xff785236),
          borderRadius: BorderRadius.circular(14),
        ),
        child: QuintalOutlinedText(
          tracking ? 'Na faixa!' : 'Aproxime a faixa do peixe',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xfffff9ec),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: Center(
          child: SizedBox(
            width: 190,
            child: LayoutBuilder(
              builder: (context, box) {
                final inset = math.min(28.0, box.maxHeight / 4);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xff926b46),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(color: Color(0x4063472c), offset: Offset(0, 4)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(27),
                      child: LayoutBuilder(
                        builder: (context, inner) {
                          final innerTravel = math.max(
                            0.0,
                            inner.maxHeight - inset * 2,
                          );
                          final bandCenter = inset + position * innerTravel;
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        HabitatRiverPalette.deep,
                                        HabitatRiverPalette.shallow,
                                        HabitatRiverPalette.middle,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              for (var i = 1; i < 5; i++)
                                Positioned(
                                  top: inner.maxHeight * i / 5,
                                  left: i.isEven ? 12 : 96,
                                  child: Container(
                                    width: 42,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: const Color(0x709fcec0),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: bandCenter - zone * innerTravel / 2,
                                left: 8,
                                right: 8,
                                height: zone * innerTravel,
                                child: Container(
                                  key: const ValueKey('fishing-zone'),
                                  decoration: BoxDecoration(
                                    color:
                                        (tracking
                                                ? const Color(0xffedf3cf)
                                                : const Color(0xfff8ead0))
                                            .withValues(alpha: .65),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: tracking
                                          ? AppColors.greenLink
                                          : const Color(0xff785236),
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: inset + fish * innerTravel - 26,
                                left: (inner.maxWidth - 52) / 2,
                                child: const QuintalArtwork(
                                  'fish',
                                  key: ValueKey('fishing-fish'),
                                  size: 52,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ],
  );
}
