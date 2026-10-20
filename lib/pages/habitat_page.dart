import '../widgets/app_loading_screen.dart';
import '../widgets/quintal_production_widgets.dart';
import '../widgets/quintal_return_dialog.dart';

import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/habitat_game.dart';
import '../services/habitat_navigation.dart';
import '../game/habitat_sprites.dart';
import '../services/habitat_service.dart';
import '../services/product_api_service.dart';
import '../widgets/habitat_care_sheet.dart';
import '../widgets/quintal_reward_celebration.dart';
import '../widgets/habitat_reward_reveal.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header_actions.dart';
import '../widgets/habitat_coin_badge.dart';
import '../widgets/habitat_sprite_preview.dart';
import '../widgets/habitat_cat_preview.dart';
import 'habitat_help_page.dart';
import 'habitat_shop_page.dart';
import '../widgets/quintal_inventory_tray.dart';
import '../widgets/quintal_bottom_tray.dart';
import 'quintal_game_page.dart';
import '../widgets/quintal_object_actions.dart';
import '../widgets/habitat_object_balloon.dart';
import '../game/quintal_scene_target.dart';

enum _GroundTool { move, paint, collect }

enum _HabitatTray { none, inventory, cats }

class HabitatPage extends StatefulWidget {
  const HabitatPage({
    super.key,
    required this.sessionStore,
    required this.catStore,
    required this.active,
    this.habitatService,
    this.sprites,
    this.onReady,
    this.onLoadError,
  });

  final SessionStore sessionStore;
  final CatStore catStore;
  final ValueListenable<bool> active;
  final HabitatService? habitatService;
  final HabitatSprites? sprites;
  final VoidCallback? onReady;
  final ValueChanged<VoidCallback>? onLoadError;

  @override
  State<HabitatPage> createState() => _HabitatPageState();
}

class _HabitatPageState extends State<HabitatPage> with WidgetsBindingObserver {
  late final HabitatService _habitat;
  late final HabitatSprites _sprites;
  late final HabitatGame _game;
  final GlobalKey _sceneKey = GlobalKey();
  final Set<(int, int)> _pathStroke = {};
  _HabitatTray _tray = _HabitatTray.none;
  bool _menuOpen = false;
  bool _productionTrayOpen = false;
  double _trayExtent = 0, _catSetExtent = 0, _productionTrayExtent = 0;
  bool _editing = false;
  bool _showShop = false;
  bool _showHelp = false;
  bool _migrationNoticeShown = false;
  String? _selectedItemId;
  QuintalSceneTarget? _productionSelection;
  ({String id, (int, int) anchor, (int, int) food, (int, int) water})? _catSet;
  bool _choosingWater = false;
  bool _placingSet = false;
  bool _sceneReady = false;
  Future<void>? _preparingScene;
  String? _sceneError;
  String? _draggingCatId;
  (int, int)? _hovered;
  int _rotation = 0;
  double _scaleStart = 1;
  _GroundTool _groundTool = _GroundTool.move;
  String? _groundSku;
  bool _groundOnly = false, _cameraGesture = false;
  int _scenePointers = 0;
  Timer? _visitorTimer;
  DateTime _nextVisitCheck = DateTime.fromMillisecondsSinceEpoch(0);
  bool _foreground = true, _claimingGift = false;
  String? _rewardLabel;

