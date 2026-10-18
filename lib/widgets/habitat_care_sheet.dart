import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/habitat_sprites.dart';
import '../services/habitat_service.dart';
import '../services/quintal_cat_meal.dart';
import '../theme/app_theme.dart';
import 'habitat_cat_preview.dart';
import 'quintal_production_widgets.dart';
import 'quintal_bond_progress.dart';

class HabitatCareSheet extends StatelessWidget {
  const HabitatCareSheet({
    super.key,
    required this.habitat,
    required this.cat,
    required this.sprites,
    required this.preference,
    required this.onAction,
    this.onInventory,
  });

  final HabitatService habitat;
  final HabitatCat cat;
  final HabitatSprites sprites;
  final String preference;
  final ValueChanged<String> onAction;
  final VoidCallback? onInventory;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: habitat,
    builder: (context, _) {
      final enabled =
          habitat.session.isSignedIn && !habitat.offline && !habitat.caring;
      final affinity = habitat.affinity(cat.id);
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    HabitatCatPreview(cat: cat, size: 82),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            preference == 'descanso'
                                ? 'Gosta de cantinhos tranquilos'
                                : 'Gosta de brincar no quintal',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vínculo $affinity pontos',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTitle,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: (affinity / 200).clamp(0, 1),
                            color: AppColors.primary,
                            backgroundColor: AppColors.primaryLight,
                            minHeight: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (habitat.production.isNotEmpty) ...[
                  Text(
                    quintalAppetiteText(
                      habitat.productionCat(cat.id),
                      habitat.serverNow,
                    ),
                  ),
                  Text(
                    habitat.productionCat(cat.id)['water_available'] == true
                        ? 'Água disponível no pote'
                        : 'O pote precisa de água',
                  ),
                  const SizedBox(height: 12),
                ],
                QuintalBondProgress(
                  habitat: habitat,
                  catId: cat.id,
                  sprites: sprites,
                  onInventory: onInventory,
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: enabled && !habitat.caredToday(cat.id, 'pet')
                      ? () => onAction('pet')
                      : null,
                  icon: const Icon(LucideIcons.heart),
                  label: Text(
                    habitat.caredToday(cat.id, 'pet')
                        ? 'Carinho recebido hoje'
                        : 'Fazer carinho · +1 afinidade',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: enabled ? () => onAction('play') : null,
                  icon: const QuintalArtwork('action_play', size: 36),
                  label: const Text('Brincar com a varinha'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Alimente e abasteça água pelos potes identificados do seu gato.',
                ),
                if (habitat.productionCat(cat.id)['assisted'] == true)
                  OutlinedButton.icon(
                    onPressed: enabled ? () => onAction('setup') : null,
                    icon: const Icon(LucideIcons.droplets),
                    label: const Text('Posicionar os dois potes'),
                  ),
                const SizedBox(height: 12),
                Text(
                  enabled
                      ? 'Cada cuidado conta uma vez por gato ao dia. A afinidade nunca diminui.'
                      : 'Conecte sua conta para registrar os cuidados.',
                  style: const TextStyle(color: AppColors.textMedium),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
