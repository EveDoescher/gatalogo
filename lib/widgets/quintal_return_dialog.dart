import 'package:flutter/material.dart';

import '../services/habitat_service.dart';
import '../theme/app_theme.dart';
import 'quintal_production_widgets.dart';

class QuintalReturnSelection {
  const QuintalReturnSelection(this.eventIds, [this.destination]);
  final List<String> eventIds;
  final String? destination;
}

/// A snapshot of the return report; refreshing the yard cannot change its receipts.
class QuintalReturnDialog extends StatelessWidget {
  const QuintalReturnDialog({
    super.key,
    required this.habitat,
    required this.updates,
  });
  final HabitatService habitat;
  final List<Map<String, dynamic>> updates;

  static const spaces = {
    'garden': 'Horta',
    'kitchen': 'Cozinha',
    'market': 'Mercadinho',
    'coop': 'Galinheiro',
    'pasture': 'Pasto',
    'orchard': 'Pomar',
    'pier': 'Píer',
  };

  String recipe(String id) =>
      habitat
          .productionRows('recipes', catalog: true)
          .where((r) => r['id'] == id)
          .firstOrNull?['name']
          ?.toString() ??
      'Ração básica';

  (String, String, String, String?) entry(Map<String, dynamic> update) {
    final target = update['target']?.toString() ?? '';
    final quantity = update['quantity'] ?? 1;
    switch (update['kind']) {
      case 'meal':
      case 'refused':
        final name =
            habitat.cats.where((c) => c.id == target).firstOrNull?.name ??
            'Seu gato';
        final refused = update['kind'] == 'refused';
        return (
          refused ? '$name recusou a ração' : '$name se alimentou',
          '${recipe(update['recipe']?.toString() ?? 'basic')} · ${refused ? '1 porção perdida' : '1 porção consumida'}',
          QuintalArtwork.recipe(update['recipe']?.toString() ?? 'basic'),
          null,
        );
      case 'cook':
        final outputs = update['outputs'] as Map? ?? {};
        final count = outputs.values.whereType<num>().fold<num>(
          0,
          (a, b) => a + b,
        );
        return (
          recipe(target),
          '$count porções prontas na cozinha',
          QuintalArtwork.recipe(target),
          'kitchen',
        );
      case 'order':
        final outputs = update['outputs'] as Map? ?? {};
        final count = outputs.values.whereType<num>().fold<num>(
          0,
          (a, b) => a + b,
        );
        return (
          target == 'beef' ? 'Carne disponível' : 'Frango disponível',
          '$count unidades esperando retirada',
          target,
          'market',
        );
      case 'harvest':
        final resources =
            habitat.production['catalog']?['resources'] as Map? ?? {};
        return (
          '${resources[target] ?? target} pronto para colher',
          '$quantity unidades · canteiro ${(update['slot'] as num? ?? 0) + 1}',
          const {'corn', 'wheat', 'carrot', 'pumpkin'}.contains(target)
              ? target
              : 'action_plant_seedling',
          'garden',
        );
      case 'resident':
        final product = target == 'coop'
            ? 'ovos'
            : target == 'pasture'
            ? 'leite'
            : 'frutas';
        return (
          '${spaces[target] ?? target}: $product disponíveis',
          '$quantity unidades para coletar',
          target == 'coop'
              ? 'egg'
              : target == 'pasture'
              ? 'milk'
              : 'action_plant_seedling',
          target,
        );
      case 'build':
        final space = target == 'rod' ? 'pier' : target;
        return (
          '${spaces[space] ?? target}: melhoria pronta',
          'Nível ${update['level']} · toque para concluir',
          'action_upgrade',
          space,
        );
      default:
        return ('Novidade no Quintal', 'Confira no cenário', 'ready', null);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: AppColors.primary, width: 2),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Novidades do Quintal',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Os produtos continuam esperando sua coleta.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final update in updates)
                      Builder(
                        builder: (context) {
                          final (title, detail, art, space) = entry(update);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                leading: QuintalArtwork(art, size: 44),
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(detail),
                                trailing: space == null
                                    ? null
                                    : const Icon(Icons.chevron_right),
                                onTap: space == null
                                    ? null
                                    : () => Navigator.pop(
                                        context,
                                        QuintalReturnSelection([
                                          if (update['event_id'] is String)
                                            update['event_id'] as String,
                                        ], space),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  QuintalReturnSelection([
                    for (final update in updates)
                      if (update['event_id'] is String)
                        update['event_id'] as String,
                  ]),
                ),
                child: const Text('Entendi, continuar no Quintal'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
