import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/quintal_scene_target.dart';
import '../game/quintal_construction_preview.dart';
import '../game/quintal_timed_progress.dart';
import '../game/habitat_game.dart';
import '../services/habitat_service.dart';
import '../services/quintal_cat_meal.dart';
import '../services/product_api_service.dart';
import '../theme/app_theme.dart';
import 'habitat_object_balloon.dart';
import 'quintal_production_widgets.dart';
import 'quintal_game_action.dart';
import 'quintal_recipe_tile.dart';
import 'quintal_preparation_tile.dart';

class QuintalObjectOverlay extends StatefulWidget {
  const QuintalObjectOverlay({
    super.key,
    required this.game,
    required this.target,
    required this.onClose,
    required this.onFish,
  });
  final HabitatGame game;
  final QuintalSceneTarget target;
  final VoidCallback onClose, onFish;
  @override
  State<QuintalObjectOverlay> createState() => _QuintalObjectOverlayState();
}

class _QuintalObjectOverlayState extends State<QuintalObjectOverlay> {
  bool docked = false;
  bool _needsFraming = true;
  HabitatGame get game => widget.game;
  QuintalSceneTarget get target => widget.target;
  @override
  void didUpdateWidget(covariant QuintalObjectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.kind != target.kind ||
        oldWidget.target.role != target.role ||
        oldWidget.target.target != target.target) {
      game.previewConstruction(null, notify: false);
      docked = false;
      _needsFraming = true;
    }
  }

  @override
  void dispose() {
    game.previewConstruction(null, notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: AnimatedBuilder(
      animation: game.interactionPositions,
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _needsFraming = true;
          return false;
        },
        child: SizeChangedLayoutNotifier(
          child: QuintalObjectActions(
            key: ValueKey('${target.kind}:${target.role}:${target.target}'),
            habitat: game.habitat,
            target: target,
            onClose: widget.onClose,
            onFish: widget.onFish,
            onConfirmed: game.showProductionAction,
            onConstructionPreview: game.previewConstruction,
            onPanelChanged: (value) => setState(() {
              if (docked && !value) _needsFraming = true;
              docked = value;
            }),
          ),
        ),
      ),
      builder: (context, child) {
        if (game.activityInProgress) return const SizedBox.shrink();
        final anchor = game.productionFocus(target);
        final height = game.productionObjectHeight(target);
        final showingTool =
            game.productionToolActive(target) ||
            game.productionBowlActive(target);
        return IgnorePointer(
          ignoring: showingTool,
          child: AnimatedOpacity(
            opacity: showingTool ? 0 : 1,
            duration: game.reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 80),
            child: HabitatObjectBalloon(
              key: ValueKey('${target.kind}:${target.role}:${target.target}'),
              anchor: anchor,
              objectHeight: height,
              showPointer: false,
              docked: docked,
              onReframeChanged: (delta) {
                if (!mounted || docked || !_needsFraming) return;
                _needsFraming = false;
                if (delta == Offset.zero) return;
                game.moveCamera(delta);
                setState(() {});
              },
              maxWidth: docked ? game.size.x - 16 : 280,
              safeInsets: EdgeInsets.fromLTRB(
                8,
                78,
                8,
                MediaQuery.paddingOf(context).bottom + 12,
              ),
              child: child!,
            ),
          ),
        );
      },
    ),
  );
}

/// First tap exposes a short action bar. Only choices open the compact tray.
class QuintalObjectActions extends StatefulWidget {
  const QuintalObjectActions({
    super.key,
    required this.habitat,
    required this.target,
    required this.onClose,
    required this.onFish,
    this.onPanelChanged,
    this.onConfirmed,
    this.onConstructionPreview,
  });
  final HabitatService habitat;
  final QuintalSceneTarget target;
  final VoidCallback onClose, onFish;
  final ValueChanged<bool>? onPanelChanged;
  final ValueChanged<String?>? onConstructionPreview;
  final void Function(QuintalSceneTarget target, String action)? onConfirmed;
  @override
  State<QuintalObjectActions> createState() => _QuintalObjectActionsState();
}

