import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';

/// A versatile card container without elevation/shadows.
/// Follows the Gatálogo tonal elevation and rounded design rules.
class GatalogoCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const GatalogoCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = AnimatedContainer(
      duration: AppDurations.normal,
      curve: AppCurves.standard,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.borderLight,
          width: 1.2,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          splashColor: AppColors.primaryLight.withValues(alpha: 0.3),
          highlightColor: AppColors.primarySoftBg.withValues(alpha: 0.5),
          child: card,
        ),
      );
    }

    return card;
  }
}

/// Primary action button.
/// Pill-shaped, 48px height, scale animation on press.
class GatalogoButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const GatalogoButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon = Icons.pets,
    this.isLoading = false,
    this.fullWidth = true,
  });

  @override
  State<GatalogoButton> createState() => _GatalogoButtonState();
}

class _GatalogoButtonState extends State<GatalogoButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.standard),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _controller.forward(),
      onTapUp: isDisabled ? null : (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: isDisabled ? null : () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedOpacity(
          duration: AppDurations.fast,
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            width: widget.fullWidth ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: Colors.white, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Flexible(
                          child: Text(
                            widget.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action button (outlined).
class GatalogoSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? leadingIcon;
  final IconData? icon;
  final bool fullWidth;

  const GatalogoSecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.leadingIcon,
    this.icon,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;
    Widget? effectiveIcon = leadingIcon;
    if (effectiveIcon == null && icon != null) {
      effectiveIcon = Icon(icon, size: 18, color: isEnabled ? AppColors.textTitle : AppColors.textLight);
    }

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (effectiveIcon != null) ...[
                  effectiveIcon,
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      color: isEnabled ? AppColors.textTitle : AppColors.textLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile avatar circle.
class GatalogoAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final String? assetPath;

  const GatalogoAvatar({
    super.key,
    this.size = 44,
    this.imageUrl,
    this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.borderProfile,
          width: 1.4,
        ),
      ),
      child: ClipOval(
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    } else if (assetPath != null && assetPath!.isNotEmpty) {
      return Image.asset(
        assetPath!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Icon(
      LucideIcons.user,
      size: size * 0.5,
      color: AppColors.textLight,
    );
  }
}

/// Themed progress bar with optional label.
class GatalogoProgressBar extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double height;
  final Color? fillColor;
  final String? label;

  const GatalogoProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.fillColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: height,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(height / 2),
              ),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: AppDurations.slow,
                    curve: AppCurves.standard,
                    width: constraints.maxWidth * clampedValue,
                    height: height,
                    decoration: BoxDecoration(
                      color: fillColor ?? AppColors.greenProgress,
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (label != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            label!,
            style: GoogleFonts.nunito(
              color: AppColors.textMedium,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Small badge/tag widget.
class GatalogoBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;

  const GatalogoBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory GatalogoBadge.common() {
    return GatalogoBadge(
      label: 'Common',
      icon: LucideIcons.leaf,
      backgroundColor: AppColors.rarityCommonBg,
      textColor: AppColors.rarityCommon,
    );
  }

  factory GatalogoBadge.uncommon() {
    return GatalogoBadge(
      label: 'Uncommon',
      icon: LucideIcons.flower,
      backgroundColor: AppColors.rarityUncommonBg,
      textColor: AppColors.rarityUncommon,
    );
  }

  factory GatalogoBadge.rare() {
    return GatalogoBadge(
      label: 'Rare',
      icon: LucideIcons.star,
      backgroundColor: AppColors.rarityRareBg,
      textColor: AppColors.rarityRare,
    );
  }

  factory GatalogoBadge.legendary() {
    return GatalogoBadge(
      label: 'Legendary',
      icon: LucideIcons.trophy,
      backgroundColor: AppColors.rarityLegendaryBg,
      textColor: AppColors.rarityLegendary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 12),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: GoogleFonts.nunito(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chip for library page and others.
class GatalogoChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const GatalogoChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: AppCurves.standard,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.borderLight,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              color: isActive ? Colors.white : AppColors.textMedium,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Positioned botanical leaf decoration.
class LeafDecoration extends StatelessWidget {
  final int leafNumber;
  final Alignment position;
  final double angle;
  final double scale;
  final double opacity;
  final EdgeInsets padding;

  const LeafDecoration({
    super.key,
    required this.leafNumber,
    required this.position,
    this.angle = 0.0,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.padding = EdgeInsets.zero,
  });

  factory LeafDecoration.topLeft({int leafNumber = 1}) {
    return LeafDecoration(
      leafNumber: leafNumber,
      position: Alignment.topLeft,
      angle: -0.5,
      padding: const EdgeInsets.only(top: 10, left: -20),
    );
  }

  factory LeafDecoration.topRight({int leafNumber = 2}) {
    return LeafDecoration(
      leafNumber: leafNumber,
      position: Alignment.topRight,
      angle: 0.5,
      padding: const EdgeInsets.only(top: 10, right: -20),
    );
  }

  factory LeafDecoration.bottomLeft({int leafNumber = 3}) {
    return LeafDecoration(
      leafNumber: leafNumber,
      position: Alignment.bottomLeft,
      angle: -2.5,
      padding: const EdgeInsets.only(bottom: -10, left: -20),
    );
  }

  factory LeafDecoration.bottomRight({int leafNumber = 4}) {
    return LeafDecoration(
      leafNumber: leafNumber,
      position: Alignment.bottomRight,
      angle: 2.5,
      padding: const EdgeInsets.only(bottom: -10, right: -20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: position,
        child: Padding(
          padding: padding,
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Image.asset(
                  'assets/images/Folha_$leafNumber.png',
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
