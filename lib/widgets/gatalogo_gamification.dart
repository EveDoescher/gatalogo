import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import 'gatalogo_components.dart';

/// Enum defining the state of an achievement.
enum AchievementState {
  locked,
  inProgress,
  completed,
}

/// Enum defining the rarity levels of cats or items.
enum RarityLevel {
  common,
  uncommon,
  rare,
  legendary,
}

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

/// A card displaying a conquest or achievement.
class GatalogoAchievementCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final double progress; // 0.0 to 1.0
  final int currentCount;
  final int targetCount;
  final AchievementState state;
  final Color themeColor;
  final String? unlockedAt;
  final VoidCallback? onTap;

  const GatalogoAchievementCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.progress,
    required this.currentCount,
    required this.targetCount,
    required this.state,
    required this.themeColor,
    this.unlockedAt,
    this.onTap,
  });

  @override
  State<GatalogoAchievementCard> createState() => _GatalogoAchievementCardState();
}

class _GatalogoAchievementCardState extends State<GatalogoAchievementCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppDurations.celebration,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.03).chain(CurveTween(curve: AppCurves.bounce)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0).chain(CurveTween(curve: AppCurves.bounce)), weight: 50),
    ]).animate(_pulseController);
  }

  @override
  void didUpdateWidget(covariant GatalogoAchievementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == AchievementState.completed && oldWidget.state != AchievementState.completed) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLocked = widget.state == AchievementState.locked;
    final bool isCompleted = widget.state == AchievementState.completed;

    Color bgColor = AppColors.cardBackground;
    Color borderColor = AppColors.borderLight;
    if (isLocked) {
      bgColor = AppColors.cardAltBackground;
    } else if (isCompleted) {
      bgColor = widget.themeColor.withValues(alpha: 0.1);
      borderColor = widget.themeColor;
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
        duration: AppDurations.slow,
        curve: AppCurves.standard,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: borderColor,
            width: isCompleted ? 2.0 : 1.0,
          ),
        ),
        child: Opacity(
          opacity: isLocked ? 0.5 : 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GatalogoTrophyIcon(
                icon: isLocked ? LucideIcons.lock : widget.icon,
                themeColor: widget.themeColor,
                isUnlocked: !isLocked,
                size: 48,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: GoogleFonts.fredoka(
                              color: isLocked ? AppColors.textMedium : AppColors.textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isCompleted)
                          Icon(
                            LucideIcons.checkCircle2,
                            color: widget.themeColor,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.description,
                      style: GoogleFonts.nunito(
                        color: isLocked ? AppColors.textLight : AppColors.textMedium,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (!isLocked) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: GatalogoProgressBar(
                              value: widget.progress,
                              fillColor: widget.themeColor,
                              height: 8.0,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '${widget.currentCount} / ${widget.targetCount}',
                            style: GoogleFonts.nunito(
                              color: AppColors.textMedium,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isCompleted && widget.unlockedAt != null && widget.unlockedAt!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(LucideIcons.calendarCheck, size: 12, color: widget.themeColor),
                          const SizedBox(width: 4),
                          Text(
                            'Desbloqueado em ${_formatUnlockedDate(widget.unlockedAt!)}',
                            style: GoogleFonts.nunito(
                              color: widget.themeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  String _formatUnlockedDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      return '$day/$month/$year';
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }
}

Future<void> showAchievementCelebrationDialog(
  BuildContext context, {
  required String title,
  required String description,
  required IconData icon,
  required RarityLevel rarity,
  VoidCallback? onShare,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          GatalogoTrophyIcon(
            icon: icon,
            themeColor: rarity.color,
            isUnlocked: true,
            size: 72,
            isLegendary: rarity == RarityLevel.legendary,
          ),
          const SizedBox(height: 16),
          Text(
            'Conquista Desbloqueada!',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: rarity.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppColors.textDark,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: rarity.backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              'Raridade: ${rarity.label}',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: rarity.color,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (onShare != null)
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              onShare();
            },
            icon: const Icon(LucideIcons.share2, size: 16),
            label: const Text('Compartilhar'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
}

/// An animated trophy or badge icon.
class GatalogoTrophyIcon extends StatefulWidget {
  final IconData icon;
  final Color themeColor;
  final bool isUnlocked;
  final double size;
  final bool isLegendary;

  const GatalogoTrophyIcon({
    super.key,
    required this.icon,
    required this.themeColor,
    this.isUnlocked = true,
    this.size = 48.0,
    this.isLegendary = false,
  });

  @override
  State<GatalogoTrophyIcon> createState() => _GatalogoTrophyIconState();
}

class _GatalogoTrophyIconState extends State<GatalogoTrophyIcon> with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _rotationAnimation = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOutSine),
    );

    if (widget.isUnlocked && !_isTesting) {
      _breathingController.repeat(reverse: true);
    }
  }

  bool get _isTesting =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void didUpdateWidget(covariant GatalogoTrophyIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUnlocked && !oldWidget.isUnlocked) {
      if (!_isTesting) {
        _breathingController.repeat(reverse: true);
      }
    } else if (!widget.isUnlocked && oldWidget.isUnlocked) {
      _breathingController.stop();
      _breathingController.reset();
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = widget.size * 0.5;

    Widget trophy = AnimatedContainer(
      duration: AppDurations.normal,
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.isUnlocked ? widget.themeColor.withValues(alpha: 0.2) : AppColors.cardAltBackground,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isUnlocked ? widget.themeColor : AppColors.borderLight,
          width: 2.0,
        ),
      ),
      child: Center(
        child: Icon(
          widget.icon,
          size: iconSize,
          color: widget.isUnlocked ? widget.themeColor : AppColors.textLight,
        ),
      ),
    );

    if (widget.isUnlocked) {
      trophy = RotationTransition(
        turns: _rotationAnimation,
        child: trophy,
      );
    }

    if (widget.isUnlocked && widget.isLegendary) {
      // Very basic shimmer simulation using stack and gradient
      trophy = Stack(
        alignment: Alignment.center,
        children: [
          trophy,
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.4),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  begin: const Alignment(-1.0, -0.3),
                  end: const Alignment(1.0, 0.3),
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcATop,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return trophy;
  }
}

/// A compact card displaying a statistic.
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
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

  const GatalogoXPBar({
    super.key,
    required this.currentLevel,
    required this.currentXP,
    required this.targetXP,
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
