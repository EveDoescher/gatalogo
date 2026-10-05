import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'illustrated_home_components.dart';

/// Display only a reward already confirmed by the API.
class HabitatRewardReveal extends StatelessWidget {
  const HabitatRewardReveal({
    super.key,
    required this.label,
    required this.onClose,
  });
  final String label;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Material(
      color: AppColors.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Image.asset(
              'assets/3d_assets/kenney_mini-dungeon/Previews/chest.png',
              width: 64,
              height: 64,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Presente aberto!', style: HomeArt.title(18)),
                  const SizedBox(height: 4),
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  const Text('Já está na sua conta.'),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              tooltip: 'Fechar recompensa',
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    ),
  );
}
