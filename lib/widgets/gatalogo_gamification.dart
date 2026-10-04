import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/gamification.dart';
import '../theme/app_theme.dart';
import 'game_components.dart';

/// Enum defining the rarity levels of cats or items.
enum RarityLevel { common, uncommon, rare, legendary }

/// Extension to provide styling and data for [RarityLevel].
extension RarityLevelExtension on RarityLevel {
  Color get color {
    switch (this) {
      case RarityLevel.common:
        return AppColors.rarityCommon;
      case RarityLevel.uncommon:
        return AppColors.rarityUncommon;
      case RarityLevel.rare:
        return AppColors.rarityRare;
      case RarityLevel.legendary:
        return AppColors.rarityLegendary;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case RarityLevel.common:
        return AppColors.rarityCommonBg;
      case RarityLevel.uncommon:
        return AppColors.rarityUncommonBg;
      case RarityLevel.rare:
        return AppColors.rarityRareBg;
      case RarityLevel.legendary:
        return AppColors.rarityLegendaryBg;
    }
  }

  String get label {
    switch (this) {
      case RarityLevel.common:
        return 'Comum';
      case RarityLevel.uncommon:
        return 'Incomum';
      case RarityLevel.rare:
        return 'Raro';
      case RarityLevel.legendary:
        return 'Lendário';
    }
  }

  int get starCount {
    switch (this) {
      case RarityLevel.common:
        return 1;
      case RarityLevel.uncommon:
        return 2;
      case RarityLevel.rare:
        return 3;
      case RarityLevel.legendary:
        return 4;
    }
  }
}

class GatalogoStatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color valueColor;
  final IconData? icon;

  const GatalogoStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.textLight, size: 20),
            const SizedBox(height: AppSpacing.xs),
          ],
          AnimatedSwitcher(
            duration: AppDurations.normal,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Text(
              '$value',
              key: ValueKey<int>(value),
              style: GoogleFonts.fredoka(
                color: valueColor,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              color: AppColors.textMedium,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A visual indicator for rarity levels using stars or dots.
class GatalogoRarityIndicator extends StatelessWidget {
  final RarityLevel rarity;
  final double iconSize;

  const GatalogoRarityIndicator({
    super.key,
    required this.rarity,
    this.iconSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    const int maxStars = 4;
    final int currentStars = rarity.starCount;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStars, (index) {
        final bool isFilled = index < currentStars;
        return Padding(
          padding: const EdgeInsets.only(right: 2.0),
          child: Icon(
            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: iconSize,
            color: isFilled ? rarity.color : AppColors.borderLight,
          ),
        );
      }),
    );
  }
}

/// A styled experience bar with level label and XP count.
class GatalogoXPBar extends StatelessWidget {
  final int currentLevel;
  final int currentXP;
  final int targetXP;
  final bool showLevel;

  const GatalogoXPBar({
    super.key,
    required this.currentLevel,
    required this.currentXP,
    required this.targetXP,
    this.showLevel = true,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = (currentXP / targetXP).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 2,
          children: [
            if (showLevel)
              Text(
                'Nível $currentLevel',
                style: GoogleFonts.fredoka(
                  color: AppColors.achievementText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              '$currentXP / $targetXP XP',
              style: GoogleFonts.nunito(
                color: AppColors.textMedium,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 12.0,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.achievementBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fillWidth = constraints.maxWidth * progress;
                  return AnimatedContainer(
                    duration: AppDurations.normal,
                    curve: AppCurves.standard,
                    width: fillWidth,
                    decoration: BoxDecoration(
                      color: AppColors.achievement,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: progress > 0.05
                          ? Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: Icon(
                                LucideIcons.sparkles,
                                size: 10,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Confirmed progression as the explorer's album badge.
class GatalogoGamificationCard extends StatelessWidget {
  const GatalogoGamificationCard({
    super.key,
    required this.gamification,
    required this.onTapJourney,
  });
  final GamificationState gamification;
  final VoidCallback onTapJourney;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTapJourney,
      borderRadius: BorderRadius.circular(16),
      child: GameNotebook(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GameSeal(label: '${gamification.level}', size: 49),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gamification.levelTitle, style: GameStyle.title(23)),
                      Text(
                        'Nível ${gamification.level} · ${gamification.xp} XP',
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 14),
            GameProgress(
              current: gamification.currentLevelXp,
              target: gamification.currentLevelTargetXp,
            ),
            const SizedBox(height: 12),
            Text(
              '${gamification.unlockedAchievements} conquistas guardadas',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Abrir meu mural',
              style: TextStyle(color: AppColors.greenLink),
            ),
          ],
        ),
      ),
    ),
  );
}
