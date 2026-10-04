import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/habitat_sprites.dart';
import '../services/habitat_service.dart';
import '../theme/app_theme.dart';
import 'habitat_sprite_preview.dart';

class HabitatCareSheet extends StatelessWidget {
  const HabitatCareSheet({
    super.key,
    required this.habitat,
    required this.cat,
    required this.sprites,
    required this.preference,
    required this.onAction,
  });

  final HabitatService habitat;
  final HabitatCat cat;
  final HabitatSprites sprites;
  final String preference;
  final ValueChanged<String> onAction;

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
                    HabitatSpritePreview(
                      sprites: sprites,
                      keyName: 'animal-cat',
                      size: 82,
                    ),
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
                            'Afinidade $affinity/100',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTitle,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: affinity / 100,
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
                Text(
                  affinity < 20
                      ? 'Aos 20 pontos, você ganha Flores da amizade para decorar.'
                      : 'A amizade de vocês desbloqueou Flores da amizade.',
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
                Text('Comida', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${habitat.freePortions} porções gratuitas disponíveis hoje',
                ),
                const SizedBox(height: 8),
                _foodButton(
                  'Porção diária',
                  'Grátis · +5 afinidade',
                  'bag_NE',
                  enabled &&
                          habitat.freePortions > 0 &&
                          !habitat.caredToday(cat.id, 'feed')
                      ? () => onAction('feed')
                      : null,
                ),
                _foodButton(
                  'Petisco',
                  '${habitat.treatPrice} moedas · +3 afinidade',
                  'can-open_NE',
                  enabled &&
                          habitat.balance >= habitat.treatPrice &&
                          !habitat.caredToday(cat.id, 'treat')
                      ? () => onAction('treat')
                      : null,
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

  Widget _foodButton(
    String name,
    String subtitle,
    String sprite,
    VoidCallback? action,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: AppColors.inputBg,
      leading: HabitatSpritePreview(
        sprites: sprites,
        keyName: sprite,
        size: 45,
      ),
      title: Text(name),
      subtitle: Text(subtitle),
      trailing: const Icon(LucideIcons.chevronRight, size: 20),
      enabled: action != null,
      onTap: action,
    ),
  );
}
