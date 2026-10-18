import 'package:flutter/material.dart';

import '../game/habitat_sprites.dart';
import '../services/habitat_service.dart';
import '../theme/app_theme.dart';
import 'habitat_sprite_preview.dart';

/// Thresholds and prizes come from the same catalog used to grant the items.
class QuintalBondProgress extends StatelessWidget {
  const QuintalBondProgress({
    super.key,
    required this.habitat,
    required this.catId,
    required this.sprites,
    this.onInventory,
  });
  final HabitatService habitat;
  final String catId;
  final HabitatSprites sprites;
  final VoidCallback? onInventory;

  @override
  Widget build(BuildContext context) {
    final affinity = habitat.affinity(catId);
    final rewards = habitat.productionRows(
      'bond_rewards',
      catalog: true,
    )..sort((a, b) => (a['threshold'] as num).compareTo(b['threshold'] as num));
    if (rewards.isEmpty) {
      return const Text(
        'Os cuidados fortalecem a amizade. Os próximos prêmios aparecem ao atualizar o Quintal.',
      );
    }
    final next = rewards
        .where((r) => (r['threshold'] as num) > affinity)
        .firstOrNull;
    final earned = rewards
        .where((r) => (r['threshold'] as num) <= affinity)
        .toList();
    final definition = next == null
        ? null
        : HabitatService.catalogItem(next['sku'].toString());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            next == null
                ? 'Todos os marcos de amizade alcançados!'
                : 'Próximo marco: ${next['threshold']} pontos',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 8),
          if (next != null)
            Row(
              children: [
                if (definition != null) ...[
                  HabitatSpritePreview(
                    sprites: sprites,
                    keyName: sprites.keyFor(definition.displaySprite, 0),
                    size: 56,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next['name'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Faltam ${(next['threshold'] as num).toInt() - affinity} pontos.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'Seus prêmios estão em Inventário · Decorações.'
                : 'Ao receber: Inventário · Decorações.',
          ),
          if (earned.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Marcos alcançados: ${earned.map((r) => r['threshold']).join(', ')} pontos.',
            ),
            if (onInventory != null)
              TextButton(
                onPressed: onInventory,
                child: const Text('Ver decorações'),
              ),
          ],
        ],
      ),
    );
  }
}
