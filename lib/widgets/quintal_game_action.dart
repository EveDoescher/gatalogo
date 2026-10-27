import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'quintal_production_widgets.dart';

/// Existing crop art and exchange arrows share the same tool-sized footprint.
class QuintalExchangeArtwork extends StatelessWidget {
  const QuintalExchangeArtwork({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 76,
    height: 70,
    child: Stack(
      children: [
        Positioned(left: 1, top: 0, child: QuintalArtwork('wheat', size: 44)),
        Positioned(
          right: 0,
          bottom: 0,
          child: QuintalArtwork('carrot', size: 43),
        ),
        Positioned(
          right: 3,
          top: 2,
          child: Icon(
            LucideIcons.arrowRight,
            size: 25,
            color: AppColors.greenLink,
          ),
        ),
        Positioned(
          left: 3,
          bottom: 1,
          child: Icon(
            LucideIcons.arrowLeft,
            size: 25,
            color: AppColors.greenLink,
          ),
        ),
      ],
    ),
  );
}

/// A tool silhouette in the scene, with a generous touch target and a short tag.
class QuintalGameAction extends StatefulWidget {
  const QuintalGameAction({
    super.key,
    required this.artwork,
    required this.label,
    required this.onPressed,
  });
  final Widget artwork;
  final String label;
  final VoidCallback? onPressed;
  @override
  State<QuintalGameAction> createState() => _QuintalGameActionState();
}

class _QuintalGameActionState extends State<QuintalGameAction> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onPressed != null,
    label: widget.label,
    onTap: widget.onPressed,
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        onHighlightChanged: (value) => setState(() => pressed = value),
        borderRadius: BorderRadius.circular(28),
        child: AnimatedScale(
          scale: pressed ? .92 : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 90),
          child: SizedBox(
            width: 90 * (MediaQuery.textScalerOf(context).scale(15) / 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: widget.onPressed == null ? .55 : 1,
                  child: SizedBox(width: 84, height: 78, child: widget.artwork),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: widget.onPressed == null
                        ? AppColors.cardBackground
                        : AppColors.surface,
                    border: Border.all(color: const Color(0xffBCA381)),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x303E281A),
                        blurRadius: 3,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textTitle,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
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
