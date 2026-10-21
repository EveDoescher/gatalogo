import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../controllers/habitat_interaction_state.dart';
import '../theme/app_theme.dart';

class HabitatGroundTools extends StatelessWidget {
  const HabitatGroundTools({
    super.key,
    required this.selected,
    required this.canPaint,
    required this.groundOnly,
    required this.onTool,
    required this.onToggleGround,
  });
  final GroundTool selected;
  final bool canPaint, groundOnly;
  final ValueChanged<GroundTool> onTool;
  final VoidCallback onToggleGround;
  @override
  Widget build(BuildContext context) => Positioned(
    left: 12,
    right: 12,
    top: MediaQuery.paddingOf(context).top + 88,
    child: Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tool in GroundTool.values)
              TextButton(
                onPressed: tool == GroundTool.paint && !canPaint
                    ? null
                    : () => onTool(tool),
                style: TextButton.styleFrom(
                  foregroundColor: selected == tool
                      ? AppColors.primaryDark
                      : AppColors.textMedium,
                ),
                child: Text(switch (tool) {
                  GroundTool.move => 'Selecionar / mover',
                  GroundTool.paint => 'Pintar',
                  GroundTool.collect => 'Recolher chão',
                }),
              ),
            IconButton(
              tooltip: groundOnly
                  ? 'Selecionar objetos'
                  : 'Selecionar chão sob objetos',
              onPressed: onToggleGround,
              icon: Icon(
                LucideIcons.layers,
                color: groundOnly
                    ? AppColors.primaryDark
                    : AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
