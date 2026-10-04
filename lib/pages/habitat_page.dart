import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/habitat_game.dart';
import '../game/habitat_sprites.dart';
import '../services/habitat_service.dart';
import '../services/product_api_service.dart';
import '../widgets/habitat_care_sheet.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header_actions.dart';
import '../widgets/habitat_coin_badge.dart';
import '../widgets/habitat_sprite_preview.dart';
import 'habitat_help_page.dart';
import 'habitat_shop_page.dart';

enum _HabitatTray { none, inventory, cats }

class HabitatPage extends StatefulWidget {
  const HabitatPage({
    super.key,
    required this.sessionStore,
    required this.catStore,
    required this.active,
    this.habitatService,
    this.sprites,
  });

  final SessionStore sessionStore;
  final CatStore catStore;
  final ValueListenable<bool> active;
  final HabitatService? habitatService;
  final HabitatSprites? sprites;

  @override
  State<HabitatPage> createState() => _HabitatPageState();
}

class _HabitatPageState extends State<HabitatPage> {
  late final HabitatService _habitat;
  late final HabitatSprites _sprites;
  late final HabitatGame _game;
  final GlobalKey _sceneKey = GlobalKey();
  final Set<(int, int)> _pathStroke = {};
  _HabitatTray _tray = _HabitatTray.none;
  bool _menuOpen = false;
  bool _editing = false;
  bool _showShop = false;
  bool _showHelp = false;
  bool _migrationNoticeShown = false;
  String? _selectedItemId;
  String? _draggingCatId;
  (int, int)? _hovered;
  int _rotation = 0;
  double _scaleStart = 1;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.active.value) {
        _updateActivity();
      } else {
        unawaited(_habitat.load());
      }
    });
  }

  @override
  void dispose() {
    widget.active.removeListener(_updateActivity);
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

  void _updateActivity() {
    if (widget.active.value) {
      _game.resumeEngine();
      unawaited(_habitat.load());
    } else {
      _game.pauseEngine();
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
    });
    final type = _habitat.definition(item.sku);
    unawaited(
      _sprites.preloadReady([
        for (var rotation = 0; rotation < (type.rotatable ? 4 : 1); rotation++)
          _sprites.keyFor(type.sprite, rotation),
      ]),
    );
  }

  void _clearSelection() {
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
      final placed = _habitat.definition(item.sku).isGround
          ? await _habitat.paintGround(item.sku, [cell]) > 0
          : await _habitat.place(
              id,
              cell.$1,
              cell.$2,
              id == _selectedItemId ? _rotation : item.rotation,
            );
      if (placed && !_habitat.definition(item.sku).isGround) {
        setState(_clearSelection);
      } else if (!placed) {
        _message('Esta posição não está disponível.');
      }
    } on HabitatConflictException {
      await _resolveConflict();
    }
    _clearPreview();
  }

  Future<void> _dropCat(String id, (int, int) cell) async {
    try {
      final placed = await _habitat.addCatAt(id, cell.$1, cell.$2);
      if (!placed) {
        _message(
          _habitat.selectedCatIds.length >= _habitat.catCapacity
              ? 'O Habitat já está na capacidade máxima de gatos.'
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
    if (!_editing) {
      if (_game.catAtScreen(position) case final id?) {
        await _showCatCare(id);
      } else if (_game.itemAtScreen(position) case final item?) {
        if (_habitat.isGrowingPlant(item)) {
          await _showPlantCare(item);
        } else if (_game.inviteToFurniture(item.id)) {
          _message('Um gatinho está indo explorar esse cantinho.');
        }
      }
      return;
    }
    if (_selectedItem case final item?) {
      final cell = _game.cellAt(position);
      if (cell == null) return;
      if (_habitat.definition(item.sku).isGround) {
        await _paintGround(item.sku, [cell]);
      } else {
        await _dropItem(item.id, cell);
      }
      return;
    }
    if (_game.itemAtScreen(position) case final item?) {
      _selectItem(item);
      return;
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
      _sprites.keyFor(_habitat.definition(item.sku).sprite, next),
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
        onAction: (action) {
          Navigator.pop(sheetContext);
          unawaited(_careForCat(id, action));
        },
      ),
    );
  }

  Future<void> _careForCat(String id, String action) async {
    try {
      if (action == 'pet') {
        await _habitat.interact(action, id);
        await _game.greetCat(id);
      } else {
        _message('O gatinho vai até o potinho para comer.');
        await _game.feedCat(id, treat: action == 'treat');
      }
      if (mounted) _message('Cuidado registrado. A afinidade aumentou!');
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
      if (mounted) _message('Canteiro regado.');
    } on HabitatConflictException {
      if (mounted) await _resolveConflict();
    } on ProductApiException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  Future<void> _removeCat(String id) async {
    try {
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
        title: const Text('Habitat atualizado em outro dispositivo'),
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
    setState(() {
      _editing = !_editing;
      _game.editing = _editing;
      _menuOpen = false;
      if (!_editing) {
        _tray = _HabitatTray.none;
        _clearSelection();
      }
    });
  }

  void _openTray(_HabitatTray tray) {
    setState(() {
      _tray = tray;
      _menuOpen = false;
      _editing = true;
      _game.editing = true;
      _clearSelection();
    });
  }

  void _openShop() => setState(() {
    _tray = _HabitatTray.none;
    _menuOpen = false;
    _clearSelection();
    _showShop = true;
  });

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
    builder: (context, _, _) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _tapCell(details.localPosition),
      onScaleStart: (details) {
        _scaleStart = _game.zoom;
        _pathStroke.clear();
        if (_selectedItem case final item?) {
          if (_habitat.definition(item.sku).isGround) {
            if (_game.cellAt(details.localFocalPoint) case final cell?) {
              _extendPathStroke(cell);
            }
          }
        }
      },
      onScaleUpdate: (details) {
        if (details.pointerCount > 1) {
          _game.scaleCamera(
            _scaleStart * details.scale,
            details.localFocalPoint,
          );
          setState(() {});
        } else if (_selectedItem case final item?) {
          if (_habitat.definition(item.sku).isGround) {
            if (_game.cellAt(details.localFocalPoint) case final cell?) {
              _extendPathStroke(cell);
            }
          }
          _preview(details.localFocalPoint);
        } else {
          _game.moveCamera(details.focalPointDelta);
          if (_editing) setState(() {});
        }
      },
      onScaleEnd: (_) {
        if (_selectedItem case final item?) {
          if (_habitat.definition(item.sku).isGround &&
              _pathStroke.isNotEmpty) {
            unawaited(_paintGround(item.sku, Set.of(_pathStroke)));
          } else if (_hovered case final cell?) {
            unawaited(_dropItem(item.id, cell));
          }
        }
        _pathStroke.clear();
        _clearPreview();
      },
      onLongPressStart: (details) {
        if (!_editing) return;
        if (_game.itemAtScreen(details.localPosition) case final item?) {
          _selectItem(item);
          return;
        }
        if (_game.catAtScreen(details.localPosition) case final id?) {
          setState(() => _draggingCatId = id);
          return;
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

  Widget _floatingMenu() => Positioned(
    right: 16,
    bottom: _tray == _HabitatTray.none ? 18 : 214,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
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
            () => _openTray(_HabitatTray.inventory),
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
        _circleAction(
          icon: _menuOpen ? LucideIcons.x : LucideIcons.plus,
          color: AppColors.greenButton,
          onTap: () => setState(() => _menuOpen = !_menuOpen),
          size: 52,
          tooltip: _menuOpen ? 'Fechar ações' : 'Abrir ações do Habitat',
        ),
      ],
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
                        'Modo edição',
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HabitatCoinBadge(balance: _habitat.balance),
            IconButton.filledTonal(
              tooltip: 'Ajuda do Habitat',
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

  Widget _selectedControls() {
    final item = _selectedItem;
    if (!_editing || item == null || !item.isPlaced) {
      return const SizedBox.shrink();
    }
    final point = _game.itemFocus(item);
    return Positioned(
      left: (point.dx - 52)
          .clamp(8.0, (_game.size.x - 112).clamp(8.0, double.infinity))
          .toDouble(),
      top: (point.dy - _game.tileWidth * 1.65)
          .clamp(
            78.0,
            (_game.size.y - MediaQuery.paddingOf(context).bottom - 70).clamp(
              78.0,
              double.infinity,
            ),
          )
          .toDouble(),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_habitat.definition(item.sku).rotatable)
              IconButton(
                tooltip: 'Girar objeto',
                onPressed: _rotateSelected,
                icon: const Icon(LucideIcons.rotateCw),
              ),
            IconButton(
              tooltip: 'Guardar no inventário',
              onPressed: _storeSelected,
              icon: const Icon(LucideIcons.package),
            ),
            IconButton(
              tooltip: 'Desmarcar objeto',
              onPressed: () => setState(_clearSelection),
              icon: const Icon(LucideIcons.x),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trayPanel() {
    final isInventory = _tray == _HabitatTray.inventory;
    final available = <String, List<HabitatItem>>{};
    for (final item in _habitat.items.where((item) => !item.isPlaced)) {
      available.putIfAbsent(item.sku, () => []).add(item);
    }
    final itemTypes = _habitat.shop
        .where((type) => available.containsKey(type.sku))
        .toList();
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.paddingOf(context).bottom,
      child: Container(
        height: 202,
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
                    Text(
                      '${_habitat.selectedCatIds.length}/${_habitat.catCapacity} no habitat',
                      style: GoogleFonts.nunito(color: AppColors.textMedium),
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
              child: isInventory
                  ? itemTypes.isEmpty
                        ? const Center(
                            child: Text('Seu inventário está vazio.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 84, 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: itemTypes.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
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
                                    keyName: _sprites.keyFor(type.sprite, 0),
                                    size: 72,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () => _selectItem(item),
                                  child: _trayCard(
                                    image: HabitatSpritePreview(
                                      sprites: _sprites,
                                      keyName: _sprites.keyFor(type.sprite, 0),
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
                          )
                  : _habitat.cats.isEmpty
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
                            child: HabitatSpritePreview(
                              sprites: _sprites,
                              keyName: 'animal-cat',
                              size: 72,
                            ),
                          ),
                          child: _trayCard(
                            image: HabitatSpritePreview(
                              sprites: _sprites,
                              keyName: 'animal-cat',
                              size: 72,
                            ),
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
            Expanded(child: Center(child: image)),
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFA4C77A),
    body: Stack(
      children: [
        Positioned.fill(child: _scene()),
        if (_habitat.loading) const Center(child: CircularProgressIndicator()),
        if (_editing) _selectedControls(),
        if (_tray != _HabitatTray.none) _trayPanel(),
        SafeArea(child: Stack(children: [_hud(), _floatingMenu()])),
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