  @override
  void initState() {
    super.initState();
    _habitat =
        (widget.habitatService ??
              HabitatService(widget.sessionStore, widget.catStore))
          ..addListener(_onHabitatChanged);
    _sprites = widget.sprites ?? HabitatSprites();
    _game = HabitatGame(_habitat, _sprites);
    if (!widget.active.value) _game.pauseEngine();
    widget.active.addListener(_updateActivity);
    WidgetsBinding.instance.addObserver(this);
    HabitatNavigation.focusGift.addListener(_focusGift);
    HabitatNavigation.focusProduction.addListener(_focusProduction);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.active.value) {
        _updateActivity();
      } else {
        unawaited(_prepareScene());
      }
    });
  }

  @override
  void dispose() {
    widget.active.removeListener(_updateActivity);
    WidgetsBinding.instance.removeObserver(this);
    HabitatNavigation.focusGift.removeListener(_focusGift);
    HabitatNavigation.focusProduction.removeListener(_focusProduction);
    _visitorTimer?.cancel();
    _habitat.removeListener(_onHabitatChanged);
    if (widget.habitatService == null) _habitat.dispose();
    if (widget.sprites == null) _sprites.catAnimations.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game.reducedMotion = MediaQuery.disableAnimationsOf(context);
  }

  void _onHabitatChanged() {
    if (!mounted) return;
    setState(() {});
    if (_habitat.layoutAdjusted && !_migrationNoticeShown) {
      _migrationNoticeShown = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _message(
          'Alguns itens foram reposicionados para caber no novo quintal. Confira o inventário.',
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateActivity();
  }

  void _updateActivity() {
    _visitorTimer?.cancel();
    if (widget.active.value && _foreground) {
      _game.resumeEngine();
      unawaited(_loadVisit());
      _visitorTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _tickVisit(),
      );
    } else {
      _game.pauseEngine();
    }
  }

  Future<void> _prepareScene() => _preparingScene ??= _loadScene().whenComplete(
    () => _preparingScene = null,
  );

  Future<void> _loadScene() async {
    try {
      if (mounted) setState(() => _sceneError = null);
      await widget.catStore.ready;
      await _habitat.load();
      await _game.loaded;
      await _game.prepareVisibleAssets();
      if (!mounted) return;
      setState(() => _sceneReady = true);
      widget.onReady?.call();
    } catch (_) {
      if (mounted) {
        setState(() => _sceneError = 'Não foi possível preparar o Quintal.');
        widget.onLoadError?.call(() => unawaited(_prepareScene()));
      }
    }
  }

  Future<void> _loadVisit() async {
    if (!_sceneReady) {
      await _prepareScene();
    } else {
      await _habitat.refreshProduction();
    }
    if (!mounted || !widget.active.value || !_foreground) return;
    await _tickVisit();
    _focusGift();
    _focusProduction();
    await _showProductionReturn();
  }

  Future<void> _showProductionReturn() async {
    final updates = _habitat.productionRows('updates').take(500).toList();
    if (!mounted ||
        updates.isEmpty ||
        _habitat.offline ||
        _habitat.productionOffline) {
      return;
    }
    final selection = await showDialog<QuintalReturnSelection>(
      context: context,
      builder: (_) => QuintalReturnDialog(habitat: _habitat, updates: updates),
    );
    if (!mounted || selection == null) return;
    try {
      await _habitat.produce('ack_return', 'quintal', {
        'event_ids': selection.eventIds,
      });
    } on ProductApiException {
      // Unacknowledged events remain available on the next visit.
    }
    if (mounted && selection.destination != null) {
      HabitatNavigation.focusProduction.value = selection.destination;
      _focusProduction();
    }
  }

  Future<void> _tickVisit() async {
    if (!mounted || _editing || !widget.active.value || !_foreground) return;
    if (DateTime.now().isAfter(_nextVisitCheck)) {
      _nextVisitCheck = DateTime.now().add(const Duration(minutes: 1));
      await _habitat.checkVisitors();
      await _habitat.refreshProduction();
    }
    final gift = _habitat.pendingGift;
    if (gift?['state'] == 'visiting') {
      final created = DateTime.tryParse(gift!['created_at'].toString());
      if (created != null &&
          _habitat.serverNow.difference(created).inSeconds >= 22) {
        try {
          await _habitat.giftAction('deliver');
          if (mounted) {
            _message('Um visitante deixou um presente do lado de fora!');
            unawaited(widget.catStore.notifications.refresh());
          }
        } on ProductApiException {
          /* Retry on the next active tick. */
        }
      }
    }
  }

  void _focusGift() {
    if (!mounted ||
        _habitat.loading ||
        !widget.active.value ||
        HabitatNavigation.focusGift.value == null) {
      return;
    }
    if (_habitat.pendingGift?['id'] == HabitatNavigation.focusGift.value &&
        _game.size.x > 0) {
      _game.focusGift();
    } else {
      _message('Este presente já foi recolhido.');
    }
    HabitatNavigation.focusGift.value = null;
  }

  void _focusProduction() {
    final space = HabitatNavigation.focusProduction.value;
    if (!mounted || !widget.active.value || space == null || _habitat.loading) {
      return;
    }
    HabitatNavigation.focusProduction.value = null;
    _game.focusProduction(space);
    setState(() {
      _editing = false;
      _game.editing = false;
      _tray = _HabitatTray.none;
      _clearSelection();
      _productionSelection = _game.productionDestination(space);
    });
  }

  Future<void> _collectGift() async {
    if (_claimingGift) return;
    setState(() => _claimingGift = true);
    try {
      final reward = await _habitat.giftAction('claim');
      if (!mounted) return;
      final label = reward['coins'] != null
          ? '+${reward['coins']} moedas'
          : reward['portions'] != null
          ? '+${reward['portions']} porções'
          : _habitat.definition(reward['sku'].toString()).name;
      setState(() => _rewardLabel = label);
    } on ProductApiException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _claimingGift = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  HabitatItem? get _selectedItem =>
      _habitat.items.where((item) => item.id == _selectedItemId).firstOrNull;

  HabitatItem? _itemAt((int, int) cell) {
    HabitatItem? groundItem;
    for (final item in _habitat.items.reversed) {
      if (!item.isPlaced) {
        continue;
      }
      final type = _habitat.definition(item.sku);
      if (_groundOnly && !type.isGround) continue;
      if (type.isGround) {
        if (_habitat.occupiedCells(item).contains(cell)) groundItem = item;
        continue;
      }
      final width = item.rotation.isOdd ? type.height : type.width;
      final height = item.rotation.isOdd ? type.width : type.height;
      if (cell.$1 >= item.x! &&
          cell.$1 < item.x! + width &&
          cell.$2 >= item.y! &&
          cell.$2 < item.y! + height) {
        return item;
      }
    }
    return groundItem;
  }

  String? _catAt((int, int) cell) {
    final positions = _game.catCells;
    for (var index = 0; index < positions.length; index++) {
      if (positions[index] == cell) {
        return _habitat.selectedCatIds[index];
      }
    }
    return null;
  }

  void _selectItem(HabitatItem item) {
    setState(() {
      _editing = true;
      _game.editing = true;
      _selectedItemId = item.id;
      _game.selectedItemId = item.id;
      _rotation = item.rotation;
      _groundTool = _habitat.definition(item.sku).isGround && !item.isPlaced
          ? _GroundTool.paint
          : _GroundTool.move;
      _groundSku = _habitat.definition(item.sku).isGround ? item.sku : null;
    });
    final type = _habitat.definition(item.sku);
    unawaited(
      _sprites.preloadReady([
        for (var rotation = 0; rotation < (type.rotatable ? 4 : 1); rotation++)
          _sprites.keyFor(type.displaySprite, rotation),
      ]),
    );
  }

  void _clearSelection() {
    _groundTool = _GroundTool.move;
    _groundSku = null;
    _selectedItemId = null;
    _game.selectedItemId = null;
    _clearPreview();
  }

  void _clearPreview() {
    _hovered = null;
    _game.previewX = null;
    _game.previewY = null;
    _game.previewSku = null;
    _game.previewCat = false;
    _game.previewCatId = null;
  }

  void _preview(Offset localPosition) {
    final cell = _game.cellAt(localPosition);
    _hovered = cell;
    _game.previewX = cell?.$1;
    _game.previewY = cell?.$2;
    _game.previewSku = _draggingCatId != null || _selectedItem == null
        ? null
        : _selectedItem!.sku;
    _game.previewCat = _draggingCatId != null;
    _game.previewCatId = _draggingCatId;
    _game.previewRotation = _rotation;
    _game.previewValid =
        cell != null &&
        (_draggingCatId != null
            ? _habitat.isFreeForCat(cell.$1, cell.$2) &&
                  !_habitat.catAnchors.entries.any(
                    (entry) =>
                        entry.key != _draggingCatId && entry.value == cell,
                  )
            : _selectedItem != null &&
                  _habitat.canPlace(
                    _selectedItem!,
                    cell.$1,
                    cell.$2,
                    _rotation,
                  ));
    setState(() {});
  }

  void _extendPathStroke((int, int) cell) {
    final previous = _pathStroke.lastOrNull;
    if (previous == null) {
      _pathStroke.add(cell);
      return;
    }
    final steps = (cell.$1 - previous.$1).abs() + (cell.$2 - previous.$2).abs();
    for (var index = 1; index <= steps; index++) {
      final x = previous.$1 + ((cell.$1 - previous.$1) * index / steps).round();
      final y = previous.$2 + ((cell.$2 - previous.$2) * index / steps).round();
      if (_habitat.buildableCells.contains((x, y))) _pathStroke.add((x, y));
    }
  }

  Future<void> _dropItem(String id, (int, int) cell) async {
    final item = _habitat.items.where((entry) => entry.id == id).firstOrNull;
    if (item == null) return;
    try {
      final placed = await _habitat.place(
        id,
        cell.$1,
        cell.$2,
        id == _selectedItemId ? _rotation : item.rotation,
      );
      if (placed) {
        setState(_clearSelection);
      } else if (!placed) {
        _message('Esta posição não está disponível.');
      }
    } on HabitatConflictException {
      await _resolveConflict();
    }
    _clearPreview();
  }

  void _openInventory() {
    _openTray(_HabitatTray.inventory);
    unawaited(_habitat.refreshProduction());
  }

  Future<void> _showBowl(HabitatItem item) async {
    final state = _habitat
        .productionRows('cats')
        .where((c) => c['food_bowl'] == item.id || c['water_bowl'] == item.id)
        .firstOrNull;
    final cat = _habitat.cats
        .where((c) => c.id == state?['cat_id'])
        .firstOrNull;
    if (cat == null) {
      _message(
        'Este pote decorativo ainda não tem um gato associado. Os potes individuais acompanham cada gato.',
      );
      return;
    }
    if (state?['assisted'] == true) {
      await _placeCatSet(cat.id, _habitat.catAnchors[cat.id] ?? (3, 3));
      return;
    }
    setState(
      () => _productionSelection = QuintalSceneTarget(
        'cat',
        cat.id,
        item.sku == 'water_bowl' ? 'water_cat' : 'food_cat',
        item.x!.toDouble(),
        item.y!.toDouble(),
      ),
    );
  }

  Future<void> _placeCatSet(String id, (int, int) cell) async {
    final choices =
        _habitat.buildableCells
            .where(
              (c) =>
                  c != cell &&
                  _habitat.isFreeForCat(c.$1, c.$2) &&
                  !_habitat.catAnchors.entries.any(
                    (entry) => entry.key != id && entry.value == c,
                  ),
            )
            .toList()
          ..sort(
            (a, b) => ((a.$1 - cell.$1).abs() + (a.$2 - cell.$2).abs())
                .compareTo((b.$1 - cell.$1).abs() + (b.$2 - cell.$2).abs()),
          );
    if (choices.length < 2) {
      _message('Libere duas células próximas para os potes do gato.');
      return;
    }
    setState(() {
      _catSet = (id: id, anchor: cell, food: choices[0], water: choices[1]);
      _choosingWater = false;
      _tray = _HabitatTray.none;
      _clearSelection();
      _productionSelection = null;
      _syncCatSetPreview();
    });
  }

  void _syncCatSetPreview() {
    final set = _catSet;
    final color = set == null
        ? 0
        : (_habitat.productionCat(set.id)['color_index'] as num? ?? 0).toInt();
    _game.catSetPreviewCatId = set?.id;
    _game.catSetPreview = set == null
        ? {}
        : {
            'production:crafted-cat-food-$color-0-NE': set.food,
            'production:crafted-cat-water-$color-0-NE': set.water,
          };
  }

  void _cancelCatSet() {
    _catSet = null;
    _syncCatSetPreview();
  }

  Future<void> _confirmCatSet() async {
    final set = _catSet;
    if (set == null || _placingSet) return;
    setState(() => _placingSet = true);
    try {
      await _habitat.produce('add_cat', set.id, {
        'anchor': [set.anchor.$1, set.anchor.$2],
        'food': [set.food.$1, set.food.$2],
        'water': [set.water.$1, set.water.$2],
      });
      if (mounted) {
        setState(() {
          _catSet = null;
          _syncCatSetPreview();
        });
      }
    } on ProductApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _placingSet = false);
    }
  }

  Widget _catSetControls() {
    final set = _catSet!;
    final name =
        _habitat.cats.where((c) => c.id == set.id).firstOrNull?.name ??
        'seu gato';
    return QuintalBottomTray(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      onExtentChanged: (height) {
        if (mounted && height != _catSetExtent) {
          setState(() => _catSetExtent = height);
        }
      },
      child: HabitatBalloonSurface(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Posicionar os potes de $name',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Toque no chão para posicionar o pote de ${_choosingWater ? 'água' : 'comida'}.',
                textAlign: TextAlign.center,
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Comida'),
                    selected: !_choosingWater,
                    onSelected: _placingSet
                        ? null
                        : (_) => setState(() => _choosingWater = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Água'),
                    selected: _choosingWater,
                    onSelected: _placingSet
                        ? null
                        : (_) => setState(() => _choosingWater = true),
                  ),

                  IconButton(
                    tooltip: 'Cancelar posicionamento',
                    onPressed: _placingSet
                        ? null
                        : () => setState(() {
                            _catSet = null;
                            _syncCatSetPreview();
                          }),
                    icon: const Icon(LucideIcons.x),
                  ),
                  IconButton(
                    tooltip: 'Confirmar posição dos potes',
                    onPressed: _placingSet ? null : _confirmCatSet,
                    icon: _placingSet
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.check),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _dropCat(String id, (int, int) cell) async {
    try {
      if (_habitat.production.isNotEmpty &&
          (!_habitat.selectedCatIds.contains(id) ||
              _habitat.productionCat(id)['assisted'] == true)) {
        await _placeCatSet(id, cell);
        _clearPreview();
        return;
      }
      final placed = await _habitat.addCatAt(id, cell.$1, cell.$2);
      if (!placed) {
        _message(
          _habitat.selectedCatIds.length >= _habitat.catCapacity
              ? 'O Quintal já está na capacidade máxima de gatos.'
              : 'Escolha uma célula livre para o gato.',
        );
      }
    } on HabitatConflictException {
      await _resolveConflict();
    }
    _clearPreview();
  }

  Future<void> _paintGround(String sku, Iterable<(int, int)> cells) async {
    try {
      final count = await _habitat.paintGround(sku, cells);
      if (count == 0) _message('Sem trechos disponíveis nesta área.');
    } on HabitatConflictException {
      await _resolveConflict();
    }
  }

  Future<void> _tapCell(Offset position) async {
    if (_catSet case final set?) {
      if (_placingSet) return;
      final cell = _game.cellAt(position);
      if (cell == null ||
          cell == set.anchor ||
          cell == (_choosingWater ? set.food : set.water) ||
          _habitat.catAnchors.entries.any(
            (entry) => entry.key != set.id && entry.value == cell,
          ) ||
          !_habitat.isFreeForCat(cell.$1, cell.$2)) {
        _message('Escolha um espaço livre para este pote.');
        return;
      }
      setState(() {
        _catSet = (
          id: set.id,
          anchor: set.anchor,
          food: _choosingWater ? set.food : cell,
          water: _choosingWater ? cell : set.water,
        );
        _syncCatSetPreview();
      });
      return;
    }
    if (!_editing) {
      if (_tray != _HabitatTray.none) {
        setState(() => _tray = _HabitatTray.none);
      }
      if (_game.productionObjectAt(position) case final target?) {
        setState(() => _productionSelection = target);
        return;
      }
      setState(() => _productionSelection = null);
      if (_game.giftAt(position)) {
        await _collectGift();
        return;
      }
      if (_game.catAtScreen(position) case final id?) {
        await _showCatCare(id);
      } else if (_game.itemAtScreen(position) case final item?) {
        if (item.sku == 'food_bowl' || item.sku == 'water_bowl') {
          await _showBowl(item);
        } else if (_habitat.isGrowingPlant(item)) {
          await _showPlantCare(item);
        } else {
          _game.inviteToFurniture(item.id);
        }
      }
      return;
    }
    final target = _game.cellAt(position);
    if (_groundTool != _GroundTool.move && target != null) {
      await _applyGroundStroke([target]);
      return;
    }
    if (_selectedItem case final item?) {
      if (target != null) await _dropItem(item.id, target);
      return;
    }
    if (!_groundOnly) {
      if (_game.itemAtScreen(position) case final item?) {
        _selectItem(item);
        return;
      }
    }
    final cell = _game.cellAt(position);
    if (cell == null) return;
    if (_itemAt(cell) case final item?) _selectItem(item);
  }

  Future<void> _rotateSelected() async {
    final item = _selectedItem;
    if (item == null || !_habitat.definition(item.sku).rotatable) return;
    final previous = _rotation;
    final next = (previous + 1) % 4;
    if (item.isPlaced && !_habitat.canPlace(item, item.x!, item.y!, next)) {
      _message('Não há espaço para girar este item.');
      return;
    }
    await _sprites.ready(
      _sprites.keyFor(_habitat.definition(item.sku).displaySprite, next),
    );
    if (!mounted || _selectedItemId != item.id || _rotation != previous) return;
    setState(() {
      _rotation = next;
      _game.previewRotation = next;
    });
    if (item.isPlaced) {
      try {
        await _habitat.place(item.id, item.x!, item.y!, next);
      } on HabitatConflictException {
        await _resolveConflict();
      }
    }
  }

  Future<void> _storeSelected() async {
    final item = _selectedItem;
    if (item == null) return;
    try {
      await _habitat.storeItem(item.id);
      setState(_clearSelection);
    } on HabitatConflictException {
      await _resolveConflict();
    } on ProductApiException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _showCatCare(String id) async {
    final cat = _habitat.cats.where((cat) => cat.id == id).firstOrNull;
    if (cat == null) return;
    _game.selectedCatId = id;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => HabitatCareSheet(
        habitat: _habitat,
        cat: cat,
        sprites: _sprites,
        preference: _game.preference(id),
        onInventory: () {
          Navigator.pop(sheetContext);
          _openInventory();
        },
        onAction: (action) {
          Navigator.pop(sheetContext);
          unawaited(_careForCat(id, action));
        },
      ),
    );
    _game.selectedCatId = null;
  }

  Future<void> _careForCat(String id, String action) async {
    try {
      if (action == 'setup') {
        await _placeCatSet(id, _habitat.catAnchors[id] ?? (3, 3));
        return;
      }
      if (action == 'play') {
        final cat = _habitat.cats.where((c) => c.id == id).firstOrNull;
        final played = await QuintalGamePage.open(
          context,
          habitat: _habitat,
          scene: _game,
          sceneOrigin: _sceneBox?.localToGlobal(Offset.zero) ?? Offset.zero,
          catId: id,
          catName: cat?.name,
        );
        if (played) await _game.greetCat(id);
        return;
      }
      if (action == 'pet') {
        await _habitat.interact(action, id);
        await widget.catStore.refreshGamification();
        await _game.greetCat(id);
      } else {
        await _game.feedCat(id, treat: action == 'treat');
      }
    } on HabitatConflictException {
      if (mounted) await _resolveConflict();
    } on ProductApiException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  Future<void> _showPlantCare(HabitatItem item) async {
    final growAt = _habitat.growsAt(item);
    final mature = _habitat.isMature(item);
    final hours = growAt == null
        ? 12
        : ((growAt.difference(_habitat.serverNow).inMinutes / 60).ceil()).clamp(
            0,
            12,
          );
    final water = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _habitat.definition(item.sku).name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                mature
                    ? 'Sua planta cresceu e pode receber a visita de abelhinhas.'
                    : growAt == null
                    ? 'A primeira rega começa o crescimento. Ela ficará adulta em 12 horas.'
                    : 'Cresce em até $hours horas. Outra rega depois de 6 horas antecipa o crescimento.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _habitat.canWater(item) && !_habitat.offline
                    ? () => Navigator.pop(sheetContext, true)
                    : null,
                icon: const Icon(LucideIcons.droplets),
                label: Text(
                  mature
                      ? 'Planta adulta'
                      : _habitat.offline
                      ? 'Conecte-se para regar'
                      : _habitat.canWater(item)
                      ? 'Regar'
                      : 'Regada recentemente',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (water != true || !mounted) return;
    try {
      await _habitat.interact('water', item.id);
      await widget.catStore.refreshGamification();
    } on HabitatConflictException {
      if (mounted) await _resolveConflict();
    } on ProductApiException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  Future<void> _removeCat(String id) async {
    try {
      if (_habitat.production.isNotEmpty) {
        await _habitat.produce('remove_cat', id);
        return;
      }
      await _habitat.selectCats(
        _habitat.selectedCatIds.where((selected) => selected != id).toList(),
      );
    } on HabitatConflictException {
      await _resolveConflict();
    }
  }

  Future<void> _resolveConflict() async {
    if (!mounted) return;
    final keepLocal = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quintal atualizado em outro dispositivo'),
        content: const Text(
          'Quer manter a organização feita aqui ou carregar a versão mais recente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Carregar recente'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Manter a minha'),
          ),
        ],
      ),
    );
    if (keepLocal == null) return;
    try {
      if (keepLocal) {
        await _habitat.syncLayout(overwrite: true);
      } else {
        await _habitat.discardDraft();
      }
    } catch (_) {
      _message(
        'Não foi possível sincronizar. Sua edição continua salva neste aparelho.',
      );
    }
  }

  void _toggleEditing() {
    if (_placingSet) return;
    setState(() {
      _cancelCatSet();
      _editing = !_editing;
      _productionSelection = null;
      _game.editing = _editing;
      _menuOpen = false;
      if (!_editing) {
        _tray = _HabitatTray.none;
        _clearSelection();
      }
    });
  }

  void _openTray(_HabitatTray tray) {
    if (_placingSet) return;
    setState(() {
      _cancelCatSet();
      _tray = tray;
      _menuOpen = false;
      if (tray == _HabitatTray.cats) {
        _editing = true;
        _game.editing = true;
      }
      _productionSelection = null;
      _game.selectedProduction = null;
      _clearSelection();
    });
  }

  void _openShop() {
    if (_placingSet) return;
    setState(() {
      _cancelCatSet();
      _tray = _HabitatTray.none;
      _menuOpen = false;
      _clearSelection();
      _showShop = true;
    });
  }

  RenderBox? get _sceneBox =>
      _sceneKey.currentContext?.findRenderObject() as RenderBox?;

  Widget _scene() => DragTarget<String>(
    key: _sceneKey,
    onMove: (details) {
      final box = _sceneBox;
      if (box != null) _preview(box.globalToLocal(details.offset));
    },
    onLeave: (_) => _clearPreview(),
    onAcceptWithDetails: (details) {
      final box = _sceneBox;
      if (box == null) return;
      final cell = _game.cellAt(box.globalToLocal(details.offset));
      if (cell == null) return;
      if (details.data.startsWith('cat:')) {
        unawaited(_dropCat(details.data.substring(4), cell));
      } else if (details.data.startsWith('item:')) {
        unawaited(_dropItem(details.data.substring(5), cell));
      }
    },
    builder: (context, _, _) => Listener(
      onPointerDown: (_) {
        if (_scenePointers == 0) {
          _cameraGesture = false;
        }
        _scenePointers++;
        if (_scenePointers > 1) {
          _cameraGesture = true;
          _pathStroke.clear();
        }
      },
      onPointerUp: (_) {
        if (_scenePointers > 0) {
          _scenePointers--;
        }
      },
      onPointerCancel: (_) {
        if (_scenePointers > 0) {
          _scenePointers--;
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _tapCell(details.localPosition),
        onScaleStart: (details) {
          _scaleStart = _game.zoom;
          _pathStroke.clear();
          if (_editing &&
              (_selectedItem != null || _groundTool == _GroundTool.collect)) {
            if (_groundTool != _GroundTool.move) {
              if (_game.cellAt(details.localFocalPoint) case final cell?) {
                _extendPathStroke(cell);
              }
            }
          }
        },
        onScaleUpdate: (details) {
          if (details.pointerCount > 1) {
            _cameraGesture = true;
            _pathStroke.clear();
            _game.scaleCamera(
              _scaleStart * details.scale,
              details.localFocalPoint,
            );
            setState(() {});
          } else if (_editing && _groundTool != _GroundTool.move) {
            if (!_cameraGesture) {
              if (_game.cellAt(details.localFocalPoint) case final cell?) {
                _extendPathStroke(cell);
              }
            }
          } else if (_selectedItem != null) {
            if (!_cameraGesture) _preview(details.localFocalPoint);
          } else {
            _game.moveCamera(details.focalPointDelta);
            if (_editing || _productionSelection != null) setState(() {});
          }
        },
        onScaleEnd: (_) {
          if (_editing && !_cameraGesture) {
            if (_groundTool != _GroundTool.move && _pathStroke.isNotEmpty) {
              unawaited(_applyGroundStroke(Set.of(_pathStroke)));
            } else if (_selectedItem case final item?) {
              if (_hovered case final cell?) {
                unawaited(_dropItem(item.id, cell));
              }
            }
          }
          _pathStroke.clear();
          _clearPreview();
        },
        onLongPressStart: (details) {
          if (!_editing) return;
          if (!_groundOnly &&
              _game.itemAtScreen(details.localPosition) != null) {
            final item = _game.itemAtScreen(details.localPosition)!;
            _selectItem(item);
            return;
          }
          if (!_groundOnly) {
            if (_game.catAtScreen(details.localPosition) case final id?) {
              setState(() => _draggingCatId = id);
              return;
            }
          }
          final cell = _game.cellAt(details.localPosition);
          if (cell == null) return;
          if (_itemAt(cell) case final item?) {
            _selectItem(item);
          } else if (_catAt(cell) case final id?) {
            setState(() => _draggingCatId = id);
          }
        },
        onLongPressMoveUpdate: (details) {
          if (_selectedItem != null || _draggingCatId != null) {
            _preview(details.localPosition);
          }
        },
        onLongPressEnd: (_) {
          if (_hovered case final cell?) {
            if (_draggingCatId case final id?) {
              unawaited(_dropCat(id, cell));
            } else if (_selectedItem case final item?) {
              unawaited(_dropItem(item.id, cell));
            }
          }
          setState(() => _draggingCatId = null);
          _clearPreview();
        },
        child: GameWidget(
          game: _game,
          loadingBuilder: (_) => const ColoredBox(
            color: Color(0xFFA4C77A),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    ),
  );

  Widget _menuAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback action,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: action,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _circleAction(icon: icon, color: color, onTap: action, size: 44),
      ],
    ),
  );

  Widget _floatingMenu() => QuintalFloatingMenu(
    trayExtent: _tray != _HabitatTray.none
        ? _trayExtent
        : _catSet != null
        ? _catSetExtent
        : _productionSelection != null && _productionTrayOpen
        ? _productionTrayExtent
        : 0,
    actions: [
      if (_menuOpen) ...[
        _menuAction(
          _editing ? 'Concluir edição' : 'Editar',
          LucideIcons.pencil,
          AppColors.greenLink,
          _toggleEditing,
        ),
        _menuAction(
          'Inventário',
          LucideIcons.backpack,
          AppColors.amberDark,
          () => _habitat.production.isEmpty
              ? _openTray(_HabitatTray.inventory)
              : _openInventory(),
        ),
        _menuAction(
          'Loja',
          LucideIcons.shoppingCart,
          AppColors.primaryDark,
          _openShop,
        ),
        _menuAction(
          'Gatos',
          LucideIcons.cat,
          AppColors.socialPurpleText,
          () => _openTray(_HabitatTray.cats),
        ),
      ],
    ],
    button: _circleAction(
      icon: _menuOpen ? LucideIcons.x : LucideIcons.plus,
      color: AppColors.greenButton,
      onTap: () => setState(() => _menuOpen = !_menuOpen),
      size: 52,
      tooltip: _menuOpen ? 'Fechar ações' : 'Abrir ações do Quintal',
    ),
  );

  Widget _circleAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double size,
    String? tooltip,
  }) {
    final button = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: size * 0.46),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _hud() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 10, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            if (_editing)
              InkWell(
                onTap: _toggleEditing,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.greenButton.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.pencil,
                        size: 17,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sair do modo edição',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            AppHeaderActions(store: widget.catStore),
          ],
        ),
        const SizedBox(height: 9),
        if (_habitat.selectedCatIds.isNotEmpty && !_editing)
          Tooltip(
            message: 'Conforto acessível, carinho e alimentação de hoje aumentam a satisfação e a chance de presentes.',
            child: Chip(
              avatar: const QuintalArtwork('cat_satisfaction', size: 32),
              label: Text('Satisfação ${_habitat.satisfaction}%'),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HabitatCoinBadge(balance: _habitat.balance),
            IconButton.filledTonal(
              tooltip: 'Ajuda do Quintal',
              onPressed: () => setState(() {
                _showHelp = true;
                _menuOpen = false;
              }),
              icon: const Icon(LucideIcons.info, size: 18),
            ),
          ],
        ),
        if (widget.sessionStore.isSignedIn &&
            _habitat.offline &&
            _habitat.hasDraft)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Edições salvas neste aparelho',
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: AppColors.textMedium,
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _applyGroundStroke(Iterable<(int, int)> cells) async {
    try {
      if (_groundTool == _GroundTool.collect) {
        await _habitat.collectGround(cells);
      } else if (_groundSku != null) {
        await _paintGround(_groundSku!, cells);
      }
    } on ProductApiException catch (error) {
      _message(error.message);
    }
  }

  Widget _groundTools() => Positioned(
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
            for (final tool in _GroundTool.values)
              TextButton(
                onPressed: tool == _GroundTool.paint && _groundSku == null
                    ? null
                    : () => setState(() {
                        _groundTool = tool;
                        _clearPreview();
                      }),
                style: TextButton.styleFrom(
                  foregroundColor: _groundTool == tool
                      ? AppColors.primaryDark
                      : AppColors.textMedium,
                ),
                child: Text(switch (tool) {
                  _GroundTool.move => 'Selecionar / mover',
                  _GroundTool.paint => 'Pintar',
                  _GroundTool.collect => 'Recolher chão',
                }),
              ),
            IconButton(
              tooltip: _groundOnly
                  ? 'Selecionar objetos'
                  : 'Selecionar chão sob objetos',
              onPressed: () => setState(() {
                _clearSelection();
                _groundOnly = !_groundOnly;
              }),
              icon: Icon(
                LucideIcons.layers,
                color: _groundOnly
                    ? AppColors.primaryDark
                    : AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _selectedControls() {
    final item = _selectedItem;
    if (!_editing || item == null || !item.isPlaced) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: HabitatObjectBalloon(
        anchor: _game.itemFocus(item),
        objectHeight: _game.tileWidth * .8,
        maxWidth: 300,
        child: HabitatBalloonSurface(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              if (_habitat.definition(item.sku).rotatable)
                HabitatBalloonAction(
                  icon: LucideIcons.rotateCw,
                  label: 'Girar',
                  onPressed: _rotateSelected,
                ),
              HabitatBalloonAction(
                icon: LucideIcons.package,
                label: 'Guardar',
                onPressed: _storeSelected,
              ),
              HabitatBalloonAction(
                icon: LucideIcons.x,
                label: 'Deselecionar',
                onPressed: () => setState(_clearSelection),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productionControls() {
    final target = _productionSelection;
    _game.selectedProduction = target;
    if (_editing || target == null) return const SizedBox.shrink();
    return QuintalObjectOverlay(
      game: _game,
      target: target,
      onTrayExtentChanged: (height) {
        if (mounted && height != _productionTrayExtent) {
          setState(() => _productionTrayExtent = height);
        }
      },
      onTrayChanged: (open) {
        if (mounted) setState(() => _productionTrayOpen = open);
      },
      onClose: () => setState(() {
        _productionSelection = null;
        _productionTrayOpen = false;
      }),
      onFish: () =>
          QuintalGamePage.open(context, habitat: _habitat, scene: _game),
    );
  }

  void _inventoryDestination(String space, String? targetId) {
    QuintalSceneTarget? target;
    if (space == 'cat') {
      final bowl = _habitat.productionCat(targetId ?? '')['food_bowl'];
      final item = _habitat.items
          .where((i) => i.id == bowl && i.isPlaced)
          .firstOrNull;
      if (item == null) return;
      target = QuintalSceneTarget(
        'cat',
        targetId!,
        'food_cat',
        item.x!.toDouble(),
        item.y!.toDouble(),
      );
    } else {
      target =
          _game.productionTargets
              .where(
                (t) =>
                    t.kind == space &&
                    (space == 'orchard' && targetId != null
                        ? t.target == targetId
                        : t.role == space),
              )
              .firstOrNull ??
          _game.productionDestination(space);
      _game.focusProduction(space);
    }
    setState(() {
      _tray = _HabitatTray.none;
      _editing = false;
      _game.editing = false;
      _clearSelection();
      _productionSelection = target;
    });
  }

  Widget _trayPanel() {
    final isInventory = _tray == _HabitatTray.inventory;
    final available = <String, List<HabitatItem>>{};
    for (final item in _habitat.items.where(
      (item) => !item.isPlaced && item.careState['cat_id'] == null,
    )) {
      available.putIfAbsent(item.sku, () => []).add(item);
    }
    final itemTypes = _habitat.shop
        .where((type) => available.containsKey(type.sku))
        .toList();
    if (isInventory) {
      return QuintalBottomTray(
        onExtentChanged: (height) {
          if (mounted && height != _trayExtent) {
            setState(() => _trayExtent = height);
          }
        },
        child: QuintalInventoryTray(
          habitat: _habitat,
          decorations: itemTypes.isEmpty
              ? const Center(child: Text('Seu inventário está vazio.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 84, 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: itemTypes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final type = itemTypes[index];
                    final item = available[type.sku]!.first;
                    return LongPressDraggable<String>(
                      data: 'item:${item.id}',
                      onDragStarted: () => _selectItem(item),
                      onDragEnd: (_) => _clearPreview(),
                      feedback: Material(
                        color: Colors.transparent,
                        child: HabitatSpritePreview(
                          sprites: _sprites,
                          keyName: _sprites.keyFor(type.displaySprite, 0),
                          size: 72,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _selectItem(item),
                        child: _trayCard(
                          image: HabitatSpritePreview(
                            sprites: _sprites,
                            keyName: _sprites.keyFor(type.displaySprite, 0),
                            size: 72,
                          ),
                          name: type.name,
                          detail:
                              '${available[type.sku]!.length} ${available[type.sku]!.length == 1 ? 'disponível' : 'disponíveis'}',
                          selected: _selectedItemId == item.id,
                        ),
                      ),
                    );
                  },
                ),
          onClose: () => setState(() => _tray = _HabitatTray.none),
          onTabChanged: (tab) {
            if (tab == 0) return;
            setState(() {
              _clearSelection();
              _editing = false;
              _game.editing = false;
            });
          },
          onKitchen: () => _inventoryDestination('kitchen', null),
          onDestination: _inventoryDestination,
        ),
      );
    }
    return QuintalBottomTray(
      onExtentChanged: (height) {
        if (mounted && height != _trayExtent) {
          setState(() => _trayExtent = height);
        }
      },
      child: Container(
        height:
            244 +
            90 * (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 2),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isInventory ? 'Inventário' : 'Gatos',
                      style: GoogleFonts.fredoka(
                        fontSize: 22,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ),
                  if (!isInventory)
                    Flexible(
                      child: Text(
                        '${_habitat.selectedCatIds.length}/${_habitat.catCapacity} no quintal',
                        textAlign: TextAlign.end,
                        style: GoogleFonts.nunito(color: AppColors.textMedium),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Fechar bandeja',
                    onPressed: () => setState(() => _tray = _HabitatTray.none),
                    icon: const Icon(LucideIcons.x, size: 19),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _habitat.cats.isEmpty
                  ? const Center(
                      child: Text(
                        'Cadastre um gato em Meus Gatos para vê-lo aqui.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 84, 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _habitat.cats.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _habitat.cats[index];
                        final placed = _habitat.selectedCatIds.contains(cat.id);
                        return LongPressDraggable<String>(
                          data: 'cat:${cat.id}',
                          maxSimultaneousDrags:
                              placed ||
                                  _habitat.selectedCatIds.length <
                                      _habitat.catCapacity
                              ? 1
                              : 0,
                          onDragStarted: () =>
                              setState(() => _draggingCatId = cat.id),
                          onDragEnd: (_) => setState(() {
                            _draggingCatId = null;
                            _clearPreview();
                          }),
                          feedback: Material(
                            color: Colors.transparent,
                            child: HabitatCatPreview(cat: cat, size: 72),
                          ),
                          child: _trayCard(
                            image: HabitatCatPreview(cat: cat, size: 72),
                            name: cat.name,
                            detail: placed
                                ? 'No quintal'
                                : 'Arraste para colocar',
                            selected: placed,
                            onRemove: placed ? () => _removeCat(cat.id) : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trayCard({
    required Widget image,
    required String name,
    required String detail,
    required bool selected,
    VoidCallback? onRemove,
  }) => Container(
    width: 112,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: selected ? AppColors.primaryLight : AppColors.cardAltBackground,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(
        color: selected ? AppColors.primary : AppColors.borderLight,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Center(
                child: FittedBox(fit: BoxFit.scaleDown, child: image),
              ),
            ),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                color: AppColors.textTitle,
              ),
            ),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
        if (onRemove != null)
          Positioned(
            right: 0,
            top: 0,
            child: InkWell(
              onTap: onRemove,
              child: const Icon(LucideIcons.x, size: 17),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      _buildPage(context),
      if (!_sceneReady)
        Positioned.fill(
          child: AppLoadingScreen(
            message: _sceneError ?? 'Montando seu Quintal…',
            onRetry: _sceneError == null ? null : _prepareScene,
          ),
        ),
    ],
  );

  Widget _buildPage(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFA4C77A),
    body: Stack(
      children: [
        Positioned.fill(child: _scene()),

        if (_editing && _catSet == null) _selectedControls(),
        if (_catSet != null) _catSetControls(),
        if (!_editing) _productionControls(),
        if (_editing && _catSet == null) _groundTools(),
        if (_habitat.pendingGift?['state'] == 'available')
          Positioned(
            left: 12,
            right: 12,
            top:
                MediaQuery.paddingOf(context).top +
                (_editing
                    ? 144
                    : _habitat.selectedCatIds.isEmpty
                    ? 108
                    : 160),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _claimingGift ? null : _game.focusGift,
                    icon: const Icon(LucideIcons.gift),
                    label: Text(
                      _claimingGift ? 'Abrindo…' : 'Ver presente lá fora',
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Abrir presente disponível',
                  onPressed: _claimingGift ? null : _collectGift,
                  icon: const Icon(LucideIcons.packageOpen),
                ),
              ],
            ),
          ),
        if (_tray != _HabitatTray.none) _trayPanel(),
        SafeArea(child: _hud()),
        _floatingMenu(),
        if (_rewardLabel case final label?)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 82,
            child: HabitatRewardReveal(
              label: label,
              onClose: () => setState(() => _rewardLabel = null),
            ),
          ),
        if (widget.active.value &&
            _foreground &&
            !_editing &&
            !_showShop &&
            !_showHelp &&
            _tray == _HabitatTray.none &&
            ModalRoute.of(context)?.isCurrent != false)
          QuintalRewardCelebrations(
            habitat: _habitat,
            sprites: _sprites,
            onInventory: () {
              if (mounted) _openInventory();
            },
          ),
        if (_showShop)
          Positioned.fill(
            child: HabitatShopPage(
              habitat: _habitat,
              sprites: _sprites,
              onClose: () => setState(() => _showShop = false),
            ),
          ),
        if (_showHelp)
          Positioned.fill(
            child: HabitatHelpPage(
              habitat: _habitat,
              onClose: () => setState(() => _showHelp = false),
            ),
          ),
      ],
    ),
  );
}
