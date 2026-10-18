import 'package:flutter/material.dart';

import '../services/habitat_service.dart';
import '../services/quintal_inventory.dart';
import '../theme/app_theme.dart';
import 'quintal_production_widgets.dart';

/// Inventory remains inside the scene. Decorations keep their placement gestures.
class QuintalInventoryTray extends StatefulWidget {
  const QuintalInventoryTray({
    super.key,
    required this.habitat,
    required this.decorations,
    required this.onClose,
    required this.onKitchen,
    this.initialTab = 0,
    this.onDestination,
    this.onTabChanged,
  });
  final HabitatService habitat;
  final Widget decorations;
  final VoidCallback onClose, onKitchen;
  final int initialTab;
  final void Function(String space, String? target)? onDestination;
  final ValueChanged<int>? onTabChanged;
  @override
  State<QuintalInventoryTray> createState() => _QuintalInventoryTrayState();
}

class _QuintalInventoryTrayState extends State<QuintalInventoryTray> {
  late int tab = widget.initialTab;
  String? selected;
  HabitatService get h => widget.habitat;

  String name(String id) => id.startsWith('ration:')
      ? (h
                .productionRows('recipes', catalog: true)
                .where((r) => r['id'] == id.substring(7))
                .firstOrNull?['name']
                ?.toString() ??
            'Ração')
      : (h.production['catalog']?['resources']?[id]?.toString() ?? id);
  String art(String id) =>
      id.startsWith('ration:') ? QuintalArtwork.recipe(id.substring(7)) : id;