class _QuintalObjectActionsState extends State<QuintalObjectActions> {
  String? _panel, _message;
  bool _busy = false;
  int _quantity = 1;
  Timer? _timer;
  HabitatService get h => widget.habitat;
  QuintalSceneTarget get t => widget.target;
  bool get enabled =>
      !_busy && !h.offline && !h.productionOffline && !h.productionBusy;
  bool ready(dynamic at) =>
      DateTime.tryParse(at?.toString() ?? '')?.isAfter(h.serverNow) == false;
  Map<String, dynamic> get resident =>
      h
          .productionRows('residents')
          .where((r) => r['kind'] == t.kind)
          .firstOrNull ??
      {};
  Map<String, dynamic> get plot =>
      h
          .productionRows('plots')
          .where((p) => p['slot'].toString() == t.target)
          .firstOrNull ??
      {};
  Map<String, dynamic> get selectedResident {
    final slot = t.kind == 'orchard'
        ? (t.target == 'apple' ? 0 : 1)
        : int.tryParse(t.target);
    return Map<String, dynamic>.from(
      ((resident['animals'] as List?) ?? [])
              .where((a) => a['slot'] == slot)
              .firstOrNull ??
          {},
    );
  }

  List<Map<String, dynamic>> tasks(String kind) =>
      h.productionRows('tasks').where((a) => a['kind'] == kind).toList()..sort(
        (a, b) => a['ready_at'].toString().compareTo(b['ready_at'].toString()),
      );
  bool isReady(Map task) =>
      task['status'] == 'ready' || ready(task['ready_at']);
  int get hungry => (resident['animals'] as List? ?? [])
      .where((a) => a['food_until'] == null || ready(a['food_until']))
      .length;
  bool hasIngredients(Map needs) => needs.entries.every(
    (e) => (h.productionStock[e.key] ?? 0) >= (e.value as num),
  );
  String resource(dynamic id) =>
      h.production['catalog']?['resources']?[id]?.toString() ?? id.toString();
  String recipeName(dynamic id) =>
      h
          .productionRows('recipes', catalog: true)
          .where((r) => r['id'] == id)
          .firstOrNull?['name']
          ?.toString() ??
      'Ração básica';
  String get upgradeKind => t.kind == 'pier' ? 'rod' : t.kind;
  Map<String, dynamic>? get offer => h
      .productionRows('offers')
      .where((o) => o['id'].toString().startsWith('$upgradeKind:'))
      .firstOrNull;
  String get title => switch (t.role) {
    'plot' => 'Canteiro ${int.parse(t.target) + 1}',
    'food' =>
      t.kind == 'coop' ? 'Comedouro das galinhas' : 'Comedouro das vaquinhas',
    'water' => t.kind == 'coop' ? 'Água das galinhas' : 'Água das vaquinhas',
    'food_cat' || 'water_cat' =>
      '${t.role == 'food_cat' ? 'Pote' : 'Água'} de ${h.cats.where((c) => c.id == t.target).firstOrNull?.name ?? 'seu gato'}',
    'collect' =>
      t.kind == 'coop'
          ? 'Galinheiro'
          : t.kind == 'pasture'
          ? 'Leite fresquinho'
          : t.target == 'apple'
          ? 'Macieira'
          : 'Pereira',
    'resident' =>
      resident['names']?[t.target]?.toString() ??
          '${t.kind == 'coop' ? 'Galinha' : 'Vaquinha'} ${int.parse(t.target) + 1}',
    _ => facilityTitle,
  };
  String get facilityTitle =>
      const {
        'garden': 'Horta',
        'coop': 'Galinheiro',
        'pasture': 'Pasto',
        'kitchen': 'Cozinha',
        'market': 'Mercadinho rural',
        'pier': 'Píer',
        'orchard': 'Pomar',
      }[t.kind] ??
      'Quintal';
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> act(
    String action,
    String target, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (!enabled) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final before = Map<String, int>.of(h.productionStock);
    final actedObject = action == 'harvest'
        ? QuintalSceneTarget(
            t.kind,
            t.target,
            t.role,
            t.x,
            t.y,
            crop: plot['crop'] as String?,
          )
        : t;
    final previous = QuintalCatMeal.fromCare(h.productionCat(target))?.eventId;
    try {
      await h.produce(action, target, data);
      widget.onConfirmed?.call(actedObject, action);
      if (!mounted) return;
      final reaction = QuintalCatMeal.fromCare(h.productionCat(target));
      final gained = h.productionStock.entries
          .where((e) => e.value > (before[e.key] ?? 0))
          .map(
            (e) =>
                '+${e.value - (before[e.key] ?? 0)} ${e.key.startsWith('ration:') ? 'porções' : resource(e.key)}',
          )
          .join(' · ');
      setState(() {
        _panel = null;
        _message = switch (action) {
          'harvest' ||
          'collect' ||
          'collect_residents' => gained.isEmpty ? 'Guardado!' : gained,
          'plant' => 'Plantado!',
          'water_crop' => 'Regado! Crescimento adiantado.',
          'cook' => 'Preparo colocado na fila.',
          'order' => 'Pedido confirmado!',
          'build' => 'Obra iniciada.',
          'finish_build' => 'Tudo pronto!',
          'water_cat' || 'water_residents' => 'Água fresquinha por 24 h!',
          'feed_residents' => 'Comedouro abastecido por 24 h!',
          'serve' =>
            reaction != null && reaction.eventId != previous
                ? reaction.reactionText
                : 'Porção guardada no pote.',
          _ => 'Feito!',
        };
      });
      widget.onConstructionPreview?.call(null);
      widget.onPanelChanged?.call(false);
    } on ProductApiException catch (e) {
      if (mounted) {
        setState(() {
          _message = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget button(IconData icon, String label, VoidCallback? callback) {
    final art = switch (label) {
      'Colher' => 'action_harvest_basket',
      'Recolher' => switch (t.kind) {
        'coop' => 'action_collect_eggs',
        'pasture' => 'action_collect_milk',
        'kitchen' => 'action_cook_pot',
        _ => 'action_harvest_basket',
      },
      'Tirar leite' => 'action_collect_milk',
      'Plantar' => 'action_plant_seedling',
      'Regar' || 'Regado' => 'action_water_can',
      'Encher' || 'Abastecido' => 'action_refill_water',
      'Receitas' => 'action_recipe_book',
      'Servir' || 'Abastecer' => 'action_serve_food',
      'Pescar' => 'action_fish_rod',
      'Fila' => 'action_production_queue',
      'Fazer pedido' => 'action_order_market',
      'Retirar' => 'action_pickup_delivery',
      'Ver projeto' || 'Consertar' || 'Construir' => 'action_repair_tools',
      'Ampliar' || 'Melhorar' => 'action_upgrade',
      'Nome' => 'action_rename',
      'Produtos' || 'Frutas' => 'action_trade',
      'Concluir' => 'ready',
      'Moedas' => 'coin',
      _ => null,
    };
    return QuintalGameAction(
      label: label,
      artwork: art == null
          ? Icon(icon, size: 36, color: AppColors.textTitle)
          : QuintalArtwork(art, size: 76),
      onPressed: enabled ? callback : null,
    );
  }

  String cropArtwork(dynamic crop) => switch (crop) {
    'corn' => 'crops_cornStageD',
    'wheat' => 'crops_wheatStageB',
    null => 'crops_leafsStageA',
    _ => 'crop_$crop',
  };
  Widget command(
    IconData icon,
    String label,
    String action,
    String target, {
    Map<String, dynamic> data = const {},
    bool available = true,
  }) => button(icon, label, available ? () => act(action, target, data) : null);
  Widget status(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textTitle),
        ),
      ),
    ),
  );
  Widget bar(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 10),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 6,
      children: [
        for (final (i, child) in children.indexed)
          Padding(
            padding: EdgeInsets.only(
              top: children.length > 1 && i != children.length ~/ 2 ? 10 : 0,
            ),
            child: child,
          ),
      ],
    ),
  );
  void open(String panel) {
    setState(() {
      _panel = panel;
      _message = null;
    });
    widget.onConstructionPreview?.call(
      panel == 'construction'
          ? t.kind
          : panel == 'upgrade'
          ? upgradeKind
          : null,
    );
    widget.onPanelChanged?.call(true);
  }

  void back() {
    setState(() => _panel = null);
    widget.onConstructionPreview?.call(null);
    widget.onPanelChanged?.call(false);
  }

  List<Widget> root() {
    if (t.role == 'build') {
      final building = h
          .productionRows('facilities')
          .any(
            (f) => f['kind'] == t.kind && (f['target_level'] as num? ?? 0) > 0,
          );
      if (building) return construction(t.kind);
      return [
        status('Um cantinho abandonado para recuperar'),
        bar([
          button(LucideIcons.hammer, 'Ver projeto', () => open('construction')),
        ]),
      ];
    }
    if (t.role == 'plot') {
      if (plot['crop'] == null) {
        return [
          status('Um cantinho para cultivar'),
          bar([button(LucideIcons.sprout, 'Plantar', () => open('crops'))]),
        ];
      }
      return [
        status(resource(plot['crop'])),
        if (!ready(plot['ready_at']))
          status('Colheita em ${remaining(plot['ready_at'])}'),
        bar([
          if (ready(plot['ready_at']))
            command(LucideIcons.wheat, 'Colher', 'harvest', t.target)
          else
            command(
              LucideIcons.droplets,
              plot['watered'] == true ? 'Regado' : 'Regar',
              'water_crop',
              t.target,
              available: plot['watered'] != true,
            ),
        ]),
      ];
    }
    if (t.role == 'food_cat') {
      final cat = h.productionCat(t.target);
      final portions = (cat['portions'] as num?)?.toInt() ?? 0;
      final meal = QuintalCatMeal.fromCare(cat);
      return [
        status(
          portions == 0
              ? 'Pote vazio · 0/2 porções'
              : '$portions/2 porções · ${recipeName(cat['recipe'])}',
        ),
        status(quintalAppetiteText(cat, h.serverNow)),
        if (meal != null)
          status('${recipeName(meal.recipe)} · ${meal.reactionText}'),
        if (meal?.tasteChange case final change?) status(change),
        bar([button(LucideIcons.utensils, 'Servir', () => open('food'))]),
      ];
    }
    if (t.role == 'water_cat') {
      final cat = h.productionCat(t.target);
      return [
        status(
          cat['water_available'] == true
              ? 'Água disponível'
              : 'O pote está vazio',
        ),
        bar([
          command(
            LucideIcons.droplets,
            cat['water_day'] == h.productionDay ? 'Abastecido' : 'Encher',
            'water_cat',
            t.target,
            available: cat['water_day'] != h.productionDay,
          ),
        ]),
      ];
    }
    if (t.role == 'food') {
      final needs = t.kind == 'coop'
          ? {'corn': hungry}
          : {'corn': hungry, 'wheat': hungry * 2};
      return [
        status(hungry == 0 ? 'Todos têm comida por hoje' : ingredients(needs)),
        if (hungry > 0 && !hasIngredients(needs))
          status('Colha mais ingredientes na horta'),
        bar([
          command(
            LucideIcons.wheat,
            'Abastecer',
            'feed_residents',
            t.kind,
            available: hungry > 0 && hasIngredients(needs),
          ),
        ]),
      ];
    }
    if (t.role == 'water') {
      return [
        status(
          resident['water_until'] != null && !ready(resident['water_until'])
              ? 'Água disponível'
              : 'Bebedouro vazio',
        ),
        bar([
          command(
            LucideIcons.droplets,
            resident['water_day'] == h.productionDay ? 'Abastecido' : 'Encher',
            'water_residents',
            t.kind,
            available: resident['water_day'] != h.productionDay,
          ),
        ]),
      ];
    }
    if (t.role == 'collect') {
      final collection = t.kind == 'orchard' ? selectedResident : resident;
      final progress = QuintalTimedProgress.fromRow(collection);
      final pause = progress?.pauseAt(h.serverNow);
      return [
        status(
          '${collection['ready'] ?? 0} ${t.kind == 'coop'
              ? 'ovos'
              : t.kind == 'pasture'
              ? 'unidades de leite'
              : 'frutas'} para recolher',
        ),
        if ((collection['ready'] as num? ?? 0) == 0 &&
            collection['next_ready_at'] != null)
          status('Próximo lote em ${remaining(collection['next_ready_at'])}'),
        if ((collection['ready'] as num? ?? 0) == 0 && t.kind != 'orchard')
          status(
            pause == 'needs_food' || (progress == null && hungry > 0)
                ? 'A produção precisa de comida'
                : pause == 'needs_water' ||
                      (progress == null &&
                          (resident['water_until'] == null ||
                              ready(resident['water_until'])))
                ? 'A produção precisa de água'
                : 'Produzindo com os cuidados em dia',
          ),
        bar([
          command(
            LucideIcons.shoppingBasket,
            'Recolher',
            'collect_residents',
            t.kind,
            data: t.kind == 'orchard'
                ? {'resident_id': selectedResident['id']}
                : const {},
            available:
                (collection['ready'] as num? ?? 0) > 0 &&
                (t.kind != 'orchard' || selectedResident['id'] != null),
          ),
        ]),
      ];
    }
    if (t.role == 'resident') {
      final animal = (resident['animals'] as List? ?? [])
          .where((a) => a['slot'].toString() == t.target)
          .firstOrNull;
      return [
        if (t.kind == 'pasture')
          status('${animal?['ready'] ?? 0} unidades de leite disponíveis'),
        if (t.kind == 'pasture' && animal?['next_ready_at'] != null)
          status('Próximo leite em ${remaining(animal?['next_ready_at'])}'),
        status(
          animal?['food_until'] == null || ready(animal?['food_until'])
              ? 'Hora de abastecer o comedouro'
              : 'Comida disponível · cuidada',
        ),
        bar([
          if (t.kind == 'pasture')
            command(
              LucideIcons.droplets,
              'Tirar leite',
              'collect_residents',
              'pasture',
              data: {'resident_id': animal?['id']},
              available:
                  animal?['id'] != null && (animal?['ready'] as num? ?? 0) > 0,
            ),
          button(LucideIcons.pencil, 'Nome', rename),
        ]),
      ];
    }
    if (t.kind == 'pier') {
      return [
        status(
          'Vara nível ${h.facilityLevel('rod')} · ${h.production['counters']?['fish_day:${h.productionDay}'] ?? 0}/12 capturas',
        ),
        bar([button(LucideIcons.fish, 'Pescar', widget.onFish)]),
      ];
    }
    if (t.kind == 'kitchen') {
      final queue = tasks('cook'), complete = queue.where(isReady).toList();
      return [
        status(
          complete.isNotEmpty
              ? '${complete.length} lote(s) pronto(s)'
              : queue.isEmpty
              ? 'Prepare uma comidinha'
              : 'Pronto em ${remaining(queue.first['ready_at'])}',
        ),
        bar([
          if (complete.isNotEmpty)
            command(
              LucideIcons.shoppingBasket,
              'Recolher',
              'collect',
              complete.first['id'],
            ),
          button(LucideIcons.cookingPot, 'Receitas', () => open('recipes')),
          if (queue.isNotEmpty)
            button(LucideIcons.clock, 'Fila', () => open('queue')),
        ]),
      ];
    }
    if (t.kind == 'market') {
      final queue = tasks('order');
      return [
        status(
          queue.isEmpty
              ? 'Ingredientes para suas receitas'
              : isReady(queue.first)
              ? 'Seu pedido está pronto!'
              : 'Chega em ${remaining(queue.first['ready_at'])}',
        ),
        bar([
          if (queue.isEmpty)
            button(
              LucideIcons.shoppingBag,
              'Fazer pedido',
              () => open('orders'),
            )
          else
            command(
              LucideIcons.package,
              'Retirar',
              'collect',
              queue.first['id'],
              available: isReady(queue.first),
            ),
        ]),
      ];
    }
    return [status('Espaço pronto para usar')];
  }

  String remaining(dynamic at) {
    final seconds =
        (DateTime.tryParse(at?.toString() ?? '')
                    ?.difference(h.serverNow)
                    .inSeconds ??
                0)
            .clamp(0, 999999);
    return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  String ingredients(Map needs) => needs.entries
      .map(
        (e) =>
            '${e.value} ${resource(e.key)} (${h.productionStock[e.key] ?? 0})',
      )
      .join(' · ');
  List<Widget> construction(String kind) {
    final f = h
        .productionRows('facilities')
        .where((e) => e['kind'] == kind)
        .firstOrNull;
    if ((f?['target_level'] as num? ?? 0) > 0) {
      final capacity = quintalCapacityChange(
        kind,
        h.facilityLevel(kind),
        (f!['target_level'] as num).toInt(),
      );
      return [
        if (capacity != null) status(capacity),
        if (kind == 'kitchen') status('Um preparo por vez'),
        status(
          ready(f['ready_at'])
              ? 'Obra pronta!'
              : 'Fica pronto em ${remaining(f['ready_at'])}',
        ),
        bar([
          command(
            LucideIcons.check,
            'Concluir',
            'finish_build',
            kind,
            available: ready(f['ready_at']),
          ),
        ]),
      ];
    }
    final offer = h
        .productionRows('offers')
        .where((o) => o['id'].toString().startsWith('$kind:'))
        .firstOrNull;
    final def = h
        .productionRows('facilities', catalog: true)
        .where((f) => f['id'] == offer?['id'])
        .firstOrNull;
    if (def == null) return [status('Todas as melhorias concluídas')];
    final targetLevel = int.tryParse(def['id'].toString().split(':').last) ?? 0;
    final capacity = quintalCapacityChange(
      kind,
      h.facilityLevel(kind),
      targetLevel,
    );
    return [
      status(def['name'].toString()),
      if (def['description'] case final String description) status(description),
      if (capacity != null) status(capacity),
      if (kind == 'kitchen') status('Um preparo por vez'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: QuintalPrice(def),
      ),
      for (final reason in offer?['reasons'] as List? ?? [])
        status(reason.toString()),
      bar([
        command(
          LucideIcons.hammer,
          h.facilityLevel(kind) == 0
              ? 'Consertar'
              : h.facilityLevel(kind) > 0
              ? 'Ampliar'
              : 'Construir',
          'build',
          def['id'],
          available: offer?['available'] == true,
        ),
      ]),
    ];
  }

  Widget choice(
    String art,
    String name,
    String description,
    VoidCallback? callback, {
    String? detail,
  }) => QuintalRecipeTile(
    art: art,
    name: name,
    description: description,
    detail: detail,
    onTap: enabled ? callback : null,
  );

  List<Widget> choiceLayout() {
    final items = choices();
    final tiles = items.whereType<QuintalRecipeTile>().toList();
    if (tiles.isEmpty) return items;
    return [
      ...items.where((w) => w is! QuintalRecipeTile),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: tiles,
        ),
      ),
    ];
  }

  List<Widget> choices() {
    if (_panel == 'construction') return construction(t.kind);
    if (_panel == 'upgrade') return construction(upgradeKind);
    if (_panel == 'crops') {
      return [
        for (final c
            in h
                .productionRows('crops', catalog: true)
                .where((c) => (c['level'] as num) <= h.facilityLevel('garden')))
          choice(
            c['id'] == 'corn'
                ? 'crops_cornStageD'
                : c['id'] == 'wheat'
                ? 'crops_wheatStageB'
                : 'crop_${c['id']}',
            c['name'],
            '${(c['seconds'] as num).toInt() ~/ 60} min · colhe ${c['yield']}',
            () => act('plant', t.target, {'crop': c['id']}),
          ),
      ];
    }
    if (_panel == 'recipes') {
      final queue = tasks('cook').where((a) => !isReady(a)).length,
          capacity = h.facilityLevel('kitchen') == 1 ? 2 : 4;
      return [
        status('$queue/$capacity lugares na fila'),
        for (final r
            in h
                .productionRows('recipes', catalog: true)
                .where(
                  (r) =>
                      h.facilityLevel(r['facility']) >= (r['level'] as num) &&
                      (!['beef', 'special'].contains(r['id']) ||
                          h.facilityLevel('market') > 0),
                ))
          choice(
            QuintalArtwork.recipe(r['id']),
            r['name'],
            '${(r['seconds'] as num).toInt() ~/ 60} min · ${r['yield']} porções',
            queue < capacity && hasIngredients(r['ingredients'])
                ? () => act('cook', r['id'])
                : null,
            detail: ingredients(r['ingredients']),
          ),
      ];
    }
    if (_panel == 'queue') {
      return [
        if (tasks('cook').isEmpty)
          status('A panela está livre. Escolha uma receita!'),
        for (final task in tasks('cook')) preparation(task),
      ];
    }
    if (_panel == 'food') {
      final cat = h.productionCat(t.target),
          prefs = h.production['catalog']?['preferences'] as List? ?? [];
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1 porção')),
              ButtonSegment(value: 2, label: Text('2 porções')),
            ],
            selected: {_quantity},
            onSelectionChanged: enabled
                ? (s) => setState(() => _quantity = s.first)
                : null,
          ),
        ),
        choice(
          QuintalArtwork.recipe('basic'),
          'Ração básica',
          '1 porção grátis por dia',
          cat['basic_day'] != h.productionDay
              ? () => act('serve', t.target, {'recipe': 'basic', 'quantity': 1})
              : null,
        ),
        for (final r in h.productionRows('recipes', catalog: true))
          choice(
            QuintalArtwork.recipe(r['id']),
            r['name'],
            '${h.productionStock['ration:${r['id']}'] ?? 0} no inventário',
            (h.productionStock['ration:${r['id']}'] ?? 0) >= _quantity
                ? () => serve(r['id'])
                : null,
            detail: h.foodPreference(t.target, r['id']) == null
                ? 'Preferência ainda desconhecida'
                : prefs[h.foodPreference(t.target, r['id'])!],
          ),
      ];
    }
    if (_panel == 'orders') {
      return [
        for (final o
            in h
                .productionRows('orders', catalog: true)
                .where((o) => h.expansionLevel >= (o['expansion'] as num))) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                QuintalArtwork(
                  o['id'] == 'chicken' ? 'turkey' : 'meat-raw',
                  size: 48,
                ),
                Expanded(
                  child: Text(
                    '${o['name']} · ${o['yield']} unidades',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: QuintalPrice(o),
          ),
          status('Pague com moedas ou escolha uma troca'),
          status('Produtos: ${ingredients(o['products'])}'),
          for (final option in o['product_options'] as List? ?? const [])
            if (option['id'] != 'harvest') ...[
              status('${option['name']}: ${ingredients(option['products'])}'),
              if (option['facility'] != null &&
                  h.facilityLevel(option['facility']) <
                      (option['level'] as num))
                status('Recupere o pomar para trocar frutas'),
            ],
          bar([
            command(
              LucideIcons.coins,
              'Moedas',
              'order',
              o['id'],
              data: {'payment': 'coins'},
              available: h.balance >= (o['price'] as num),
            ),
            command(
              LucideIcons.arrowLeftRight,
              'Produtos',
              'order',
              o['id'],
              data: {'payment': 'products'},
              available: hasIngredients(o['products']),
            ),
            for (final option in o['product_options'] as List? ?? const [])
              if (option['id'] != 'harvest')
                command(
                  LucideIcons.arrowLeftRight,
                  option['name'],
                  'order',
                  o['id'],
                  data: {'payment': 'products', 'product_option': option['id']},
                  available:
                      hasIngredients(option['products']) &&
                      (option['facility'] == null ||
                          h.facilityLevel(option['facility']) >=
                              (option['level'] as num)),
                ),
          ]),
        ],
      ];
    }
    return root();
  }

  Widget preparation(Map<String, dynamic> task) {
    final progress = QuintalTimedProgress.fromRow(task), now = h.serverNow;
    final waiting = progress?.queued(now) == true, done = isReady(task);
    return QuintalPreparationTile(
      art: QuintalArtwork.recipe(task['target']),
      name: recipeName(task['target']),
      ready: done,
      status: done
          ? 'Pronto para recolher'
          : waiting
          ? 'Na fila · começa em ${remaining(task['started_at'])}'
          : 'Preparando · ${remaining(task['ready_at'])}',
      progress: waiting ? null : progress?.fraction(now),
      onCollect: enabled && done ? () => act('collect', task['id']) : null,
      onCancel: enabled && waiting ? () => act('cancel', task['id']) : null,
    );
  }

  Future<void> serve(String recipe) async {
    final hates = h.foodPreference(t.target, recipe) == 0;
    if (hates) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Esta receita será recusada'),
          content: Text(
            'Servir vai perder $_quantity porção(ões). Escolha outra receita para alimentar seu gato.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Escolher outra'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Servir mesmo assim'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await act('serve', t.target, {
      'recipe': recipe,
      'quantity': _quantity,
      'confirm_refusal': hates,
    });
  }

  Future<void> rename() async {
    final controller = TextEditingController(text: title);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nome do residente'),
        content: TextField(
          controller: controller,
          maxLength: 32,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty && mounted) {
      await act('rename_resident', t.kind, {
        'slot': int.parse(t.target),
        'name': name,
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: h,
    builder: (context, _) {
      final work = h
          .productionRows('facilities')
          .where(
            (f) => f['kind'] == t.kind && (f['target_level'] as num? ?? 0) > 0,
          )
          .firstOrNull;
      final workReady = work != null && ready(work['ready_at']);
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_panel == null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textTitle,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                IconButton(
                  tooltip: 'Voltar às ações',
                  onPressed: back,
                  icon: const Icon(LucideIcons.arrowLeft, size: 20),
                ),
                Expanded(
                  child: Text(
                    switch (_panel) {
                      'recipes' => 'Escolher receita',
                      'crops' => 'Escolher cultivo',
                      'food' => title,
                      'queue' => 'Na cozinha',
                      'construction' || 'upgrade' =>
                        'Projeto · ${t.kind == 'pier' && _panel == 'upgrade' ? 'Vara de pesca' : facilityTitle}',
                      _ => title,
                    },
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Deselecionar',
                  onPressed: widget.onClose,
                  icon: const Icon(LucideIcons.x, size: 19),
                ),
              ],
            ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _panel == null
                    ? [
                        ...root(),
                        if (t.kind != 'cat' &&
                            t.role != 'build' &&
                            (offer != null || work != null))
                          TextButton.icon(
                            onPressed: () => open('upgrade'),
                            icon: Icon(
                              workReady
                                  ? LucideIcons.check
                                  : LucideIcons.hammer,
                              size: 14,
                            ),
                            label: Text(
                              work == null
                                  ? 'Melhorar espaço'
                                  : workReady
                                  ? 'Concluir ampliação'
                                  : 'Ampliando · ${remaining(work['ready_at'])}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                      ]
                    : choiceLayout(),
              ),
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(6),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (h.offline || h.productionOffline)
            status('Sem conexão · progresso salvo'),
          if (_message != null) status(_message!),
        ],
      );
      if (_panel == null) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 280,
            maxHeight:
                t.role == 'food_cat' ||
                    MediaQuery.textScalerOf(context).scale(15) > 18
                ? 420
                : 260,
          ),
          child: content,
        );
      }
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: content,
          ),
        ),
      );
    },
  );
}
