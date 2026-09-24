import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/cat_database.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import 'product_api_service.dart';

class HabitatItem {
  const HabitatItem({
    required this.id,
    required this.sku,
    this.x,
    this.y,
    this.rotation = 0,
  });

  final String id;
  final String sku;
  final int? x;
  final int? y;
  final int rotation;

  bool get isPlaced => x != null && y != null;

  HabitatItem at(int? newX, int? newY, int newRotation) =>
      HabitatItem(id: id, sku: sku, x: newX, y: newY, rotation: newRotation);

  factory HabitatItem.fromMap(Map<String, dynamic> value) => HabitatItem(
    id: value['id'].toString(),
    sku: value['sku'].toString(),
    x: (value['x'] as num?)?.toInt(),
    y: (value['y'] as num?)?.toInt(),
    rotation: (value['rotation'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'sku': sku,
    'x': x,
    'y': y,
    'rotation': rotation,
  };
}

class HabitatShopItem {
  const HabitatShopItem({
    required this.sku,
    required this.name,
    required this.category,
    required this.sprite,
    required this.price,
    required this.width,
    required this.height,
    required this.maxOwned,
    this.layer = 'solid',
    this.rotatable = true,
  });

  final String sku;
  final String name;
  final String category;
  final String sprite;
  final int price;
  final int width;
  final int height;
  final int maxOwned;
  final String layer;
  final bool rotatable;
  bool get isPath => layer == 'path';

  factory HabitatShopItem.fromMap(Map<String, dynamic> value) =>
      HabitatShopItem(
        sku: value['sku'].toString(),
        name: value['name'].toString(),
        category: value['category'].toString(),
        sprite: value['sprite'].toString(),
        price: (value['price'] as num).toInt(),
        width: (value['width'] as num).toInt(),
        height: (value['height'] as num).toInt(),
        maxOwned: (value['max_owned'] as num).toInt(),
        layer: value['layer']?.toString() ?? 'solid',
        rotatable: value['rotatable'] != false,
      );

  Map<String, dynamic> toMap() => {
    'sku': sku,
    'name': name,
    'category': category,
    'sprite': sprite,
    'price': price,
    'width': width,
    'height': height,
    'max_owned': maxOwned,
    'layer': layer,
    'rotatable': rotatable,
  };
}

class HabitatCat {
  const HabitatCat({required this.id, required this.name, this.primaryColor});

  final String id;
  final String name;
  final String? primaryColor;

  factory HabitatCat.fromMap(Map<String, dynamic> value) => HabitatCat(
    id: value['id'].toString(),
    name: value['name']?.toString() ?? 'Meu gato',
    primaryColor: value['primary_color']?.toString(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'primary_color': primaryColor,
  };
}

class HabitatConflictException implements Exception {}

class HabitatService extends ChangeNotifier {
  HabitatService(
    this.session,
    this.catStore, {
    CatDatabase? database,
    ProductApiService? api,
  }) : _database = database ?? CatDatabase.instance,
       _api = api ?? ProductApiService(session);

  final SessionStore session;
  final CatStore catStore;
  final CatDatabase _database;
  final ProductApiService _api;

  static const gridSize = 8;
  static const maxPlaced = 24;
  static const _layoutRulesVersion = 3;
  static const _starterSkus = [
    'cat_bed',
    'small_tree',
    'small_bush',
    'red_flowers',
  ];
  static const _offlineShop = [
    HabitatShopItem(
      sku: 'cat_bed',
      name: 'Caminha',
      category: 'descanso',
      sprite: 'bed',
      price: 0,
      width: 1,
      height: 2,
      maxOwned: 1,
    ),
    HabitatShopItem(
      sku: 'small_tree',
      name: 'Árvore pequena',
      category: 'natureza',
      sprite: 'tree_default',
      price: 0,
      width: 1,
      height: 1,
      maxOwned: 1,
    ),
    HabitatShopItem(
      sku: 'small_bush',
      name: 'Arbusto',
      category: 'natureza',
      sprite: 'plant_bushSmall',
      price: 0,
      width: 1,
      height: 1,
      maxOwned: 1,
    ),
    HabitatShopItem(
      sku: 'red_flowers',
      name: 'Flores vermelhas',
      category: 'natureza',
      sprite: 'flower_redA',
      price: 0,
      width: 1,
      height: 1,
      maxOwned: 1,
    ),
    HabitatShopItem(
      sku: 'yellow_flowers',
      name: 'Flores amarelas',
      category: 'natureza',
      sprite: 'flower_yellowA',
      price: 20,
      width: 1,
      height: 1,
      maxOwned: 4,
    ),
    HabitatShopItem(
      sku: 'soft_grass',
      name: 'Grama macia',
      category: 'descanso',
      sprite: 'grass',
      price: 20,
      width: 1,
      height: 1,
      maxOwned: 4,
    ),
    HabitatShopItem(
      sku: 'small_rock',
      name: 'Pedra',
      category: 'natureza',
      sprite: 'rock_smallA',
      price: 25,
      width: 1,
      height: 1,
      maxOwned: 4,
    ),
    HabitatShopItem(
      sku: 'stone_path',
      name: 'Caminho de pedra',
      category: 'natureza',
      sprite: 'ground_pathTile',
      price: 25,
      width: 1,
      height: 1,
      maxOwned: 6,
      layer: 'path',
    ),
    HabitatShopItem(
      sku: 'low_fence',
      name: 'Cerca de madeira',
      category: 'natureza',
      sprite: 'fence_simple',
      price: 30,
      width: 1,
      height: 1,
      maxOwned: 6,
    ),
    HabitatShopItem(
      sku: 'leafy_plant',
      name: 'Folhagem',
      category: 'natureza',
      sprite: 'plant_flatShort',
      price: 35,
      width: 1,
      height: 1,
      maxOwned: 4,
    ),
    HabitatShopItem(
      sku: 'floor_bed',
      name: 'Cantinho de descanso',
      category: 'descanso',
      sprite: 'bed_floor',
      price: 45,
      width: 2,
      height: 2,
      maxOwned: 2,
    ),
    HabitatShopItem(
      sku: 'oak_tree',
      name: 'Carvalho',
      category: 'natureza',
      sprite: 'tree_oak',
      price: 60,
      width: 2,
      height: 2,
      maxOwned: 2,
    ),
    HabitatShopItem(
      sku: 'large_log',
      name: 'Tronco para brincar',
      category: 'brincadeira',
      sprite: 'log_large',
      price: 65,
      width: 2,
      height: 1,
      maxOwned: 3,
    ),
    HabitatShopItem(
      sku: 'large_rock',
      name: 'Pedra de jardim',
      category: 'natureza',
      sprite: 'rock_largeA',
      price: 75,
      width: 2,
      height: 2,
      maxOwned: 2,
    ),
    HabitatShopItem(
      sku: 'detailed_tree',
      name: 'Árvore frondosa',
      category: 'natureza',
      sprite: 'tree_detailed',
      price: 95,
      width: 2,
      height: 2,
      maxOwned: 2,
    ),
    HabitatShopItem(
      sku: 'tall_pine',
      name: 'Pinheiro alto',
      category: 'natureza',
      sprite: 'tree_pineTallA',
      price: 120,
      width: 2,
      height: 2,
      maxOwned: 2,
    ),
    HabitatShopItem(
      sku: 'canvas_shelter',
      name: 'Abrigo de lona',
      category: 'descanso',
      sprite: 'tent_smallOpen',
      price: 90,
      width: 2,
      height: 2,
      maxOwned: 2,
    ),
    HabitatShopItem(
      sku: 'canvas_retreat',
      name: 'Refúgio de lona',
      category: 'descanso',
      sprite: 'tent_detailedOpen',
      price: 140,
      width: 3,
      height: 2,
      maxOwned: 2,
    ),
    HabitatShopItem(
      sku: 'green_cottage',
      name: 'Casinha verde',
      category: 'casinhas',
      sprite: 'building-type-a',
      price: 220,
      width: 3,
      height: 3,
      maxOwned: 1,
      rotatable: false,
    ),
    HabitatShopItem(
      sku: 'large_cottage',
      name: 'Casinha ampla',
      category: 'casinhas',
      sprite: 'building-type-f',
      price: 260,
      width: 3,
      height: 3,
      maxOwned: 1,
      rotatable: false,
    ),
    HabitatShopItem(
      sku: 'pebble_path',
      name: 'Caminho de pedrinhas',
      category: 'caminhos',
      sprite: 'path_stone',
      price: 6,
      width: 1,
      height: 1,
      maxOwned: 256,
      layer: 'path',
    ),
    HabitatShopItem(
      sku: 'wood_path',
      name: 'Caminho de madeira',
      category: 'caminhos',
      sprite: 'path_wood',
      price: 8,
      width: 1,
      height: 1,
      maxOwned: 256,
      layer: 'path',
    ),
  ];

  int balance = 0;
  int revision = 0;
  int expansionLevel = 0;
  bool layoutAdjusted = false;
  Map<String, (int, int)> catAnchors = {};
  Set<(int, int)> buildableCells = yardCells(0);
  int get catCapacity => 3 + expansionLevel;
  int get decorationCapacity => 24 + 8 * expansionLevel;
  int? get nextExpansionPrice =>
      expansionLevel < 3 ? const [80, 180, 320][expansionLevel] : null;

  static Set<(int, int)> yardCells(int level) {
    var cells = <(int, int)>{
      for (var x = 0; x < 8; x++)
        for (var y = 0; y < 8; y++) (x, y),
      for (var x = 2; x <= 5; x++) (x, -1),
      for (var y = 2; y <= 5; y++) (-1, y),
      for (var y = 1; y <= 6; y++) (8, y),
      for (var x = 2; x <= 6; x++) (x, 8),
    };
    for (var i = 0; i < level; i++) {
      cells = {
        ...cells,
        for (final cell in cells) (cell.$1 + 1, cell.$2),
        for (final cell in cells) (cell.$1 - 1, cell.$2),
        for (final cell in cells) (cell.$1, cell.$2 + 1),
        for (final cell in cells) (cell.$1, cell.$2 - 1),
      };
    }
    return cells;
  }

  bool loading = false;
  bool offline = false;
  bool hasDraft = false;
  List<HabitatItem> items = [];
  List<HabitatCat> cats = [];
  List<String> selectedCatIds = [];
  List<HabitatShopItem> _shop = _offlineShop;
  Map<String, HabitatShopItem> _catalog = {
    for (final item in _offlineShop) item.sku: item,
  };
  List<HabitatShopItem> get shop => _shop;
  set shop(List<HabitatShopItem> value) {
    _shop = value;
    _catalog = {for (final item in value) item.sku: item};
  }

  Map<String, int> rewards = const {
    'catalog': 25,
    'reference': 3,
    'sighting': 8,
    'post': 10,
    'comment': 3,
    'like': 1,
    'share': 3,
    'care': 3,
  };
  Map<String, int> dailyLimits = const {
    'reference': 2,
    'sighting': 3,
    'post': 2,
    'comment': 4,
    'like': 5,
    'share': 2,
    'care': 1,
  };
  Map<String, String> _pendingPurchases = {};
  Future<void>? _syncInFlight;
  int _editVersion = 0;

  String get _ownerId => session.session?.userId ?? 'guest';
  HabitatShopItem definition(String sku) =>
      _catalog[sku] ?? (throw StateError('Item desconhecido no Habitat: $sku'));

  Future<void> load() async {
    final owner = _ownerId;
    loading = true;
    notifyListeners();
    Map<String, dynamic>? cached;
    try {
      cached = await _database.readHabitatCache(owner);
    } catch (_) {
      // The scene can still open if local storage is temporarily unavailable.
    }
    _pendingPurchases = {
      for (final entry
          in (cached?['pending_purchases'] as Map? ?? const {}).entries)
        entry.key.toString(): entry.value.toString(),
    };
    if (cached?['snapshot'] case final Map raw) {
      _readSnapshot(Map<String, dynamic>.from(raw));
    } else if (!session.isSignedIn) {
      _seedGuest();
    }
    final draft = cached?['draft'];
    if (draft is Map) {
      _applyDraft(Map<String, dynamic>.from(draft));
      hasDraft = true;
    }
    final snapshot = cached?['snapshot'];
    if (snapshot is Map &&
        ((snapshot['layout_rules_version'] as num?)?.toInt() ?? 1) <
            _layoutRulesVersion) {
      // Offline layouts must use the same corrected bed axes as the API.
      shop = [
        for (final item in shop)
          if (item.sku == 'cat_bed')
            HabitatShopItem.fromMap({...item.toMap(), 'width': 1, 'height': 2})
          else
            item,
      ];
      if (_normalizeDraftLayout()) {
        hasDraft = true;
        await _database.saveHabitatDraft(owner, _draft());
      }
      await _persistSnapshot();
    }
    if (!session.isSignedIn) {
      _readLocalCats();
      loading = false;
      offline = true;
      notifyListeners();
      return;
    }
    try {
      final results = await Future.wait([
        _api.get('/app/habitat'),
        _api.get('/app/habitat/shop'),
      ]);
      if (owner != _ownerId) return;
      _readSnapshot(results.first);
      shop = ((results.last['items'] as List?) ?? const [])
          .map(
            (entry) => HabitatShopItem.fromMap(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();
      if (shop.isEmpty) shop = _offlineShop;
      rewards = _intMap(results.last['rewards']) ?? rewards;
      dailyLimits = _intMap(results.last['daily_limits']) ?? dailyLimits;
      if (draft is Map) {
        _applyDraft(Map<String, dynamic>.from(draft));
        if (_normalizeDraftLayout()) {
          await _database.saveHabitatDraft(_ownerId, _draft());
        }
      }
      await _persistSnapshot();
      offline = false;
    } catch (_) {
      offline = true;
      if (items.isEmpty && !session.isSignedIn) _seedGuest();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _seedGuest() {
    items = [
      for (final sku in _starterSkus) HabitatItem(id: 'guest-$sku', sku: sku),
    ];
    shop = _offlineShop;
    balance = 0;
    revision = 0;
    expansionLevel = 0;
    buildableCells = yardCells(0);
    catAnchors = {};
  }

  void _readLocalCats() {
    cats = [
      for (final cat in catStore.pets)
        HabitatCat(
          id: cat.id,
          name: cat.displayName,
          primaryColor: catStore.analysisFor(cat.id)?.primaryColor,
        ),
    ];
  }

  void _readSnapshot(Map<String, dynamic> data) {
    balance = (data['balance'] as num?)?.toInt() ?? 0;
    revision = (data['revision'] as num?)?.toInt() ?? 0;
    expansionLevel = (data['expansion_level'] as num?)?.toInt() ?? 0;
    layoutAdjusted = data['layout_adjusted'] == true;
    buildableCells = data['buildable_cells'] is List
        ? {
            for (final cell in data['buildable_cells'] as List)
              ((cell[0] as num).toInt(), (cell[1] as num).toInt()),
          }
        : yardCells(expansionLevel);
    catAnchors = {
      for (final entry in (data['cat_anchors'] as Map? ?? const {}).entries)
        if (entry.value is List && (entry.value as List).length == 2)
          entry.key.toString(): (
            (entry.value[0] as num).toInt(),
            (entry.value[1] as num).toInt(),
          ),
    };
    items = ((data['items'] as List?) ?? const [])
        .map(
          (entry) =>
              HabitatItem.fromMap(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    cats = ((data['cats'] as List?) ?? const [])
        .map(
          (entry) =>
              HabitatCat.fromMap(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    selectedCatIds = ((data['selected_cat_ids'] as List?) ?? const [])
        .map((entry) => entry.toString())
        .toList();
    if (data['shop'] is List) {
      shop = (data['shop'] as List)
          .map(
            (entry) => HabitatShopItem.fromMap(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();
    }
    rewards = _intMap(data['rewards']) ?? rewards;
    dailyLimits = _intMap(data['daily_limits']) ?? dailyLimits;
  }

  Map<String, int>? _intMap(Object? value) => value is Map
      ? {
          for (final entry in value.entries)
            entry.key.toString(): (entry.value as num).toInt(),
        }
      : null;

  Map<String, dynamic> _snapshot() => {
    'layout_rules_version': _layoutRulesVersion,
    'balance': balance,
    'revision': revision,
    'expansion_level': expansionLevel,
    'buildable_cells': [
      for (final cell in buildableCells) [cell.$1, cell.$2],
    ],
    'cat_anchors': {
      for (final entry in catAnchors.entries)
        entry.key: [entry.value.$1, entry.value.$2],
    },
    'items': items.map((item) => item.toMap()).toList(),
    'cats': cats.map((cat) => cat.toMap()).toList(),
    'selected_cat_ids': selectedCatIds,
    'shop': shop.map((entry) => entry.toMap()).toList(),
    'rewards': rewards,
    'daily_limits': dailyLimits,
  };

  Future<void> _persistSnapshot() =>
      _database.saveHabitatSnapshot(_ownerId, _snapshot());

  Map<String, dynamic> _draft() => {
    'expected_revision': revision,
    'placements': [
      for (final item in items.where((item) => item.isPlaced))
        {
          'item_id': item.id,
          'x': item.x,
          'y': item.y,
          'rotation': item.rotation,
        },
    ],
    'selected_cat_ids': selectedCatIds,
    'cat_anchors': {
      for (final entry in catAnchors.entries)
        if (selectedCatIds.contains(entry.key))
          entry.key: [entry.value.$1, entry.value.$2],
    },
  };

  void _applyDraft(Map<String, dynamic> draft) {
    final positions = <String, Map<String, dynamic>>{
      for (final raw in (draft['placements'] as List? ?? const []))
        Map<String, dynamic>.from(raw as Map)['item_id'].toString():
            Map<String, dynamic>.from(raw),
    };
    items = [
      for (final item in items)
        if (positions[item.id] case final position?)
          item.at(
            (position['x'] as num).toInt(),
            (position['y'] as num).toInt(),
            (position['rotation'] as num).toInt(),
          )
        else
          item.at(null, null, 0),
    ];
    selectedCatIds = ((draft['selected_cat_ids'] as List?) ?? const [])
        .map((entry) => entry.toString())
        .toList();
    if (draft['cat_anchors'] is Map) {
      catAnchors = {
        for (final entry in (draft['cat_anchors'] as Map).entries)
          if (entry.value is List && (entry.value as List).length == 2)
            entry.key.toString(): (
              (entry.value[0] as num).toInt(),
              (entry.value[1] as num).toInt(),
            ),
      };
    }
  }

  List<(int, int)> _cellsNearestTo((int, int) origin) =>
      buildableCells.toList()..sort((a, b) {
        final distanceA = (a.$1 - origin.$1).abs() + (a.$2 - origin.$2).abs();
        final distanceB = (b.$1 - origin.$1).abs() + (b.$2 - origin.$2).abs();
        if (distanceA != distanceB) return distanceA.compareTo(distanceB);
        if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
        return a.$1.compareTo(b.$1);
      });

  bool _normalizeDraftLayout() {
    final placed = items.where((item) => item.isPlaced).toList()
      ..sort((a, b) {
        final first = definition(a.sku);
        final second = definition(b.sku);
        return (second.width * second.height).compareTo(
          first.width * first.height,
        );
      });
    final original = {for (final item in placed) item.id: (item.x!, item.y!)};
    final previousAnchors = Map<String, (int, int)>.of(catAnchors);
    catAnchors = {};
    items = [for (final item in items) item.at(null, null, 0)];
    var adjusted = false;
    for (final item in placed) {
      final origin = original[item.id]!;
      final rotation = definition(item.sku).rotatable ? item.rotation : 0;
      final position = _cellsNearestTo(origin)
          .where((cell) => canPlace(item, cell.$1, cell.$2, rotation))
          .firstOrNull;
      if (position != null) {
        final index = items.indexWhere((entry) => entry.id == item.id);
        items[index] = item.at(position.$1, position.$2, rotation);
      }
      adjusted |= position != origin;
    }
    for (final id in selectedCatIds) {
      final origin = previousAnchors[id];
      final position = _cellsNearestTo(origin ?? (3, 3))
          .where(
            (cell) =>
                isFreeForCat(cell.$1, cell.$2) &&
                !catAnchors.values.contains(cell),
          )
          .firstOrNull;
      if (position != null) catAnchors[id] = position;
      adjusted |= position != origin;
    }
    layoutAdjusted |= adjusted;
    return adjusted;
  }

  bool canPlace(HabitatItem item, int x, int y, int rotation) {
    final definition = this.definition(item.sku);
    if (!definition.rotatable && rotation != 0) return false;
    final width = rotation.isOdd ? definition.height : definition.width;
    final height = rotation.isOdd ? definition.width : definition.height;
    for (var dx = 0; dx < width; dx++) {
      for (var dy = 0; dy < height; dy++) {
        if (!buildableCells.contains((x + dx, y + dy))) {
          return false;
        }
        if (!definition.isPath &&
            catAnchors.values.contains((x + dx, y + dy))) {
          return false;
        }
      }
    }
    if (!item.isPlaced &&
        !definition.isPath &&
        items
                .where(
                  (entry) =>
                      entry.isPlaced && !this.definition(entry.sku).isPath,
                )
                .length >=
            decorationCapacity) {
      return false;
    }
    for (final other in items.where(
      (entry) => entry.isPlaced && entry.id != item.id,
    )) {
      final otherDefinition = this.definition(other.sku);
      if (definition.isPath != otherDefinition.isPath) continue;
      final otherWidth = other.rotation.isOdd
          ? otherDefinition.height
          : otherDefinition.width;
      final otherHeight = other.rotation.isOdd
          ? otherDefinition.width
          : otherDefinition.height;
      if (x < other.x! + otherWidth &&
          x + width > other.x! &&
          y < other.y! + otherHeight &&
          y + height > other.y!) {
        return false;
      }
    }
    return true;
  }

  Future<bool> place(String itemId, int x, int y, int rotation) async {
    final index = items.indexWhere((entry) => entry.id == itemId);
    if (index < 0 || !canPlace(items[index], x, y, rotation)) return false;
    items[index] = items[index].at(x, y, rotation);
    notifyListeners();
    await _saveDraft();
    return true;
  }

  Future<void> storeItem(String itemId) async {
    final index = items.indexWhere((entry) => entry.id == itemId);
    if (index < 0) return;
    items[index] = items[index].at(null, null, 0);
    notifyListeners();
    await _saveDraft();
  }

  Future<void> selectCats(List<String> ids) async {
    if (ids.length > catCapacity ||
        ids.toSet().length != ids.length ||
        ids.any((id) => !cats.any((cat) => cat.id == id))) {
      return;
    }
    selectedCatIds = ids;
    catAnchors.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      catAnchors.putIfAbsent(id, () => firstFreeCatCell() ?? (0, 0));
    }
    notifyListeners();
    await _saveDraft();
  }

  bool isFreeForCat(int x, int y) {
    if (!buildableCells.contains((x, y))) return false;
    return !items.any((item) {
      if (!item.isPlaced || definition(item.sku).isPath) return false;
      final type = definition(item.sku);
      final width = item.rotation.isOdd ? type.height : type.width;
      final height = item.rotation.isOdd ? type.width : type.height;
      return x >= item.x! &&
          x < item.x! + width &&
          y >= item.y! &&
          y < item.y! + height;
    });
  }

  (int, int)? firstFreeCatCell() {
    final cells = buildableCells.toList()
      ..sort(
        (a, b) => ((a.$1 - 3).abs() + (a.$2 - 3).abs()).compareTo(
          (b.$1 - 3).abs() + (b.$2 - 3).abs(),
        ),
      );
    for (final cell in cells) {
      if (isFreeForCat(cell.$1, cell.$2) && !catAnchors.values.contains(cell)) {
        return cell;
      }
    }
    return null;
  }

  Future<bool> setCatAnchor(String id, int x, int y) async {
    if (!selectedCatIds.contains(id) ||
        !isFreeForCat(x, y) ||
        catAnchors.entries.any(
          (entry) => entry.key != id && entry.value == (x, y),
        )) {
      return false;
    }
    catAnchors[id] = (x, y);
    notifyListeners();
    await _saveDraft();
    return true;
  }

  Future<bool> addCatAt(String id, int x, int y) async {
    if (selectedCatIds.contains(id)) return setCatAnchor(id, x, y);
    if (selectedCatIds.length >= catCapacity ||
        !cats.any((cat) => cat.id == id) ||
        !isFreeForCat(x, y) ||
        catAnchors.values.contains((x, y))) {
      return false;
    }
    selectedCatIds = [...selectedCatIds, id];
    catAnchors[id] = (x, y);
    notifyListeners();
    await _saveDraft();
    return true;
  }

  Future<int> paintPath(String sku, Iterable<(int, int)> cells) async {
    if (!definition(sku).isPath) return 0;
    var painted = 0;
    for (final cell in cells.toSet()) {
      final available = items
          .where((item) => item.sku == sku && !item.isPlaced)
          .firstOrNull;
      if (available == null || !canPlace(available, cell.$1, cell.$2, 0)) {
        continue;
      }
      final index = items.indexWhere((item) => item.id == available.id);
      items[index] = available.at(cell.$1, cell.$2, 0);
      painted++;
    }
    if (painted > 0) {
      notifyListeners();
      await _saveDraft();
    }
    return painted;
  }

  Future<void> _saveDraft() async {
    _editVersion++;
    hasDraft = true;
    await _database.saveHabitatDraft(_ownerId, _draft());
    if (session.isSignedIn) {
      try {
        await syncLayout();
      } on HabitatConflictException {
        rethrow;
      } catch (_) {
        offline = true;
        notifyListeners();
      }
    } else {
      await _persistSnapshot();
    }
  }

  Future<void> syncLayout({bool overwrite = false}) async {
    while (true) {
      final running = _syncInFlight;
      if (running == null) break;
      await running;
    }
    if (!session.isSignedIn || !hasDraft) return;
    final task = _syncOnce(overwrite: overwrite);
    _syncInFlight = task;
    try {
      await task;
    } finally {
      _syncInFlight = null;
    }
  }

  Future<void> _syncOnce({required bool overwrite}) async {
    try {
      if (overwrite) {
        final remote = await _api.get('/app/habitat');
        revision = (remote['revision'] as num).toInt();
      }
      final version = _editVersion;
      final result = await _api.put('/app/habitat/layout', _draft());
      final newerDraft = version == _editVersion ? null : _draft();
      _readSnapshot(result);
      final appliedVersion = _editVersion;
      if (newerDraft != null) {
        _applyDraft(newerDraft);
        await _database.saveHabitatDraft(_ownerId, _draft());
      } else {
        await _database.saveHabitatDraft(_ownerId, null);
      }
      hasDraft = newerDraft != null || _editVersion != appliedVersion;
      if (_editVersion != appliedVersion) {
        await _database.saveHabitatDraft(_ownerId, _draft());
      }
      offline = false;
      await _persistSnapshot();
      notifyListeners();
    } on ProductApiException catch (error) {
      if (error.statusCode == 409) throw HabitatConflictException();
      rethrow;
    }
  }

  Future<void> discardDraft() async {
    await _database.saveHabitatDraft(_ownerId, null);
    hasDraft = false;
    await load();
  }

  Future<void> buy(String sku, {int quantity = 1}) async {
    if (!session.isSignedIn) {
      throw const ProductApiException(
        'Entre na sua conta para comprar decorações.',
      );
    }
    if (quantity < 1 ||
        quantity > 20 ||
        (quantity > 1 && !definition(sku).isPath)) {
      throw const ProductApiException('Quantidade inválida para este item.');
    }
    final pendingId = '$sku:$quantity';
    if (_pendingPurchases.keys.any(
      (id) => id.startsWith('$sku:') && id != pendingId,
    )) {
      throw const ProductApiException(
        'Conclua a compra anterior deste item antes de mudar a quantidade.',
      );
    }
    final key = _pendingPurchases[pendingId] ?? const Uuid().v4();
    _pendingPurchases[pendingId] = key;
    await _database.saveHabitatPendingPurchases(_ownerId, _pendingPurchases);
    final result = await _api.post('/app/habitat/purchases', {
      'sku': sku,
      'quantity': quantity,
      'idempotency_key': key,
    });
    final purchased = (result['items'] as List? ?? [result['item']]).map(
      (raw) => HabitatItem.fromMap(Map<String, dynamic>.from(raw as Map)),
    );
    for (final item in purchased) {
      if (!items.any((existing) => existing.id == item.id)) {
        items = [...items, item];
      }
    }
    balance = (result['balance'] as num).toInt();
    offline = false;
    await _persistSnapshot();
    _pendingPurchases.remove(pendingId);
    await _database.saveHabitatPendingPurchases(_ownerId, _pendingPurchases);
    notifyListeners();
  }

  Future<void> expand() async {
    if (!session.isSignedIn || nextExpansionPrice == null) {
      throw const ProductApiException(
        'Não é possível ampliar este quintal agora.',
      );
    }
    if (hasDraft) await syncLayout();
    final pendingId = 'expansion:$expansionLevel';
    final key = _pendingPurchases[pendingId] ?? const Uuid().v4();
    _pendingPurchases[pendingId] = key;
    await _database.saveHabitatPendingPurchases(_ownerId, _pendingPurchases);
    final result = await _api.post('/app/habitat/expansions', {
      'expected_level': expansionLevel,
      'idempotency_key': key,
    });
    _readSnapshot(result);
    _pendingPurchases.remove(pendingId);
    await _database.saveHabitatPendingPurchases(_ownerId, _pendingPurchases);
    await _persistSnapshot();
    notifyListeners();
  }
}