  Widget stock() {
    final entries = quintalInventory(h).values
        .where((e) => e.id.startsWith('ration:') == (tab == 1))
        .toList();
    if (entries.isEmpty) {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QuintalArtwork(
              tab == 1 ? 'action_cook_pot' : 'action_harvest_basket',
              size: 62,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tab == 1
                        ? 'Prepare rações na cozinha.'
                        : 'Seus ingredientes ficam aqui.',
                    textAlign: TextAlign.center,
                  ),
                  if (tab == 1)
                    TextButton(
                      onPressed: widget.onKitchen,
                      child: const Text('Ir até a cozinha'),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (selected != null && !entries.any((e) => e.id == selected)) {
      selected = null;
    }
    if (selected != null) {
      return _resourceDetails(entries.firstWhere((e) => e.id == selected));
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final e = entries[index];
              return Semantics(
                button: true,
                selected: selected == e.id,
                label:
                    '${name(e.id)}, ${e.available} disponíveis, ${e.ready} aguardando coleta',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => selected = e.id),
                    child: Container(
                      width: 110,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: selected == e.id
                            ? AppColors.greenLight
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                QuintalArtwork(art(e.id), size: 78),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${e.available} livres',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            name(e.id),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            'Toque para ver quantidades e onde usar',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
        ),
      ],
    );
  }

  void _go(String space, [String? target]) {
    if (widget.onDestination != null) {
      widget.onDestination!(space, target);
    } else if (space == 'kitchen') {
      widget.onKitchen();
    }
  }

  Widget _resourceDetails(QuintalInventoryEntry entry) {
    final id = entry.id, ration = id.startsWith('ration:');
    final recipes = h
        .productionRows('recipes', catalog: true)
        .where((r) => (r['ingredients'] as Map? ?? const {}).containsKey(id));
    final orders = h
        .productionRows('orders', catalog: true)
        .where(
          (r) =>
              (r['products'] as Map? ?? const {}).containsKey(id) ||
              (r['product_options'] as List? ?? const []).any(
                (option) =>
                    (option['products'] as Map? ?? const {}).containsKey(id),
              ),
        );
    final preferences =
        h.production['catalog']?['preferences'] as List? ?? const [];
    final cats = h.cats.where((c) => h.selectedCatIds.contains(c.id));
    Widget link(String label, String space, [String? target]) => TextButton(
      onPressed: widget.onDestination != null || space == 'kitchen'
          ? () => _go(space, target)
          : null,
      child: Text(label),
    );
    return Scrollbar(
      thumbVisibility: true,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Voltar aos recursos',
                onPressed: () => setState(() => selected = null),
                icon: const Icon(Icons.arrow_back),
              ),
              QuintalArtwork(art(id), size: 48),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name(id),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textTitle,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '${entry.available} disponíveis',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.greenLink,
            ),
          ),
          if (entry.reserved > 0)
            Text('${entry.reserved} reservados em preparos/pedidos'),
          if (entry.preparing > 0)
            Text('${entry.preparing} em preparo ou na fila'),
          if (entry.served > 0)
            Text(
              '${entry.served} ${entry.served == 1 ? 'porção servida' : 'porções servidas'} nos potes',
            ),
          if (entry.ready > 0) Text('${entry.ready} aguardando coleta'),
          for (final space in entry.collectionSpaces)
            link(
              'Ver coleta · ${switch (space) {
                'kitchen' => 'Cozinha',
                'market' => 'Mercadinho',
                'garden' => 'Horta',
                'coop' => 'Galinheiro',
                'pasture' => 'Pasto',
                _ => 'Pomar',
              }}',
              space,
              space == 'orchard' ? id : null,
            ),
          if (recipes.isNotEmpty) ...[
            Text('Na cozinha: ${recipes.map((r) => r['name']).join(', ')}'),
            link('Ir até a cozinha', 'kitchen'),
          ],
          if (orders.isNotEmpty) ...[
            Text(
              'Trocas no Mercadinho: ${orders.map((r) => r['name']).join(', ')}',
            ),
            link('Ver trocas', 'market'),
          ],
          if (id == 'corn') ...[
            const Text('Também abastece galinhas e vacas.'),
            link('Ver galinheiro', 'coop'),
            link('Ver pasto', 'pasture'),
          ],
          if (id == 'wheat') ...[
            const Text('Também abastece as vacas.'),
            link('Ver pasto', 'pasture'),
          ],
          if (ration) ...[
            for (final cat in cats)
              Builder(
                builder: (context) {
                  final preference = h.foodPreference(cat.id, id.substring(7));
                  final taste =
                      preference != null &&
                          preference >= 0 &&
                          preference < preferences.length
                      ? preferences[preference].toString()
                      : 'ainda não provou';
                  final bowl = h.productionCat(cat.id)['food_bowl'];
                  final placed = h.items.any(
                    (item) => item.id == bowl && item.isPlaced,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${cat.name}: $taste'),
                      if (placed)
                        link('Ver pote de ${cat.name}', 'cat', cat.id),
                    ],
                  );
                },
              ),
            if (cats.isEmpty)
              const Text('Coloque um gato no Quintal para servir esta ração.'),
            link('Preparar mais', 'kitchen'),
          ],
          if (!ration &&
              recipes.isEmpty &&
              orders.isEmpty &&
              id != 'corn' &&
              id != 'wheat')
            const Text(
              'Este ingrediente ainda não tem receita ou troca no catálogo.',
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: h,
    builder: (context, _) => Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 258,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Inventário',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ),
                  if (h.offline || h.productionOffline)
                    const Tooltip(
                      message: 'Último estoque salvo',
                      child: Icon(Icons.cloud_off_outlined, size: 18),
                    ),
                  IconButton(
                    tooltip: 'Fechar bandeja',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 19),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                for (final (index, label) in [
                  'Decorações',
                  'Rações',
                  'Ingredientes',
                ].indexed)
                  Expanded(
                    flex: const [10, 6, 12][index],
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          tab = index;
                          selected = null;
                        });
                        widget.onTabChanged?.call(index);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: tab == index
                                  ? AppColors.greenLink
                                  : AppColors.borderLight,
                              width: tab == index ? 3 : 1,
                            ),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            color: tab == index
                                ? AppColors.greenLink
                                : AppColors.textMedium,
                            fontWeight: tab == index
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(child: tab == 0 ? widget.decorations : stock()),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
