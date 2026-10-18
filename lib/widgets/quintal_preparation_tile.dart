import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'quintal_clock_badge.dart';
import 'quintal_production_widgets.dart';

class QuintalPreparationTile extends StatelessWidget {
  const QuintalPreparationTile({
    super.key,
    required this.art,
    required this.name,
    required this.status,
    required this.ready,
    this.progress,
    this.onCollect,
    this.onCancel,
  });
  final String art, name, status;
  final bool ready;
  final double? progress;
  final VoidCallback? onCollect, onCancel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            children: [
              QuintalArtwork(art, size: 56),
              Positioned(
                right: 0,
                bottom: 0,
                child: ready
                    ? const QuintalArtwork('ready', size: 32)
                    : const QuintalClockBadge(size: 26),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                status,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTitle,
                ),
              ),
              if (progress != null && !ready) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                  color: AppColors.greenLink,
                  backgroundColor: const Color(0xFFE4D9BB),
                ),
              ],
              if (ready)
                TextButton.icon(
                  onPressed: onCollect,
                  icon: const Icon(LucideIcons.shoppingBasket, size: 17),
                  label: const Text('Recolher'),
                ),
            ],
          ),
        ),
        if (onCancel != null)
          IconButton(
            tooltip: 'Cancelar preparo',
            onPressed: onCancel,
            icon: const Icon(LucideIcons.x, size: 20),
          ),
      ],
    ),
  );
}
